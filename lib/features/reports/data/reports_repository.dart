import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/report_models.dart';

class ReportsRepository {
  final SupabaseClient _sb;
  ReportsRepository(this._sb);

  Future<RepReport> loadReport({
    required String companyId,
    required String salesRepId,
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _sb.rpc('get_rep_reports', params: {
      'p_company_id': companyId,
      'p_sales_rep_id': salesRepId,
      'p_from_date': _dateStr(from),
      'p_to_date': _dateStr(to),
    });
    return RepReport.fromJson((res as Map).cast<String, dynamic>());
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
