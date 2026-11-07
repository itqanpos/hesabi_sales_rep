import 'package:flutter/material.dart';

import '../../domain/pos_models.dart';
import 'pos_cart_line_tile.dart';

class PosCartList extends StatelessWidget {
  final List<PosCartLine> lines;
  final void Function(int index, double newQty) onQuantityChanged;
  final void Function(int index, double newPrice) onPriceChanged;
  final void Function(int index) onRemove;

  const PosCartList({
    super.key,
    required this.lines,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 56, color: Color(0xFFBDBDBD)),
            SizedBox(height: 10),
            Text('السلة فارغة',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF757575))),
            SizedBox(height: 4),
            Text('ابحث عن منتج أو امسح الباركود لإضافته.',
                style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: lines.length,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, i) => PosCartLineTile(
        line: lines[i],
        onQuantityChanged: (q) => onQuantityChanged(i, q),
        onPriceChanged: (p) => onPriceChanged(i, p),
        onRemove: () => onRemove(i),
      ),
    );
  }
}
