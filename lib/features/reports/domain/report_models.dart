class RepReport {
  final double salesTotal;
  final int salesCount;
  final double collectionsTotal;
  final int collectionsCount;
  final double returnsTotal;
  final int returnsCount;
  final double netTotal;
  final List<DailySale> dailySales;
  final List<MethodBreakdown> byMethod;
  final List<TopProduct> topProducts;
  final List<TopCustomer> topCustomers;
  final double debtsTotal;
  final List<DebtCustomer> debts;

  const RepReport({
    required this.salesTotal,
    required this.salesCount,
    required this.collectionsTotal,
    required this.collectionsCount,
    required this.returnsTotal,
    required this.returnsCount,
    required this.netTotal,
    required this.dailySales,
    required this.byMethod,
    required this.topProducts,
    required this.topCustomers,
    required this.debtsTotal,
    required this.debts,
  });

  factory RepReport.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        (v as List? ?? [])
            .map((e) => f((e as Map).cast<String, dynamic>()))
            .toList();

    return RepReport(
      salesTotal: n(j['sales_total']),
      salesCount: i(j['sales_count']),
      collectionsTotal: n(j['collections_total']),
      collectionsCount: i(j['collections_count']),
      returnsTotal: n(j['returns_total']),
      returnsCount: i(j['returns_count']),
      netTotal: n(j['net_total']),
      dailySales: list(j['daily_sales'], DailySale.fromJson),
      byMethod: list(j['by_method'], MethodBreakdown.fromJson),
      topProducts: list(j['top_products'], TopProduct.fromJson),
      topCustomers: list(j['top_customers'], TopCustomer.fromJson),
      debtsTotal: n(j['debts_total']),
      debts: list(j['debts'], DebtCustomer.fromJson),
    );
  }

  bool get isEmpty =>
      salesCount == 0 && collectionsCount == 0 && returnsCount == 0;
}

class DailySale {
  final DateTime day;
  final double total;
  final int invoices;

  const DailySale({
    required this.day,
    required this.total,
    required this.invoices,
  });

  factory DailySale.fromJson(Map<String, dynamic> j) => DailySale(
        day: DateTime.parse(j['day'] as String),
        total: (j['total'] as num?)?.toDouble() ?? 0,
        invoices: (j['invoices'] as num?)?.toInt() ?? 0,
      );
}

class MethodBreakdown {
  final String method;
  final double total;
  final int count;

  const MethodBreakdown({
    required this.method,
    required this.total,
    required this.count,
  });

  factory MethodBreakdown.fromJson(Map<String, dynamic> j) => MethodBreakdown(
        method: (j['method'] as String?) ?? 'other',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );

  String get label => switch (method) {
        'cash' => 'نقدي',
        'card' => 'بطاقة',
        'transfer' => 'تحويل',
        'instapay' => 'إنستاباي',
        'bank_transfer' => 'تحويل بنكي',
        'other' => 'أخرى',
        _ => method,
      };
}

class TopProduct {
  final String productId;
  final String productName;
  final double qty;
  final double total;

  const TopProduct({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.total,
  });

  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
        productId: j['product_id'] as String,
        productName: (j['product_name'] as String?) ?? '',
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

class TopCustomer {
  final String customerId;
  final String customerName;
  final double total;
  final int invoices;

  const TopCustomer({
    required this.customerId,
    required this.customerName,
    required this.total,
    required this.invoices,
  });

  factory TopCustomer.fromJson(Map<String, dynamic> j) => TopCustomer(
        customerId: j['customer_id'] as String,
        customerName: (j['customer_name'] as String?) ?? '',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        invoices: (j['invoices'] as num?)?.toInt() ?? 0,
      );
}

class DebtCustomer {
  final String customerId;
  final String customerName;
  final String? phone;
  final double balance;

  const DebtCustomer({
    required this.customerId,
    required this.customerName,
    this.phone,
    required this.balance,
  });

  factory DebtCustomer.fromJson(Map<String, dynamic> j) => DebtCustomer(
        customerId: j['customer_id'] as String,
        customerName: (j['customer_name'] as String?) ?? '',
        phone: j['phone'] as String?,
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
      );
}
