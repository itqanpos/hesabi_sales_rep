import 'package:flutter/material.dart';

class PosCustomerPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  const PosCustomerPickerSheet({super.key, required this.customers});
  @override State<PosCustomerPickerSheet> createState() => _PosCustomerPickerSheetState();
}

class _PosCustomerPickerSheetState extends State<PosCustomerPickerSheet> {
  String _q = '';
  @override Widget build(BuildContext context) {
    final f = widget.customers.where((c) => (c['name'] ?? '').toString().contains(_q)).toList();
    return Container(padding: const EdgeInsets.all(16), height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        const Text('اختيار العميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(decoration: const InputDecoration(hintText: 'بحث...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: f.length, itemBuilder: (_, i) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(f[i]['name']), 
          subtitle: Text(f[i]['phone'] ?? ''),
          trailing: (f[i]['balance'] as num? ?? 0) > 0 ? Text('${f[i]['balance']} ج.م', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)) : null,
          onTap: () => Navigator.pop(context, f[i])
        ))),
      ]),
    );
  }
}
