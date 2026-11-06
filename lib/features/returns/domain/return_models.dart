class ReturnEntry {
  final String id;
  final String returnNumber;
  final DateTime returnDate;
  final double total;
  final String status;
  final String refundMethod;
  final String? customerId;
  final String? customerName;
  final String? saleId;
  final String? invoiceNumber;
  final String? notes;

  const ReturnEntry({
    required this.id,
    required this.returnNumber,
    required this.returnDate,
    required this.total,
    required this.status,
    required this.refundMethod,
    this.customerId,
    this.customerName,
    this.saleId,
    this.invoiceNumber,
    this.notes,
  });

  factory ReturnEntry.fromJson(Map<String, dynamic> j) => ReturnEntry(
        id: j['id'] as String,
        returnNumber: (j['return_number'] as String?) ?? '—',
        returnDate: DateTime.parse(j['return_date'] as String),
        total: (j['total'] as num?)?.toDouble() ?? 0,
        status: (j['status'] as String?) ?? 'draft',
        refundMethod: (j['refund_method'] as String?) ?? 'credit_note',
        customerId: j['customer_id'] as String?,
        customerName: j['customer_name'] as String?,
        saleId: j['sale_id'] as String?,
        invoiceNumber: j['invoice_number'] as String?,
        notes: j['notes'] as String?,
      );

  bool get isLinked => saleId != null;
  String get refundLabel => refundLabelOf(refundMethod);
  String get statusLabel => switch (status) {
        'draft' => 'مسودة',
        'confirmed' => 'مؤكد',
        'cancelled' => 'ملغي',
        _ => status,
      };
}

class ReturnCustomer {
  final String id;
  final String name;
  final String? phone;
  final double balance;

  const ReturnCustomer({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
  });

  factory ReturnCustomer.fromJson(Map<String, dynamic> j) => ReturnCustomer(
        id: j['id'] as String,
        name: (j['name'] ?? j['customer_name'] ?? '') as String,
        phone: j['phone'] as String?,
        balance: ((j['balance'] ?? j['current_balance'] ?? 0) as num).toDouble(),
      );
}

class ReturnableSale {
  final String id;
  final String invoiceNumber;
  final DateTime saleDate;
  final double total;

  const ReturnableSale({
    required this.id,
    required this.invoiceNumber,
    required this.saleDate,
    required this.total,
  });

  factory ReturnableSale.fromJson(Map<String, dynamic> j) => ReturnableSale(
        id: j['id'] as String,
        invoiceNumber: (j['invoice_number'] as String?) ?? '—',
        saleDate: DateTime.parse(j['sale_date'] as String),
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

class ReturnableSaleItem {
  final String id;
  final String productId;
  final String productName;
  final String unitId;
  final String unitName;
  final double quantity;
  final double alreadyReturned;
  final double unitPrice;

  const ReturnableSaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitId,
    required this.unitName,
    required this.quantity,
    required this.alreadyReturned,
    required this.unitPrice,
  });

  factory ReturnableSaleItem.fromJson(Map<String, dynamic> j) =>
      ReturnableSaleItem(
        id: j['id'] as String,
        productId: j['product_id'] as String,
        productName: (j['product_name'] as String?) ?? '',
        unitId: j['unit_id'] as String,
        unitName: (j['unit_name'] as String?) ?? '',
        quantity: (j['quantity'] as num).toDouble(),
        alreadyReturned: (j['already_returned'] as num?)?.toDouble() ?? 0,
        unitPrice: (j['unit_price'] as num).toDouble(),
      );

  double get returnableQty => (quantity - alreadyReturned).clamp(0, double.infinity);
  bool get canReturn => returnableQty > 0.001;
}

class FreeReturnProduct {
  final String id;
  final String name;
  final String? unitId;
  final String unitName;
  final double price;

  const FreeReturnProduct({
    required this.id,
    required this.name,
    this.unitId,
    required this.unitName,
    required this.price,
  });
}

class FreeReturnCartLine {
  final FreeReturnProduct product;
  double quantity;
  double price;

  FreeReturnCartLine({
    required this.product,
    this.quantity = 1,
    required this.price,
  });

  double get lineTotal => quantity * price;
}

class ReturnLineInput {
  final String productId;
  final String unitId;
  final double quantity;
  final double unitPrice;
  final String? saleItemId;

  const ReturnLineInput({
    required this.productId,
    required this.unitId,
    required this.quantity,
    required this.unitPrice,
    this.saleItemId,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'unit_id': unitId,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (saleItemId != null) 'sale_item_id': saleItemId,
      };
}

// ─── Constants + Helpers ────────────────────────────────────────────────────

const kRefundMethods = <String>['credit_note', 'cash'];

String refundLabelOf(String method) => switch (method) {
      'credit_note' => 'رصيد دائن على العميل',
      'cash' => 'استرداد نقدي',
      _ => method,
    };

const kReturnReasons = <String>[
  'عيب في المنتج',
  'خطأ في الطلب',
  'إلغاء من العميل',
  'انتهاء الصلاحية',
  'أخرى',
];
