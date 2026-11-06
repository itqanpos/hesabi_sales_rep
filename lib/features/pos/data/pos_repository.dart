import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/pos_models.dart';

class PosRepository {
  final SupabaseClient _client;
  PosRepository(this._client);

  Future<List<PosProduct>> loadProducts(String companyId, String branchId) async {
    final res = await _client.rpc('get_pos_catalogue', params: {
      'p_company_id': companyId, 'p_branch_id': branchId,
    });
    return (res as List).cast<Map<String, dynamic>>().map(PosProduct.fromJson).toList();
  }

  Future<List<PosCustomer>> loadCustomers(String companyId) async {
    final res = await _client.rpc('get_pos_customers', params: {'p_company_id': companyId});
    return (res as List).cast<Map<String, dynamic>>().map(PosCustomer.fromJson).toList();
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
    final totalPaid = isCredit ? 0.0 : payments.fold<double>(0, (s, p) => s + p.amount);
    final primaryMethod = isCredit ? null : payments.first.method;

    // ✅ 1. حساب إجمالي الفاتورة الحالية
    final subtotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final saleTotal = subtotal - discount;

    // ✅ 2. تحديد المبلغ الذي سيُسجل على الفاتورة، والمبلغ الزائد لرصيد العميل
    final appliedToSale = totalPaid > saleTotal ? saleTotal : totalPaid;
    final appliedToBalance = totalPaid > saleTotal ? (totalPaid - saleTotal) : 0.0;

    // ✅ 3. إنشاء الفاتورة بالمبلغ الصحيح
    final result = await _client.rpc('create_rep_sale', params: {
      'p_company_id': companyId,
      'p_client_uuid': const Uuid().v4(),
      'p_payload': {
        'customer_id': customerId,
        'items': lines.map((l) => l.toSaleItem()).toList(),
        'payment_method': primaryMethod,
        'paid_amount': appliedToSale, // لا يتجاوز إجمالي الفاتورة
        'discount': discount,
        'notes': notes,
      },
    });

    final saleId = result as String;

    // ✅ 4. إذا دفع العميل أكثر من قيمة الفاتورة (لتسوية رصيد سابق)
    // نقوم بتسجيل الدفعة الزائدة في جدول customer_payments
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
        // لا نريد أن تفشل الفاتورة إذا فشل تسجيل الدفعة الزائدة
        // يمكن تسجيل الخطأ هنا في السجلات مستقبلاً
        print('Failed to record balance payment: $e');
      }
    }

    return saleId;
  }
}
