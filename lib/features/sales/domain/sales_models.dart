import 'package:flutter/foundation.dart';

@immutable
class SaleSummary {
  final String id;
  final String? invoiceNumber;
  final String? customerId;
  final String customerName;
  final DateTime saleDate;
  final double subtotal;
  final double discount;
  final double total;
  final double paidAmount;
  final String paymentStatus; // 'unpaid' | 'partial' | 'paid'
  final String status;        // 'confirmed' | 'cancelled'
  final int itemCount;

  const SaleSummary({
    required this.id, this.invoiceNumber, this.customerId,
    required this.customerName, required this.saleDate,
    required this.subtotal, required this.discount, required this.total,
    required this.paidAmount, required this.paymentStatus,
    required this.status, required this.itemCount,
  });

  factory SaleSummary.fromJson(Map<String, dynamic> j) => SaleSummary(
    id: j['id'] as String,
    invoiceNumber: j['invoice_number'] as String?,
    customerId: j['customer_id'] as String?,
    customerName: j['customer_name'] as String? ?? 'عميل نقدي',
    saleDate: DateTime.parse(j['sale_date'] as String),
    subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
    discount: (j['discount'] as num?)?.toDouble() ?? 0,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    paidAmount: (j['paid_amount'] as num?)?.toDouble() ?? 0,
    paymentStatus: j['payment_status'] as String? ?? 'unpaid',
    status: j['status'] as String? ?? 'confirmed',
    itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
  );

  double get remaining => total - paidAmount;
  bool get isPaid => paymentStatus == 'paid';
  bool get isPartial => paymentStatus == 'partial';
  bool get isUnpaid => paymentStatus == 'unpaid';
  bool get isCancelled => status == 'cancelled';
}

@immutable
class SaleItemLine {
  final String id;
  final String productId;
  final String productName;
  final String unitId;
  final String unitName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  const SaleItemLine({
    required this.id, required this.productId, required this.productName,
    required this.unitId, required this.unitName,
    required this.quantity, required this.unitPrice, required this.lineTotal,
  });

  factory SaleItemLine.fromJson(Map<String, dynamic> j) => SaleItemLine(
    id: j['id'] as String,
    productId: j['product_id'] as String,
    productName: j['product_name'] as String? ?? 'منتج',
    unitId: j['unit_id'] as String,
    unitName: j['unit_name'] as String? ?? 'قطعة',
    quantity: (j['quantity'] as num).toDouble(),
    unitPrice: (j['unit_price'] as num).toDouble(),
    lineTotal: (j['line_total'] as num).toDouble(),
  );
}

@immutable
class SaleDetail {
  final String id;
  final String? invoiceNumber;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final DateTime saleDate;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;
  final double paidAmount;
  final String? notes;
  final List<SaleItemLine> items;

  const SaleDetail({
    required this.id, this.invoiceNumber, this.customerId,
    required this.customerName, this.customerPhone,
    required this.saleDate, required this.status, required this.paymentStatus,
    required this.subtotal, required this.discount, required this.taxAmount,
    required this.total, required this.paidAmount, this.notes,
    required this.items,
  });

  factory SaleDetail.fromJson(Map<String, dynamic> j) => SaleDetail(
    id: j['id'] as String,
    invoiceNumber: j['invoice_number'] as String?,
    customerId: j['customer_id'] as String?,
    customerName: j['customer_name'] as String? ?? 'عميل نقدي',
    customerPhone: j['customer_phone'] as String?,
    saleDate: DateTime.parse(j['sale_date'] as String),
    status: j['status'] as String? ?? 'confirmed',
    paymentStatus: j['payment_status'] as String? ?? 'unpaid',
    subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
    discount: (j['discount'] as num?)?.toDouble() ?? 0,
    taxAmount: (j['tax_amount'] as num?)?.toDouble() ?? 0,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    paidAmount: (j['paid_amount'] as num?)?.toDouble() ?? 0,
    notes: j['notes'] as String?,
    items: ((j['items'] as List?) ?? [])
        .map((e) => SaleItemLine.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  double get remaining => total - paidAmount;
}
