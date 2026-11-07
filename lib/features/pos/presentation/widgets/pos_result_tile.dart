import 'package:flutter/material.dart';

import '../../domain/pos_models.dart';

class PosResultTile extends StatelessWidget {
  final PosProduct product;
  final VoidCallback onTap;

  const PosResultTile({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inStock = product.hasStock;

    return ListTile(
      onTap: inStock ? onTap : null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _C.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.inventory_2_outlined,
            color: _C.primary, size: 20),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            '${product.defaultPrice.toStringAsFixed(2)} ج.م',
            style: const TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          const SizedBox(width: 8),
          if (product.hasMultipleUnits)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${product.allUnits.length} وحدات',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.primaryDark),
              ),
            ),
          const Spacer(),
          Text(
            inStock
                ? '${product.stockQty.toInt()} ${product.defaultUnitName}'
                : 'نفذ',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: inStock ? _C.success : _C.danger),
          ),
        ],
      ),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: inStock ? _C.primary : _C.surfaceGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add,
            color: inStock ? Colors.white : _C.textSecondary, size: 18),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF757575);
}
