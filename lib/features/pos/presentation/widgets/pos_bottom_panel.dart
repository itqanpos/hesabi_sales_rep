import 'package:flutter/material.dart';

class PosBottomPanel extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double total;
  final Function(double) onDiscountChanged;
  final VoidCallback onPay;

  const PosBottomPanel({super.key, required this.subtotal, required this.discount, required this.total, required this.onDiscountChanged, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع الفرعي:', style: TextStyle(fontSize: 14)),
              Text('${subtotal.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('الخصم:', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 28,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.zero, isDense: true, border: OutlineInputBorder()),
                      onChanged: (v) => onDiscountChanged(double.tryParse(v) ?? 0),
                    ),
                  ),
                ],
              ),
              Text('- ${discount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 14, color: Colors.red)),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${total.toStringAsFixed(2)} ج.م', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payment),
              label: const Text('الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
