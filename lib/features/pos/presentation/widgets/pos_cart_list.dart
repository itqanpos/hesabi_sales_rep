import 'package:flutter/material.dart';
import 'pos_cart_line_tile.dart';

class PosCartList extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final Function(int, double) onUpdateQty;
  final Function(int, double) onUpdatePrice;
  final Function(int) onRemove;

  const PosCartList({super.key, required this.cart, required this.onUpdateQty, required this.onUpdatePrice, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('السلة فارغة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text('ابحث عن منتج أو امسح الباركود لإضافته.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: cart.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return PosCartLineTile(
          line: cart[index],
          onQtyChanged: (q) => onUpdateQty(index, q),
          onPriceChanged: (p) => onUpdatePrice(index, p),
          onRemove: () => onRemove(index),
        );
      },
    );
  }
}
