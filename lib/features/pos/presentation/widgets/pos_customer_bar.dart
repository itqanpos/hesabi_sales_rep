import 'package:flutter/material.dart';

class PosCustomerBar extends StatelessWidget {
  final Map<String, dynamic>? customer;
  final double balance;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const PosCustomerBar({super.key, this.customer, required this.balance, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustomer = customer != null;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(hasCustomer ? Icons.person : Icons.person_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hasCustomer ? customer!['name'] : 'عميل نقدي', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      if (hasCustomer && balance != 0)
                        Text('الرصيد: ${balance.toStringAsFixed(2)} ج.م', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (hasCustomer)
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClear)
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('تغيير', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_left, color: theme.colorScheme.primary, size: 18),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
