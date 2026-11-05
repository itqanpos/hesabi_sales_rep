import 'package:flutter/material.dart';

class PosCartLineTile extends StatefulWidget {
  final Map<String, dynamic> line;
  final Function(double) onQtyChanged;
  final Function(double) onPriceChanged;
  final VoidCallback onRemove;

  const PosCartLineTile({super.key, required this.line, required this.onQtyChanged, required this.onPriceChanged, required this.onRemove});

  @override
  State<PosCartLineTile> createState() => _PosCartLineTileState();
}

class _PosCartLineTileState extends State<PosCartLineTile> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  final _qtyFocus = FocusNode();
  final _priceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.line['qty'].toString());
    _priceCtrl = TextEditingController(text: widget.line['price'].toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _qtyFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _commitQty() {
    final val = double.tryParse(_qtyCtrl.text);
    if (val != null && val > 0) {
      widget.onQtyChanged(val);
    } else {
      _qtyCtrl.text = widget.line['qty'].toString();
    }
  }

  void _commitPrice() {
    final val = double.tryParse(_priceCtrl.text);
    final min = (widget.line['min_price'] as num?)?.toDouble();
    final max = (widget.line['max_price'] as num?)?.toDouble();
    
    if (val != null && val >= 0 && (min == null || val >= min) && (max == null || val <= max)) {
      widget.onPriceChanged(val);
    } else {
      _priceCtrl.text = widget.line['price'].toString();
      if (val != null && min != null && val < min) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أقل سعر مسموح هو $min'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = widget.line;
    final total = (line['qty'] as double) * (line['price'] as double);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(line['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          SizedBox(width: 50, height: 38, child: TextField(controller: _qtyCtrl, focusNode: _qtyFocus, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: OutlineInputBorder()), onSubmitted: (_) => _commitQty(), onTapOutside: (_) { _qtyFocus.unfocus(); _commitQty(); })),
          const SizedBox(width: 4),
          SizedBox(width: 40, child: Text(line['unit_name'], style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          SizedBox(width: 65, height: 38, child: TextField(controller: _priceCtrl, focusNode: _priceFocus, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: OutlineInputBorder()), onSubmitted: (_) => _commitPrice(), onTapOutside: (_) { _priceFocus.unfocus(); _commitPrice(); })),
          const SizedBox(width: 6),
          SizedBox(width: 70, child: Text(total.toStringAsFixed(2), textAlign: TextAlign.end, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13))),
          IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: widget.onRemove),
        ],
      ),
    );
  }
}
