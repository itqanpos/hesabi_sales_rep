import 'package:flutter/material.dart';

import '../../domain/pos_models.dart';
import 'pos_result_tile.dart';

class PosResultsList extends StatelessWidget {
  final List<PosProduct> products;
  final ValueChanged<PosProduct> onProductTap;
  final bool isLoading;

  const PosResultsList({
    super.key,
    required this.products,
    required this.onProductTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00897B)));
    }
    if (products.isEmpty) {
      return const Center(
        child: Text('لا توجد نتائج',
            style: TextStyle(color: Color(0xFF757575), fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: products.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
      itemBuilder: (_, i) => PosResultTile(
        product: products[i],
        onTap: () => onProductTap(products[i]),
      ),
    );
  }
}
