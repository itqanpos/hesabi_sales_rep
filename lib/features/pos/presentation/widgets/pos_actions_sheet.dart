import 'package:flutter/material.dart';

import '../state/pos_cart_state.dart';

class PosActionsSheet extends StatelessWidget {
  final bool hasCart;
  final PosCartState? heldCart;
  final VoidCallback onHold;
  final VoidCallback onRestore;
  final VoidCallback onReturns;

  const PosActionsSheet({
    super.key,
    required this.hasCart,
    required this.heldCart,
    required this.onHold,
    required this.onRestore,
    required this.onReturns,
  });

  static Future<void> show(
    BuildContext context, {
    required bool hasCart,
    required PosCartState? heldCart,
    required VoidCallback onHold,
    required VoidCallback onRestore,
    required VoidCallback onReturns,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => PosActionsSheet(
        hasCart: hasCart,
        heldCart: heldCart,
        onHold: onHold,
        onRestore: onRestore,
        onReturns: onReturns,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text('خيارات',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          _tile(
            icon: Icons.pause_circle_outline,
            title: 'تعليق الفاتورة',
            subtitle: 'حفظ السلة مؤقتاً وبدء سلة جديدة',
            enabled: hasCart,
            onTap: () {
              Navigator.pop(context);
              onHold();
            },
          ),
          _tile(
            icon: Icons.restore,
            title: 'استعادة السلة المعلقة',
            subtitle: heldCart != null
                ? '${heldCart!.lineCount} صنف'
                : 'لا توجد سلة معلقة',
            enabled: heldCart != null,
            onTap: () {
              Navigator.pop(context);
              onRestore();
            },
          ),
          const Divider(height: 1),
          _tile(
            icon: Icons.assignment_return_outlined,
            title: 'إنشاء فاتورة مرتجع',
            subtitle: 'إرجاع أي صنف إلى المخزون',
            enabled: true,
            onTap: () {
              Navigator.pop(context);
              onReturns();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon,
          color: enabled ? _C.primary : _C.textSecondary, size: 22),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle:
          Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: enabled
          ? const Icon(Icons.chevron_left, color: _C.textSecondary)
          : null,
      onTap: enabled ? onTap : null,
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const textSecondary = Color(0xFF757575);
}
