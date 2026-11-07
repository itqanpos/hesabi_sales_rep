import 'package:flutter/material.dart';

import '../../domain/pos_models.dart';

class PosCustomerBar extends StatelessWidget {
  final PosCustomer? customer;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const PosCustomerBar({
    super.key,
    required this.customer,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomer = customer != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasCustomer ? _C.primaryLight : Colors.white,
          border: const Border(
            bottom: BorderSide(color: _C.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasCustomer ? Icons.person : Icons.person_outline,
              color: hasCustomer ? _C.primaryDark : _C.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasCustomer ? customer!.name : 'تحديد عميل (اختياري)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          hasCustomer ? FontWeight.w700 : FontWeight.w500,
                      color: hasCustomer ? _C.primaryDark : _C.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasCustomer && customer!.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer!.phone!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _C.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasCustomer && onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _C.primaryDark),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'إزالة العميل',
              )
            else
              const Icon(Icons.chevron_left, color: _C.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const border = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF757575);
}
