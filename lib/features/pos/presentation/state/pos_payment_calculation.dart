import 'package:flutter/foundation.dart';

import '../../domain/pos_models.dart';
import 'pos_cart_state.dart';

// ============================================================================
// طرق الدفع — يجب أن تطابق SQL whitelist في Hesabi
// ============================================================================

abstract final class PaymentMethods {
  static const String cash = 'cash';
  static const String card = 'card';
  static const String transfer = 'transfer';
  static const String instapay = 'instapay';
  static const String bankTransfer = 'bank_transfer';
  static const String other = 'other';

  static const List<String> all = <String>[
    cash,
    card,
    transfer,
    instapay,
    bankTransfer,
    other,
  ];

  static String label(String m) => switch (m) {
        cash => 'نقدي',
        card => 'بطاقة',
        transfer => 'تحويل',
        instapay => 'إنستاباي',
        bankTransfer => 'تحويل بنكي',
        other => 'أخرى',
        _ => m,
      };
}

// ============================================================================
// PaymentCalculation — منطق حسابي نقي (قابل للاختبار)
// ============================================================================

@immutable
class PaymentCalculation {
  final String method;
  final double inputAmount;
  final double cartTotal;
  final double customerBalance;
  final bool hasCustomer;
  final bool cartIsEmpty;

  const PaymentCalculation({
    required this.method,
    required this.inputAmount,
    required this.cartTotal,
    required this.customerBalance,
    required this.hasCustomer,
    required this.cartIsEmpty,
  });

  factory PaymentCalculation.fromCart({
    required PosCartState cart,
    required String method,
    required double inputAmount,
  }) {
    return PaymentCalculation(
      method: method,
      inputAmount: inputAmount,
      cartTotal: cart.total,
      customerBalance: cart.customerBalance,
      hasCustomer: cart.hasCustomer,
      cartIsEmpty: cart.isEmpty,
    );
  }

  /// الجزء من المبلغ الذي يطبق على الفاتورة (محدود بـ cartTotal).
  double get appliedToSale {
    if (inputAmount <= 0) return 0;
    return inputAmount >= cartTotal ? cartTotal : inputAmount;
  }

  /// الباقي للعميل (فقط للنقدي).
  double get changeToCustomer {
    if (method != PaymentMethods.cash) return 0;
    final excess = inputAmount - cartTotal;
    return excess > 0 ? excess : 0;
  }

  /// الفرق الذي يضاف لرصيد العميل (الدفع الناقص).
  double get addedToBalance => cartTotal - appliedToSale;

  /// الرصيد النهائي المتوقع بعد البيع.
  double get resultingBalance => customerBalance + addedToBalance;

  /// هل تمت تسوية الفاتورة بالكامل دون باقي ولا دين؟
  bool get isFullyPaid => changeToCustomer == 0 && addedToBalance == 0;

  // ─── التحقق ──────────────────────────────────────────────────────

  String? get errorMessage {
    if (cartIsEmpty) return 'السلة فارغة.';

    if (appliedToSale == 0 && inputAmount > 0) {
      return 'المبلغ غير صالح.';
    }

    if (method == PaymentMethods.card ||
        method == PaymentMethods.instapay ||
        method == PaymentMethods.bankTransfer) {
      if (inputAmount < cartTotal) {
        return 'الدفع بالبطاقة/التحويل يجب أن يغطي كامل الفاتورة.';
      }
      if (inputAmount > cartTotal) {
        return 'لا يوجد باقي للدفع بالبطاقة/التحويل.';
      }
    }

    if (addedToBalance > 0 && !hasCustomer) {
      return 'الدفع الجزئي يتطلب اختيار عميل.';
    }

    return null;
  }

  bool get isValid => errorMessage == null;

  /// الطريقة المعروضة للعميل (إذا كانت الدفعة جزئية).
  bool get requiresCustomer => addedToBalance > 0.001;
}
