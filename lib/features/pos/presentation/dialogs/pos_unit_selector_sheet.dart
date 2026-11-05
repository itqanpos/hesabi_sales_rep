import 'package:flutter/material.dart';

class PosUnitSelectorSheet extends StatefulWidget {
  final Map<String, dynamic> product; 
  final double stock;
  const PosUnitSelectorSheet({super.key, required this.product, required this.stock});

  @override 
  State<PosUnitSelectorSheet> createState() => _PosUnitSelectorSheetState();
}

class _PosUnitSelectorSheetState extends State<PosUnitSelectorSheet> {
  String? _selectedUnitId;
  late TextEditingController _qtyCtrl, _priceCtrl;
  late List<Map<String, dynamic>> _availableUnits;

  @override 
  void initState() {
    super.initState();
    
    _availableUnits = [];
    // الوحدة الأساسية (تم التعديل لقراءة base_unit_name)
    _availableUnits.add({
      'unit_id': widget.product['default_unit_id'],
      'name': widget.product['base_unit_name']?.toString() ?? 'قطعة',
      'price': (widget.product['selling_price'] as num?)?.toDouble() ?? 0.0,
      'min_price': (widget.product['min_selling_price'] as num?)?.toDouble(),
      'max_price': (widget.product['max_selling_price'] as num?)?.toDouble(),
    });

    // الوحدات الإضافية (تم التعديل لقراءة unit_name)
    final extras = widget.product['product_units'] as List?;
    if (extras != null) {
      for (var u in extras) {
        final double factor = (u['conversion_factor'] as num?)?.toDouble() ?? 1.0;
        final double basePrice = (widget.product['selling_price'] as num?)?.toDouble() ?? 0.0;
        final double? explicitPrice = (u['selling_price'] as num?)?.toDouble();
        
        _availableUnits.add({
          'unit_id': u['unit_id'],
          'name': u['unit_name']?.toString() ?? 'وحدة',
          'price': explicitPrice ?? (basePrice * factor),
          'min_price': (u['min_selling_price'] as num?)?.toDouble() ?? ((widget.product['min_selling_price'] as num?)?.toDouble() != null ? (widget.product['min_selling_price'] as num).toDouble() * factor : null),
          'max_price': (u['max_selling_price'] as num?)?.toDouble() ?? ((widget.product['max_selling_price'] as num?)?.toDouble() != null ? (widget.product['max_selling_price'] as num).toDouble() * factor : null),
        });
      }
    }

    _selectedUnitId = _availableUnits.first['unit_id'];
    _qtyCtrl = TextEditingController(text: '1');
    _priceCtrl = TextEditingController(text: _availableUnits.first['price'].toString());
  }

  @override void dispose() { _qtyCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }
  
  Map<String, dynamic> get _cur => _availableUnits.firstWhere((u) => u['unit_id'] == _selectedUnitId);
  
  @override Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.product['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedUnitId, 
          decoration: const InputDecoration(labelText: 'الوحدة', border: OutlineInputBorder()),
          items: _availableUnits.map<DropdownMenuItem<String>>((u) {
            return DropdownMenuItem(value: u['unit_id'] as String, child: Text(u['name'] as String));
          }).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() { 
              _selectedUnitId = v; 
              _priceCtrl.text = _cur['price'].toString(); 
            });
          }
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()), onChanged: (_) => setState((){}))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder()), onChanged: (_) => setState((){}))),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: FilledButton(
          onPressed: qty > 0 ? () => Navigator.pop(context, {
            'product_id': widget.product['id'], 
            'product_name': widget.product['name'], 
            'unit_id': _selectedUnitId, 
            'unit_name': _cur['name'], 
            'qty': qty, 
            'price': price,
            'min_price': _cur['min_price'],
            'max_price': _cur['max_price'],
          }) : null,
          child: const Text('إضافة إلى السلة'),
        )),
      ]),
    );
  }
}
