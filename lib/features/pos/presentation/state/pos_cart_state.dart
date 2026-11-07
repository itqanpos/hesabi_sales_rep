import 'package:flutter/foundation.dart';

import '../../domain/pos_models.dart';

/// لقطة ثابتة من حالة السلة.
@immutable
class PosCartState {
  final List<PosCartLine> lines;
  final PosCustomer? customer;
  final double discount;

  const PosCartState({
    this.lines = const <PosCartLine>[],
    this.customer,
    this.discount = 0,
  });

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get lineCount => lines.length;
  bool get hasCustomer => customer != null;
  double get customerBalance => customer?.balance ?? 0;

  double get subtotal =>
      lines.fold(0.0, (s, l) => s + l.lineTotal);

  double get total {
    final t = subtotal - discount;
    return t < 0 ? 0 : t;
  }

  PosCartState copyWith({
    List<PosCartLine>? lines,
    PosCustomer? customer,
    bool clearCustomer = false,
    double? discount,
  }) {
    return PosCartState(
      lines: lines ?? this.lines,
      customer: clearCustomer ? null : (customer ?? this.customer),
      discount: discount ?? this.discount,
    );
  }
}

/// متحكم السلة — يعتمد على ValueNotifier (بدون Riverpod).
class PosCartController extends ValueNotifier<PosCartState> {
  PosCartController() : super(const PosCartState());

  PosCartState get state => value;

  /// يضيف خط. يعيد `true` إذا كان دمجاً (المنتج موجود بنفس الوحدة).
  bool addLine({
    required String productId,
    required String productName,
    required String unitId,
    required String unitName,
    required double quantity,
    required double unitPrice,
    double? minPrice,
    double? maxPrice,
  }) {
    if (quantity <= 0) return false;

    final key = '$productId::$unitId';
    final next = <PosCartLine>[];
    bool merged = false;

    for (final line in value.lines) {
      if (line.key != key) {
        next.add(line);
        continue;
      }
      next.add(line.copyWith(quantity: line.quantity + quantity));
      merged = true;
    }

    if (!merged) {
      next.add(PosCartLine(
        productId: productId,
        productName: productName,
        unitId: unitId,
        unitName: unitName,
        quantity: quantity,
        unitPrice: unitPrice,
        minPrice: minPrice,
        maxPrice: maxPrice,
      ));
    }

    value = value.copyWith(lines: next);
    return merged;
  }

  void updateQuantity(int index, double quantity) {
    if (index < 0 || index >= value.lines.length) return;
    final next = List<PosCartLine>.from(value.lines);
    if (quantity <= 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].copyWith(quantity: quantity);
    }
    value = value.copyWith(lines: next);
  }

  void updatePrice(int index, double price) {
    if (index < 0 || index >= value.lines.length || price < 0) return;
    final next = List<PosCartLine>.from(value.lines);
    next[index] = next[index].copyWith(unitPrice: price);
    value = value.copyWith(lines: next);
  }

  void removeLine(int index) {
    if (index < 0 || index >= value.lines.length) return;
    final next = List<PosCartLine>.from(value.lines)..removeAt(index);
    value = value.copyWith(lines: next);
  }

  void setCustomer(PosCustomer? customer) {
    value = customer == null
        ? value.copyWith(clearCustomer: true)
        : value.copyWith(customer: customer);
  }

  void setDiscount(double discount) {
    final max = value.subtotal * 0.5;
    value = value.copyWith(
      discount: discount < 0 ? 0 : (discount > max ? max : discount),
    );
  }

  void clear() => value = const PosCartState();

  void restore(PosCartState snapshot) => value = snapshot;
}
