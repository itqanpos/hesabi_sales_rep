import 'package:flutter/material.dart';

import '../../domain/pos_models.dart';
import 'pos_cart_line_tile.dart';

class PosCartList extends StatelessWidget {
  final List<PosCartLine> lines;
  final void Function(int index, double newQty) onQuantityChanged;
  final void Function(int index) onRemove;

  const PosCartList({
    super.key,
    required this.lines,
    required this.onQuantityChanged,
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
                size: 56, color: Color(0xFF757575)),
            SizedBox(height: 8),
            Text('السلة فارغة',
                style: TextStyle(color: Color(0xFF757575), fontSize: 14)),
            SizedBox(height: 2),
            Text('ابحث عن منتج لإضافته',
                style: TextStyle(color: Color(0xFF757575), fontSize: 11)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => PosCartLineTile(
        line: lines[i],
        onQuantityChanged: (q) => onQuantityChanged(i, q),
        onRemove: () => onRemove(i),
      ),
    );
  }
}
