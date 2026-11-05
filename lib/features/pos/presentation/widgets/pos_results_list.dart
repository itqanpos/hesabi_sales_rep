import 'package:flutter/material.dart';

class PosResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, double> stockMap;
  final Function(Map<String, dynamic>) onTap;

  const PosResultsList({super.key, required this.products, required this.stockMap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('لا توجد منتجات مطابقة', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = products[i];
        final stock = stockMap[p['id']] ?? 0.0;
        final price = (p['selling_price'] as num?)?.toDouble() ?? 0.0;
        // تم تعديل هذا السطر لقراءة اسم الوحدة الأساسية من الحقل الجديد
        final unitName = p['base_unit_name']?.toString() ?? 'قطعة';
        
        final (bg, fg, lbl) = stock <= 0 
            ? (const Color(0xFFFFEBEE), const Color(0xFFC62828), 'نفد') 
            : stock <= 10 
                ? (const Color(0xFFFFF3E0), const Color(0xFFE65100), '${stock.toInt()} متبقٍ') 
                : (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), '${stock.toInt()} متاح');

        return InkWell(
          onTap: () => onTap(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.inventory_2_outlined, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(unitName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: fg.withOpacity(0.3))), child: Text(lbl, style: TextStyle(fontSize: 10, color: fg))),
                const SizedBox(width: 8),
                Text('${price.toStringAsFixed(2)} ج.م', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }
}
