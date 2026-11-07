import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/customer_models.dart';

class CustomersRepository {
  final SupabaseClient _sb;
  CustomersRepository(this._sb);

  Future<List<CustomerSummary>> listCustomers({
    required String companyId,
    String query = '',
  }) async {
    final res = await _sb.rpc('get_pos_customers', params: {
      'p_company_id': companyId,
    });
    final list = (res as List)
        .cast<Map<String, dynamic>>()
        .map(CustomerSummary.fromJson)
        .toList();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.phone ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<List<StatementEntry>> getStatement({
    required String companyId,
    required String customerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _sb.rpc('get_customer_statement', params: {
      'p_company_id': companyId,
      'p_customer_id': customerId,
      'p_from_date': from == null ? null : _dateStr(from),
      'p_to_date': to == null ? null : _dateStr(to),
    });
    return (res as List)
        .map((e) => StatementEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createCustomer({
    required String companyId,
    required String name,
    String? phone,
    String? address,
  }) async {
    final res = await _sb.rpc('create_rep_customer', params: {
      'p_company_id': companyId,
      'p_name': name,
      'p_phone': phone,
      'p_address': address,
    });
    return res as String;
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
