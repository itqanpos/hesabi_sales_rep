import 'package:flutter/material.dart';

import '../../domain/pos_models.dart';

class PosUnitSelectorSheet extends StatelessWidget {
  final PosProduct product;

  const PosUnitSelectorSheet({super.key, required this.product});

  static Future<PosProductUnit?> show(
      BuildContext context, PosProduct product) {
    return showModalBottomSheet<PosProductUnit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosUnitSelectorSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: _C.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('اختر وحدة البيع',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text('المنتج: ${product.name}',
                style:
                    const TextStyle(fontSize: 12, color: _C.textSecondary)),
            const SizedBox(height: 16),
            for (final unit in product.allUnits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _UnitCard(
                  unit: unit,
                  product: product,
                  onTap: () => Navigator.pop(context, unit),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final PosProductUnit unit;
  final PosProduct product;
  final VoidCallback onTap;

  const _UnitCard({
    required this.unit,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBase = unit.isBase;
    final price = unit.effectivePrice(product.defaultPrice);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBase ? _C.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isBase ? _C.primary : _C.border,
              width: isBase ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isBase ? _C.primary : _C.border, width: 2),
              ),
              child: isBase
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: _C.primary),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(unit.unitName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    isBase
                        ? 'الوحدة الأساسية'
                        : '${unit.conversionFactor.toInt()} ${product.defaultUnitName}',
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '${price.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isBase ? _C.primary : _C.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryLight = Color(0xFFE0F2F1);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
