import 'package:flutter/foundation.dart';

@immutable
class PosProduct {
  final String id;
  final String name;
  final String defaultUnitId;
  final String defaultUnitName;
  final double defaultPrice;
  final double? minPrice;
  final double? maxPrice;
  final String? barcode;
  final String? sku;
  final double stockQty;
  final List<PosProductUnit> extraUnits;

  const PosProduct({
    required this.id, required this.name, required this.defaultUnitId,
    required this.defaultUnitName, required this.defaultPrice,
    this.minPrice, this.maxPrice, this.barcode, this.sku,
    required this.stockQty, required this.extraUnits,
  });

  factory PosProduct.fromJson(Map<String, dynamic> j) => PosProduct(
    id: j['product_id'] as String,
    name: j['product_name'] as String,
    defaultUnitId: j['default_unit_id'] as String,
    defaultUnitName: j['default_unit_name'] as String? ?? 'قطعة',
    defaultPrice: (j['default_price'] as num?)?.toDouble() ?? 0,
    minPrice: (j['min_price'] as num?)?.toDouble(),
    maxPrice: (j['max_price'] as num?)?.toDouble(),
    barcode: j['barcode'] as String?,
    sku: j['sku'] as String?,
    stockQty: (j['stock_qty'] as num?)?.toDouble() ?? 0,
    extraUnits: (j['extra_units'] as List<dynamic>?)
            ?.map((e) => PosProductUnit.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
  );

  List<PosProductUnit> get allUnits => [
    PosProductUnit(
      unitId: defaultUnitId, unitName: defaultUnitName,
      conversionFactor: 1, sellingPrice: defaultPrice,
      minPrice: minPrice, maxPrice: maxPrice, isBase: true,
    ),
    ...extraUnits,
  ];

  bool get hasStock => stockQty > 0;
  bool get hasMultipleUnits => extraUnits.isNotEmpty;
}

@immutable
class PosProductUnit {
  final String? id;
  final String unitId;
  final String unitName;
  final double conversionFactor;
  final double? sellingPrice;
  final double? minPrice;
  final double? maxPrice;
  final bool isBase;

  const PosProductUnit({
    this.id, required this.unitId, required this.unitName,
    required this.conversionFactor, this.sellingPrice,
    this.minPrice, this.maxPrice, this.isBase = false,
  });

  factory PosProductUnit.fromJson(Map<String, dynamic> j) => PosProductUnit(
    id: j['id'] as String?,
    unitId: j['unit_id'] as String,
    unitName: j['unit_name'] as String,
    conversionFactor: (j['conversion_factor'] as num).toDouble(),
    sellingPrice: (j['selling_price'] as num?)?.toDouble(),
    minPrice: (j['min_selling_price'] as num?)?.toDouble(),
    maxPrice: (j['max_selling_price'] as num?)?.toDouble(),
  );

  double effectivePrice(double basePrice) => sellingPrice ?? basePrice * conversionFactor;
  double? effectiveMin(double? baseMin) => minPrice ?? (baseMin != null ? baseMin * conversionFactor : null);
  double? effectiveMax(double? baseMax) => maxPrice ?? (baseMax != null ? baseMax * conversionFactor : null);
}

@immutable
class PosCustomer {
  final String id;
  final String name;
  final String? phone;
  final double balance;

  const PosCustomer({required this.id, required this.name, this.phone, required this.balance});

  factory PosCustomer.fromJson(Map<String, dynamic> j) => PosCustomer(
    id: j['id'] as String, name: j['name'] as String,
    phone: j['phone'] as String?,
    balance: (j['balance'] as num?)?.toDouble() ?? 0,
  );

  bool get hasDebt => balance > 0;
}

@immutable
class PosCartLine {
  final String productId;
  final String productName;
  final String unitId;
  final String unitName;
  final double quantity;
  final double unitPrice;
  final double? minPrice;
  final double? maxPrice;

  const PosCartLine({
    required this.productId, required this.productName,
    required this.unitId, required this.unitName,
    required this.quantity, required this.unitPrice,
    this.minPrice, this.maxPrice,
  });

  String get key => '$productId::$unitId';
  double get lineTotal => quantity * unitPrice;

  PosCartLine copyWith({double? quantity, double? unitPrice}) => PosCartLine(
    productId: productId, productName: productName,
    unitId: unitId, unitName: unitName,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    minPrice: minPrice, maxPrice: maxPrice,
  );

  Map<String, dynamic> toSaleItem() => {
    'product_id': productId, 'unit_id': unitId,
    'quantity': quantity, 'unit_price': unitPrice,
  };
}

@immutable
class PaymentEntry {
  final String method;
  final double amount;

  const PaymentEntry({required this.method, required this.amount});

  Map<String, dynamic> toJson() => {'method': method, 'amount': amount};

  static const List<String> methods = ['cash','card','instapay','bank_transfer','other'];

  static String label(String m) => {
    'cash': 'نقدي', 'card': 'بطاقة', 'instapay': 'إنستاباي',
    'bank_transfer': 'تحويل بنكي', 'other': 'أخرى', 'credit': 'آجل',
  }[m] ?? m;
}
