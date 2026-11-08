import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/return_models.dart';

class ReturnsRepository {
  final SupabaseClient _sb;
  ReturnsRepository(this._sb);

  Future<List<ReturnEntry>> listReturns({
    required String companyId,
    required String salesRepId,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _sb.rpc('get_rep_returns', params: {
      'p_company_id': companyId,
      'p_sales_rep_id': salesRepId,
      'p_from_date': from == null ? null : _dateStr(from),
      'p_to_date': to == null ? null : _dateStr(to),
    });
    return (res as List)
        .map((e) => ReturnEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReturnCustomer>> searchCustomers({
    required String companyId,
    String query = '',
  }) async {
    final res = await _sb.rpc('get_pos_customers', params: {
      'p_company_id': companyId,
    });
    final q = query.trim().toLowerCase();
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(ReturnCustomer.fromJson)
        .where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              (c.phone ?? '').toLowerCase().contains(q);
        })
        .toList();
  }

  Future<List<ReturnableSale>> getReturnableSales({
    required String companyId,
    required String customerId,
    int limit = 20,
  }) async {
    final res = await _sb.rpc('get_returnable_sales', params: {
      'p_company_id': companyId,
      'p_customer_id': customerId,
      'p_limit': limit,
    });
    return (res as List)
        .map((e) => ReturnableSale.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReturnableSaleItem>> getReturnableSaleItems({
    required String companyId,
    required String saleId,
  }) async {
    final res = await _sb.rpc('get_returnable_sale_items', params: {
      'p_company_id': companyId,
      'p_sale_id': saleId,
    });
    return (res as List)
        .map((e) => ReturnableSaleItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FreeReturnProduct>> searchFreeReturnProducts({
    required String companyId,
    String query = '',
    int limit = 30,
  }) async {
    var q = _sb
        .from('products')
        .select('id, name, default_unit_id, selling_price')
        .eq('company_id', companyId)
        .eq('is_active', true);
    final qs = query.trim();
    if (qs.isNotEmpty) q = q.ilike('name', '%$qs%');

    final rows = await q.order('name').limit(limit);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];

    final unitIds = <String>{
      for (final p in list)
        if (p['default_unit_id'] != null) p['default_unit_id'] as String
    }.toList();

    final unitMap = <String, String>{};
    if (unitIds.isNotEmpty) {
      final ures = await _sb
          .from('units')
          .select('id, name')
          .eq('company_id', companyId)
          .inFilter('id', unitIds);
      for (final u in (ures as List)) {
        unitMap[u['id'] as String] = (u['name'] as String?) ?? '';
      }
    }

    return list.map((p) {
      final uid = p['default_unit_id'] as String?;
      return FreeReturnProduct(
        id: p['id'] as String,
        name: p['name'] as String,
        unitId: uid,
        unitName: unitMap[uid] ?? '',
        price: (p['selling_price'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<String> createReturn({
    required String companyId,
    required String? customerId,
    required String? saleId,
    required String refundMethod,
    required List<ReturnLineInput> items,
    String? notes,
  }) async {
    final res = await _sb.rpc('create_rep_sale_return_v2', params: {
      'p_company_id': companyId,
      'p_client_uuid': const Uuid().v4(),
      'p_payload': {
        if (saleId != null) 'sale_id': saleId,
        if (customerId != null) 'customer_id': customerId,
        'refund_method': refundMethod,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'items': items.map((i) => i.toJson()).toList(),
      },
    });
    return res as String;
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
