import 'package:flutter/foundation.dart';

import '../../domain/pos_models.dart';

// ============================================================================
// PosCartState — لقطة ثابتة (immutable) من حالة السلة
// ============================================================================

@immutable
class PosCartState {
  final List<PosCartLine> lines;
  final PosCustomer? customer;
  final double discount;
  final double taxAmount;

  const PosCartState({
    this.lines = const <PosCartLine>[],
    this.customer,
    this.discount = 0,
    this.taxAmount = 0,
  });

  // ─── الحالة ────────────────────────────────────────────────────────
  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get lineCount => lines.length;
  bool get hasCustomer => customer != null;

  // ─── الحسابات ──────────────────────────────────────────────────────
  double get totalQuantity =>
      lines.fold(0.0, (s, l) => s + l.quantity);

  double get subtotal =>
      lines.fold(0.0, (s, l) => s + l.lineTotal);

  double get total {
    final t = subtotal - discount + taxAmount;
    return t < 0 ? 0 : t;
  }

  double get customerBalance => customer?.balance ?? 0;

  /// إجمالي المطلوب = رصيد سابق + فاتورة
  double get settlementTotal => customerBalance + total;

  PosCartState copyWith({
    List<PosCartLine>? lines,
    PosCustomer? customer,
    bool clearCustomer = false,
    double? discount,
    double? taxAmount,
  }) {
    return PosCartState(
      lines: lines ?? this.lines,
      customer: clearCustomer ? null : (customer ?? this.customer),
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
    );
  }
}

// ============================================================================
// PosCartController — يتحكم في تعديل الحالة
// ============================================================================

/// متحكم بسيط للسلة يعتمد على `ValueNotifier` (جزء من Flutter SDK).
///
/// * كل التعديلات تمر عبر `value = value.copyWith(...)` لضمان أن الـ State
///   يبقى immutable.
/// * كل widget يستمع عبر `ValueListenableBuilder`.
/// * لا يوجد اعتماد على Riverpod.
class PosCartController extends ValueNotifier<PosCartState> {
  PosCartController() : super(const PosCartState());

  PosCartState get state => value;

  // ─── خطوط السلة ───────────────────────────────────────────────────

  /// يضيف خط جديد أو يدمج مع خط موجود (نفس المنتج + نفس الوحدة).
  /// يعيد `true` إذا كان الدمج (المنتج موجود مسبقاً).
  bool addLine({
    required PosProduct product,
    required PosProductUnit unit,
    required double quantity,
    required double unitPrice,
  }) {
    if (quantity <= 0) return false;

    final existingIndex = value.lines.indexWhere(
      (l) => l.product.id == product.id && l.unit.id == unit.id,
    );

    final List<PosCartLine> newLines = List<PosCartLine>.from(value.lines);

    if (existingIndex >= 0) {
      final existing = newLines[existingIndex];
      newLines[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
        unitPrice: unitPrice,
      );
      value = value.copyWith(lines: newLines);
      return true;
    }

    newLines.add(PosCartLine(
      product: product,
      unit: unit,
      quantity: quantity,
      unitPrice: unitPrice,
    ));
    value = value.copyWith(lines: newLines);
    return false;
  }

  void updateQuantity(int index, double quantity) {
    if (index < 0 || index >= value.lines.length) return;
    final List<PosCartLine> newLines = List<PosCartLine>.from(value.lines);
    if (quantity <= 0) {
      newLines.removeAt(index);
    } else {
      newLines[index] = newLines[index].copyWith(quantity: quantity);
    }
    value = value.copyWith(lines: newLines);
  }

  void updatePrice(int index, double price) {
    if (index < 0 || index >= value.lines.length || price < 0) return;
    final List<PosCartLine> newLines = List<PosCartLine>.from(value.lines);
    newLines[index] = newLines[index].copyWith(unitPrice: price);
    value = value.copyWith(lines: newLines);
  }

  void removeLine(int index) {
    if (index < 0 || index >= value.lines.length) return;
    final List<PosCartLine> newLines = List<PosCartLine>.from(value.lines)
      ..removeAt(index);
    value = value.copyWith(lines: newLines);
  }

  // ─── العميل ───────────────────────────────────────────────────────

  void setCustomer(PosCustomer? customer) {
    if (customer == null) {
      value = value.copyWith(clearCustomer: true);
    } else {
      value = value.copyWith(customer: customer);
    }
  }

  // ─── الخصم والضريبة ───────────────────────────────────────────────

  void setDiscount(double discount) {
    // الحد الأقصى للخصم: 50% من الإجمالي الفرعي
    final maxDiscount = value.subtotal * 0.5;
    value = value.copyWith(
      discount: discount < 0
          ? 0
          : (discount > maxDiscount ? maxDiscount : discount),
    );
  }

  void setTax(double taxAmount) {
    value = value.copyWith(taxAmount: taxAmount < 0 ? 0 : taxAmount);
  }

  // ─── إعادة تعيين ──────────────────────────────────────────────────

  void clear() {
    value = const PosCartState();
  }

  /// استعادة حالة محفوظة (تُستخدم في تعليق/استعادة الفاتورة).
  void restore(PosCartState snapshot) {
    value = snapshot;
  }
}
