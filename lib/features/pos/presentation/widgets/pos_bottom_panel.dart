import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/pos_cart_state.dart';

class PosBottomPanel extends StatelessWidget {
  final PosCartState cart;
  final ValueChanged<double> onDiscountChanged;
  final VoidCallback onClearTap;
  final VoidCallback onPayTap;

  const PosBottomPanel({
    super.key,
    required this.cart,
    required this.onDiscountChanged,
    required this.onClearTap,
    required this.onPayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = cart.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(top: BorderSide(color: _C.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    size: 14, color: _C.textSecondary),
                const SizedBox(width: 4),
                Text('الأصناف: ${cart.lineCount}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.textSecondary)),
                const Spacer(),
                const Text('الخصم',
                    style: TextStyle(fontSize: 12, color: _C.textSecondary)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 70,
                  height: 32,
                  child: TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0;
                      onDiscountChanged(val);
                    },
                    decoration: const InputDecoration(
                      hintText: '0',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('ج.م',
                    style: TextStyle(fontSize: 12, color: _C.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('الصافي',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${cart.total.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _C.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: isEmpty ? null : onClearTap,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('إلغاء'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.danger,
                        side: const BorderSide(color: _C.danger),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isEmpty ? null : onPayTap,
                      icon: const Icon(Icons.payments, size: 20),
                      label: const Text('الدفع',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const danger = Color(0xFFC62828);
  static const border = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF757575);
}
