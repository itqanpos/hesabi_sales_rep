import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PosPaymentDialog extends StatefulWidget {
  final String companyId; 
  final List<Map<String, dynamic>> cart;
  final Map<String, dynamic>? customer; 
  final double discount, total, customerBalance;
  
  const PosPaymentDialog({super.key, required this.companyId, required this.cart, this.customer, required this.discount, required this.total, required this.customerBalance});
  
  @override State<PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<PosPaymentDialog> {
  String _method = 'cash';
  late TextEditingController _paidCtrl;
  bool _saving = false;

  @override void initState() { super.initState(); _paidCtrl = TextEditingController(text: widget.total.toStringAsFixed(2)); }
  @override void dispose() { _paidCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final paid = double.tryParse(_paidCtrl.text) ?? widget.total;
      final isCredit = _method == 'credit';
      if (isCredit && widget.customer == null) throw 'البيع الآجل يتطلب اختيار عميل';
      
      final items = widget.cart.map((i) => {
        'product_id': i['product_id'], 
        'unit_id': i['unit_id'], 
        'quantity': i['qty'], 
        'unit_price': i['price']
      }).toList();
      
      await Supabase.instance.client.rpc('create_rep_sale', params: {
        'p_company_id': widget.companyId, 
        'p_client_uuid': const Uuid().v4(),
        'p_payload': {
          'customer_id': widget.customer?['id'], 
          'items': items, 
          'payment_method': isCredit ? null : _method, 
          'paid_amount': isCredit ? 0 : paid, 
          'discount': widget.discount
        },
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override Widget build(BuildContext context) {
    final totalRequired = widget.total + widget.customerBalance;
    final paid = double.tryParse(_paidCtrl.text) ?? 0;
    final remaining = totalRequired - paid;

    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('إتمام الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            if (widget.customerBalance != 0) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الرصيد السابق'), Text(widget.customerBalance.toStringAsFixed(2))]),
              const SizedBox(height: 4),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('قيمة الفاتورة'), Text(widget.total.toStringAsFixed(2))]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي المطلوب', style: TextStyle(fontWeight: FontWeight.bold)), Text(totalRequired.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))]),
          ]),
        ),
        const SizedBox(height: 16),

        SegmentedButton<String>(segments: const [ButtonSegment(value: 'cash', label: Text('نقدي'), icon: Icon(Icons.payments)), ButtonSegment(value: 'credit', label: Text('آجل'), icon: Icon(Icons.schedule))],
          selected: {_method}, onSelectionChanged: (s) => setState(() => _method = s.first)),
        
        const SizedBox(height: 16),

        if (_method != 'credit') ...[
          TextField(controller: _paidCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المدفوع', border: OutlineInputBorder(), suffixText: 'ج.م'), onChanged: (_) => setState((){})),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(remaining > 0 ? 'المتبقي:' : remaining < 0 ? 'الزيادة (تُضاف للرصيد):' : 'مطابق'),
              Text(remaining.abs().toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: remaining > 0 ? Colors.red : Colors.green)),
            ],
          ),
        ] else ...[
          const Text('سيتم إضافة كامل قيمة الفاتورة إلى رصيد العميل.', style: TextStyle(color: Colors.orange)),
        ],

        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
          label: Text(_saving ? 'جارٍ الحفظ...' : 'تأكيد وإتمام البيع'),
        )),
      ])),
    );
  }
}
