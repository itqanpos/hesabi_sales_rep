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
