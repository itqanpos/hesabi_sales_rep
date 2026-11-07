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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: _C.primaryLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.person,
                    color: _C.primaryDark, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasCustomer ? customer!.name : 'عميل نقدي',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _C.primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'تغيير',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _C.primaryDark.withOpacity(0.8),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_left,
                    size: 18, color: _C.primaryDark.withOpacity(0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _C {
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
}
