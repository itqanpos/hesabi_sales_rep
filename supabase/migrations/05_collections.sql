-- ============================================================================
-- Migration 05 — Collections (Rep-level customer payments)
-- Adds sales_rep_id to customer_payments + read/write RPCs
-- ============================================================================

-- 1) عمود sales_rep_id ------------------------------------------------------
alter table public.customer_payments
  add column if not exists sales_rep_id uuid
    references public.sales_reps(id) on delete set null;

create index if not exists idx_customer_payments_sales_rep
  on public.customer_payments (company_id, sales_rep_id, created_at desc);

comment on column public.customer_payments.sales_rep_id is
  'Sales rep who collected this payment (null for admin/back-office payments)';

-- 2) get_rep_collections ----------------------------------------------------
create or replace function public.get_rep_collections(
  p_company_id   uuid,
  p_sales_rep_id uuid,
  p_from_date    date default null,
  p_to_date      date default null
)
returns table (
  id            uuid,
  customer_id   uuid,
  customer_name text,
  amount        numeric,
  method        text,
  reference     text,
  notes         text,
  created_at    timestamptz
)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $$
  select
    cp.id,
    cp.customer_id,
    c.name as customer_name,
    cp.amount,
    cp.method,
    cp.reference,
    cp.notes,
    cp.created_at
  from public.customer_payments cp
  left join public.customers c
    on c.id = cp.customer_id
   and c.company_id = cp.company_id
  where cp.company_id    = p_company_id
    and cp.sales_rep_id  = p_sales_rep_id
    and (p_from_date is null or cp.created_at::date >= p_from_date)
    and (p_to_date   is null or cp.created_at::date <= p_to_date)
  order by cp.created_at desc;
$$;

grant execute on function public.get_rep_collections(uuid, uuid, date, date)
  to authenticated;

-- 3) get_customer_unpaid_invoices -------------------------------------------
create or replace function public.get_customer_unpaid_invoices(
  p_company_id  uuid,
  p_customer_id uuid
)
returns table (
  id             uuid,
  invoice_number text,
  sale_date      timestamptz,
  total          numeric,
  paid_amount    numeric,
  remaining      numeric,
  payment_status text
)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $$
  select
    s.id,
    s.invoice_number,
    s.sale_date::timestamptz,
    s.total,
    s.paid_amount,
    (s.total - s.paid_amount) as remaining,
    s.payment_status
  from public.sales s
  where s.company_id    = p_company_id
    and s.customer_id   = p_customer_id
    and s.status        = 'confirmed'
    and s.paid_amount   < s.total
  order by s.sale_date asc;
$$;

grant execute on function public.get_customer_unpaid_invoices(uuid, uuid)
  to authenticated;

-- 4) create_rep_customer_payment --------------------------------------------
-- Wrapper around create_offline_customer_payment:
--   * keeps all validation, permissions, idempotency from the original
--   * tags the resulting payment with the current rep's sales_reps.id
create or replace function public.create_rep_customer_payment(
  p_company_id  uuid,
  p_client_uuid uuid,
  p_payload     jsonb
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_sales_rep_id uuid;
  v_payment_id   uuid;
begin
  -- Resolve current user's active sales_rep in this company (if any)
  select sr.id into v_sales_rep_id
    from public.sales_reps sr
   where sr.company_id = p_company_id
     and sr.user_id    = auth.uid()
     and sr.is_active  = true
   limit 1;

  -- Delegate to the canonical function (all checks live there)
  v_payment_id := public.create_offline_customer_payment(
    p_company_id, p_client_uuid, p_payload
  );

  -- Tag with sales_rep_id (no-op if already tagged by a previous call)
  if v_sales_rep_id is not null then
    update public.customer_payments
       set sales_rep_id = v_sales_rep_id
     where id = v_payment_id
       and sales_rep_id is null;
  end if;

  return v_payment_id;
end;
$$;

grant execute on function public.create_rep_customer_payment(uuid, uuid, jsonb)
  to authenticated;

-- 5) RLS hint (فقط لو RLS على customer_payments بيقيّد بالقراءة) ----------
-- (لو مفيش مشكلة حالياً، تجاهل هذا الجزء)
