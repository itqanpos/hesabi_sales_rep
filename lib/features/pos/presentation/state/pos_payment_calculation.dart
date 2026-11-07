import 'package:flutter/foundation.dart';

import '../../domain/pos_models.dart';
import 'pos_cart_state.dart';

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

  double get appliedToSale {
    if (inputAmount <= 0) return 0;
    return inputAmount >= cartTotal ? cartTotal : inputAmount;
  }

  double get changeToCustomer {
    if (method != 'cash') return 0;
    final excess = inputAmount - cartTotal;
    return excess > 0 ? excess : 0;
  }

  double get addedToBalance => cartTotal - appliedToSale;
  double get resultingBalance => customerBalance + addedToBalance;

  String? get errorMessage {
    if (cartIsEmpty) return 'السلة فارغة';
    if (method == 'card' ||
        method == 'instapay' ||
        method == 'bank_transfer') {
      if (inputAmount < cartTotal) {
        return 'هذه الطريقة يجب أن تغطي كامل الفاتورة';
      }
      if (inputAmount > cartTotal) {
        return 'هذه الطريقة لا تُعيد باقياً';
      }
    }
    if (addedToBalance > 0 && !hasCustomer) {
      return 'الدفع الجزئي يتطلب اختيار عميل';
    }
    return null;
  }

  bool get isValid => errorMessage == null;
}
