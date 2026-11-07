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

    return InkWell(
      onTap: inStock ? onTap : null,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // أيقونة المنتج
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: _C.primary, size: 22),
            ),
            const SizedBox(width: 10),
            // الاسم + الوحدة
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.defaultUnitName,
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // شارة المخزون
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color:
                    inStock ? _C.successLight : _C.dangerLight,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                inStock
                    ? '${product.stockQty.toInt()} متاح'
                    : 'نفذ',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: inStock ? _C.success : _C.danger),
              ),
            ),
            const SizedBox(width: 8),
            // السعر
            Text(
              '${product.defaultPrice.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _C.primary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left,
                size: 20, color: _C.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const danger = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const textSecondary = Color(0xFF757575);
}
