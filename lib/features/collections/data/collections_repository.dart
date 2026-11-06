import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/collection_models.dart';

class CollectionsRepository {
  final SupabaseClient _sb;
  CollectionsRepository(this._sb);

  Future<List<CollectionEntry>> listCollections({
    required String companyId,
    required String salesRepId,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _sb.rpc('get_rep_collections', params: {
      'p_company_id': companyId,
      'p_sales_rep_id': salesRepId,
      'p_from_date': from == null ? null : _dateStr(from),
      'p_to_date': to == null ? null : _dateStr(to),
    });
    return (res as List)
        .map((e) => CollectionEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CollectionCustomer>> searchCustomers({
    required String companyId,
    String query = '',
  }) async {
    final res = await _sb.rpc('get_pos_customers', params: {
      'p_company_id': companyId,
    });
    final q = query.trim().toLowerCase();
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(CollectionCustomer.fromJson)
        .where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              (c.phone ?? '').toLowerCase().contains(q);
        })
        .toList();
  }

  /// فواتير العميل — للمرجعية فقط (بدون "متبقي")
  Future<List<CustomerInvoice>> getCustomerInvoices({
    required String companyId,
    required String customerId,
    int limit = 20,
  }) async {
    final res = await _sb.rpc('get_customer_invoices', params: {
      'p_company_id': companyId,
      'p_customer_id': customerId,
      'p_limit': limit,
    });
    return (res as List)
        .map((e) => CustomerInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ⚠️ deprecated — استخدم getCustomerInvoices
  Future<List<UnpaidInvoice>> getCustomerUnpaidInvoices({
    required String companyId,
    required String customerId,
  }) async {
    final res = await _sb.rpc('get_customer_unpaid_invoices', params: {
      'p_company_id': companyId,
      'p_customer_id': customerId,
    });
    return (res as List)
        .map((e) => UnpaidInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createPayment({
    required String companyId,
    required String customerId,
    required double amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    final res = await _sb.rpc('create_rep_customer_payment', params: {
      'p_company_id': companyId,
      'p_client_uuid': const Uuid().v4(),
      'p_payload': {
        'customer_id': customerId,
        'amount': amount,
        'method': method,
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    });
    return res as String;
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
