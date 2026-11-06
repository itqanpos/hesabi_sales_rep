import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/visit_models.dart';

class VisitsRepository {
  final SupabaseClient _sb;
  VisitsRepository(this._sb);

  Future<List<VisitEntry>> listVisits({
    required String companyId,
    required String salesRepId,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _sb.rpc('get_rep_visits', params: {
      'p_company_id': companyId,
      'p_sales_rep_id': salesRepId,
      'p_from_date': from == null ? null : _dateStr(from),
      'p_to_date': to == null ? null : _dateStr(to),
    });
    return (res as List)
        .map((e) => VisitEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VisitCustomer>> searchCustomers({
    required String companyId,
    String query = '',
  }) async {
    final res = await _sb.rpc('get_pos_customers', params: {
      'p_company_id': companyId,
    });
    final q = query.trim().toLowerCase();
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(VisitCustomer.fromJson)
        .where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              (c.phone ?? '').toLowerCase().contains(q);
        })
        .toList();
  }

  Future<String> createVisit({
    required String companyId,
    required String salesRepId,
    String? customerId,
    required String purpose,
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _sb.rpc('create_rep_visit', params: {
      'p_company_id': companyId,
      'p_sales_rep_id': salesRepId,
      'p_customer_id': customerId,
      'p_purpose': purpose,
      'p_notes': notes,
      'p_latitude': latitude,
      'p_longitude': longitude,
    });
    return res as String;
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
