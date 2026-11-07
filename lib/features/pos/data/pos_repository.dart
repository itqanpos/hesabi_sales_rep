import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/pos_models.dart';

class PosRepository {
  final SupabaseClient _client;
  PosRepository(this._client);

  Future<List<PosProduct>> loadProducts(
      String companyId, String branchId) async {
    final res = await _client.rpc('get_pos_catalogue', params: {
      'p_company_id': companyId,
      'p_branch_id': branchId,
    });
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(PosProduct.fromJson)
        .toList();
  }

  Future<List<PosCustomer>> loadCustomers(String companyId) async {
    final res = await _client.rpc('get_pos_customers', params: {
      'p_company_id': companyId,
    });
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(PosCustomer.fromJson)
        .toList();
  }

  Future<String> createSale({
    required String companyId,
    required String? customerId,
    required List<PosCartLine> lines,
    required List<PaymentEntry> payments,
    required double discount,
    String? notes,
  }) async {
    if (lines.isEmpty) throw Exception('السلة فارغة');

    final isCredit = payments.isEmpty;
    final totalPaid =
        isCredit ? 0.0 : payments.fold<double>(0, (s, p) => s + p.amount);
    final primaryMethod = isCredit ? null : payments.first.method;

    // ─── حساب الفاتورة ───
    final subtotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final saleTotal = subtotal - discount;

    // ═══════════════════════════════════════════════════════════════════
    // 🔴 الحماية الحرجة: paid_amount لا يتجاوز total أبداً
    //    (CHECK constraint: sales_paid_amount_not_exceeding_total)
    // ═══════════════════════════════════════════════════════════════════
    final double appliedToSale =
        (totalPaid > saleTotal) ? saleTotal : totalPaid;
    final double appliedToBalance =
        (totalPaid > saleTotal) ? (totalPaid - saleTotal) : 0.0;

    // ─── إنشاء الفاتورة ───
    final result = await _client.rpc('create_rep_sale', params: {
      'p_company_id': companyId,
      'p_client_uuid': const Uuid().v4(),
      'p_payload': {
        'customer_id': customerId,
        'items': lines.map((l) => l.toSaleItem()).toList(),
        'payment_method': primaryMethod,
        // ✅ القيمة المحسوبة — لا تتجاوز saleTotal
        'paid_amount': appliedToSale,
        'discount': discount,
        'notes': notes,
      },
    });

    final saleId = result as String;

    // ─── تسجيل الزيادة على رصيد العميل ───
    if (appliedToBalance > 0 && customerId != null) {
      try {
        await _client.rpc('create_offline_customer_payment', params: {
          'p_company_id': companyId,
          'p_client_uuid': const Uuid().v4(),
          'p_payload': {
            'customer_id': customerId,
            'amount': appliedToBalance,
            'method': primaryMethod ?? 'cash',
            'notes': 'دفعة زيادة من فاتورة رقم: ${saleId.substring(0, 6)}',
          },
        });
      } catch (e) {
        // تجاهل — لا نفشل البيع بسبب فشل تسجيل الزيادة
        print('Failed to record balance payment: $e');
      }
    }

    return saleId;
  }
}
