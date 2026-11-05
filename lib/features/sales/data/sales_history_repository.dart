import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/sales_models.dart';

class SalesHistoryRepository {
  final SupabaseClient _client;
  SalesHistoryRepository(this._client);

  Future<List<SaleSummary>> listSales({
    required String companyId,
    required String salesRepId,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 100,
  }) async {
    final res = await _client.rpc('get_rep_sales', params: {
      'p_company_id': companyId,
      'p_sales_rep_id': salesRepId,
      'p_from_date': fromDate?.toUtc().toIso8601String(),
      'p_to_date': toDate?.toUtc().toIso8601String(),
      'p_search': (search?.trim().isEmpty ?? true) ? null : search!.trim(),
      'p_limit': limit,
    });
    return (res as List).cast<Map<String, dynamic>>().map(SaleSummary.fromJson).toList();
  }

  Future<SaleDetail?> getSaleDetail({
    required String saleId,
    required String companyId,
  }) async {
    final res = await _client.rpc('get_rep_sale_detail', params: {
      'p_sale_id': saleId,
      'p_company_id': companyId,
    });
    if (res == null) return null;
    return SaleDetail.fromJson(res as Map<String, dynamic>);
  }
}
