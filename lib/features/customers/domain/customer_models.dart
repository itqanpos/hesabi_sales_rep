import 'package:intl/intl.dart';

class CustomerSummary {
  final String id;
  final String name;
  final String? phone;
  final double balance;

  const CustomerSummary({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> j) => CustomerSummary(
        id: j['id'] as String,
        name: (j['name'] ?? j['customer_name'] ?? '') as String,
        phone: j['phone'] as String?,
        balance:
            ((j['balance'] ?? j['current_balance'] ?? 0) as num).toDouble(),
      );

  bool get hasDebt => balance > 0.001;
  bool get hasCredit => balance < -0.001;
}

class StatementEntry {
  final String type; // 'sale' | 'payment'
  final String id;
  final DateTime date;
  final String? refNumber;
  final String? method;
  final double amount;
  final double? paidAmount; // sale only
  final double? remaining; // sale only
  final String? notes;

  const StatementEntry({
    required this.type,
    required this.id,
    required this.date,
    this.refNumber,
    this.method,
    required this.amount,
    this.paidAmount,
    this.remaining,
    this.notes,
  });

  factory StatementEntry.fromJson(Map<String, dynamic> j) => StatementEntry(
        type: j['entry_type'] as String,
        id: j['entry_id'] as String,
        date: DateTime.parse(j['entry_date'] as String),
        refNumber: j['ref_number'] as String?,
        method: j['method'] as String?,
        amount: (j['amount'] as num).toDouble(),
        paidAmount: (j['paid_amount'] as num?)?.toDouble(),
        remaining: (j['remaining'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
      );

  bool get isSale => type == 'sale';
  bool get isPayment => type == 'payment';

  /// التأثير على رصيد العميل: موجب = يزيد المديونية، سالب = يقللها
  double get balanceEffect {
    if (isSale) return (remaining ?? amount);
    return -amount;
  }

  String get methodLabel => switch (method) {
        'cash' => 'نقدي',
        'card' => 'بطاقة',
        'transfer' => 'تحويل',
        'instapay' => 'إنستاباي',
        'bank_transfer' => 'تحويل بنكي',
        'other' => 'أخرى',
        _ => method ?? '',
      };
}

String fmtMoney(double v) {
  final f = NumberFormat('#,##0.00', 'en');
  return '${f.format(v)} ج.م';
}

String fmtDate(DateTime d) => DateFormat('yyyy/MM/dd', 'en').format(d);
String fmtDateTime(DateTime d) => DateFormat('yyyy/MM/dd HH:mm', 'en').format(d);
