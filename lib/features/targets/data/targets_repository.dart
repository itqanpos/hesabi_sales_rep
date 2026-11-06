import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/targets_models.dart';

class TargetsRepository {
  final SupabaseClient _sb;
  TargetsRepository(this._sb);

  Future<RepTargetInfo> load({
    required String companyId,
    required String salesRepId,
  }) async {
    final res = await _sb.rpc('get_rep_targets_commissions', params: {
      'p_company_id': companyId,
      'p_sales_rep_id': salesRepId,
    });
    return RepTargetInfo.fromJson((res as Map).cast<String, dynamic>());
  }
}
