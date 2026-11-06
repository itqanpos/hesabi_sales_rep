class CollectionEntry {
  final String id;
  final String customerId;
  final String? customerName;
  final double amount;
  final String method;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  const CollectionEntry({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.amount,
    required this.method,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  factory CollectionEntry.fromJson(Map<String, dynamic> j) => CollectionEntry(
        id: j['id'] as String,
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String?,
        amount: (j['amount'] as num).toDouble(),
        method: (j['method'] as String?) ?? 'cash',
        reference: j['reference'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get methodLabel => methodLabelOf(method);
}

class UnpaidInvoice {
  final String id;
  final String invoiceNumber;
  final DateTime saleDate;
  final double total;
  final double paidAmount;
  final double remaining;
  final String paymentStatus;

  const UnpaidInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.saleDate,
    required this.total,
    required this.paidAmount,
    required this.remaining,
    required this.paymentStatus,
  });

  factory UnpaidInvoice.fromJson(Map<String, dynamic> j) => UnpaidInvoice(
        id: j['id'] as String,
        invoiceNumber: (j['invoice_number'] as String?) ?? '—',
        saleDate: DateTime.parse(j['sale_date'] as String),
        total: (j['total'] as num).toDouble(),
        paidAmount: (j['paid_amount'] as num).toDouble(),
        remaining: (j['remaining'] as num).toDouble(),
        paymentStatus: (j['payment_status'] as String?) ?? 'unpaid',
      );
}

/// فاتورة العميل — للمرجعية فقط (بدون "متبقي" لأنه مضلل)
class CustomerInvoice {
  final String id;
  final String invoiceNumber;
  final DateTime saleDate;
  final double total;
  final double paidAtSale;
  final String paymentStatus;

  const CustomerInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.saleDate,
    required this.total,
    required this.paidAtSale,
    required this.paymentStatus,
  });

  factory CustomerInvoice.fromJson(Map<String, dynamic> j) =>
      CustomerInvoice(
        id: j['id'] as String,
        invoiceNumber: (j['invoice_number'] as String?) ?? '—',
        saleDate: DateTime.parse(j['sale_date'] as String),
        total: (j['total'] as num).toDouble(),
        paidAtSale: (j['paid_at_sale'] as num?)?.toDouble() ?? 0,
        paymentStatus: (j['payment_status'] as String?) ?? 'unpaid',
      );

  bool get fullyPaidAtSale => paidAtSale >= total - 0.001;
  double get unpaidAtSale =>
      fullyPaidAtSale ? 0 : (total - paidAtSale);
}

class CollectionCustomer {
  final String id;
  final String name;
  final String? phone;
  final double balance;

  const CollectionCustomer({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
  });

  factory CollectionCustomer.fromJson(Map<String, dynamic> j) {
    return CollectionCustomer(
      id: j['id'] as String,
      name: (j['name'] ?? j['customer_name'] ?? '') as String,
      phone: j['phone'] as String?,
      balance: ((j['balance'] ?? j['current_balance'] ?? 0) as num).toDouble(),
    );
  }
}

/// قيم `method` المسموحة من قاعدة البيانات
const kPaymentMethods = <String>[
  'cash',
  'card',
  'transfer',
  'instapay',
  'bank_transfer',
  'other',
];

String methodLabelOf(String method) => switch (method) {
      'cash' => 'نقدي',
      'card' => 'بطاقة',
      'transfer' => 'تحويل',
      'instapay' => 'إنستاباي',
      'bank_transfer' => 'تحويل بنكي',
      'other' => 'أخرى',
      _ => method,
    };
