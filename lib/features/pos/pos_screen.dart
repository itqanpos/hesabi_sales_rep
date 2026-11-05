import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PosScreen extends StatefulWidget {
  final String companyId;
  final String branchId;
  const PosScreen({super.key, required this.companyId, required this.branchId});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<String, double> _stockMap = {};
  List<Map<String, dynamic>> _customers = [];

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _loading = true;
  bool _isSearching = false;

  List<Map<String, dynamic>> _cart = [];
  Map<String, dynamic>? _selectedCustomer;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = Supabase.instance.client;

      final prods = await client
          .from('products')
          .select('id, name, product_units(id, unit_name, sell_price, min_selling_price, max_selling_price, barcode)')
          .eq('company_id', widget.companyId)
          .eq('is_active', true);

      final stock = await client
          .from('inventory_balances')
          .select('product_id, quantity_on_hand')
          .eq('branch_id', widget.branchId);

      final Map<String, double> sMap = {};
      for (var s in stock) {
        if (s['product_id'] != null && s['quantity_on_hand'] != null) {
          sMap[s['product_id']] = (s['quantity_on_hand'] as num).toDouble();
        }
      }

      final custs = await client
          .from('customers')
          .select('id, name, phone, balance')
          .eq('company_id', widget.companyId)
          .order('name');

      if (mounted) {
        setState(() {
          _products = (prods as List).cast<Map<String, dynamic>>();
          _filteredProducts = _products;
          _stockMap = sMap;
          _customers = (custs as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _isSearching = q.isNotEmpty;
        _filteredProducts = _products.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final units = p['product_units'] as List?;
          bool barcodeMatch = false;
          if (units != null) {
            for (var u in units) {
              if ((u['barcode'] ?? '').toString().toLowerCase().contains(q)) {
                barcodeMatch = true;
                break;
              }
            }
          }
          return name.contains(q) || barcodeMatch;
        }).toList();
      });
    });
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
  double get _total => _subtotal - _discount;
  bool get _hasCustomer => _selectedCustomer != null;
  double get _customerBalance => (_selectedCustomer?['balance'] as num?)?.toDouble() ?? 0.0;

  void _addToCart(Map<String, dynamic> line) {
    setState(() {
      final i = _cart.indexWhere((item) => item['product_id'] == line['product_id'] && item['unit_id'] == line['unit_id']);
      if (i >= 0) { _cart[i]['qty'] += line['qty']; } else { _cart.add(line); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          if (_cart.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.red), onPressed: () => setState(() => _cart.clear())),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCustomerBar(),
                _buildSearchField(),
                Expanded(child: _isSearching ? _buildSearchResults() : _buildCartList()),
                if (!_isSearching && _cart.isNotEmpty) _buildBottomPanel(),
              ],
            ),
    );
  }

  Widget _buildCustomerBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final sel = await showModalBottomSheet<Map<String, dynamic>>(
              context: context, isScrollControlled: true,
              builder: (_) => _CustomerPickerSheet(customers: _customers),
            );
            if (sel != null) setState(() => _selectedCustomer = sel);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(_hasCustomer ? Icons.person : Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_hasCustomer ? _selectedCustomer!['name'] : 'عميل نقدي', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (_hasCustomer && _customerBalance != 0)
                        Text('الرصيد: ${_customerBalance.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ),
                ),
                if (_hasCustomer) IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _selectedCustomer = null)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: _searchCtrl, focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم أو الباركود...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () async {
                final res = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScannerPage()));
                if (res != null) _searchCtrl.text = res;
              }),
              if (_searchCtrl.text.isNotEmpty) IconButton(icon: const Icon(Icons.close), onPressed: () => _searchCtrl.clear()),
            ],
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredProducts.isEmpty) return const Center(child: Text('لا توجد نتائج'));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _filteredProducts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = _filteredProducts[i];
        final stock = _stockMap[p['id']] ?? 0.0;
        final units = p['product_units'] as List?;
        final defaultUnit = (units != null && units.isNotEmpty) ? units.first : null;
        final price = (defaultUnit?['sell_price'] as num?)?.toDouble() ?? 0.0;
        final (bg, fg, lbl) = stock <= 0 ? (Colors.red.shade50, Colors.red, 'نفد') : stock <= 10 ? (Colors.orange.shade50, Colors.orange, '${stock.toInt()} متبقٍ') : (Colors.green.shade50, Colors.green, '${stock.toInt()} متاح');
        return InkWell(
          onTap: () async {
            final r = await showModalBottomSheet<Map<String, dynamic>>(
              context: context, isScrollControlled: true,
              builder: (_) => _UnitSelectorSheet(product: p, stock: stock),
            );
            if (r != null) { _addToCart(r); _searchCtrl.clear(); _searchFocus.unfocus(); }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (defaultUnit != null) Text(defaultUnit['unit_name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)), child: Text(lbl, style: TextStyle(fontSize: 10, color: fg))),
                const SizedBox(width: 8),
                Text('${price.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey), SizedBox(height: 16),
      Text('السلة فارغة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
    ]));
    return ListView.separated(
      itemCount: _cart.length, separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final line = _cart[i];
        return ListTile(
          title: Text(line['product_name']),
          subtitle: Text('${line['qty']} ${line['unit_name']} × ${line['price']}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${((line['qty'] as num) * (line['price'] as num)).toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _cart.removeAt(i))),
          ]),
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المجموع:'), Text('${_subtotal.toStringAsFixed(2)} ج.م')]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي:'), Text('${_total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
          onPressed: () async {
            final ok = await showModalBottomSheet<bool>(
              context: context, isScrollControlled: true,
              builder: (_) => _PaymentSheet(companyId: widget.companyId, cart: _cart, customer: _selectedCustomer, discount: _discount, total: _total, customerBalance: _customerBalance),
            );
            if (ok == true) { setState(() { _cart.clear(); _discount = 0; _selectedCustomer = null; }); _loadData(); }
          },
          icon: const Icon(Icons.payment), label: const Text('الدفع', style: TextStyle(fontSize: 18)),
        )),
      ]),
    );
  }
}

// ============ الوحدات ============
class _UnitSelectorSheet extends StatefulWidget {
  final Map<String, dynamic> product; final double stock;
  const _UnitSelectorSheet({required this.product, required this.stock});
  @override State<_UnitSelectorSheet> createState() => _UnitSelectorSheetState();
}
class _UnitSelectorSheetState extends State<_UnitSelectorSheet> {
  String? _selectedUnitId;
  late TextEditingController _qtyCtrl, _priceCtrl;
  @override void initState() {
    super.initState();
    final units = widget.product['product_units'] as List;
    _selectedUnitId = units.first['id'];
    _qtyCtrl = TextEditingController(text: '1');
    _priceCtrl = TextEditingController(text: (units.first['sell_price'] ?? 0).toString());
  }
  @override void dispose() { _qtyCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }
  Map<String, dynamic> get _cur => (widget.product['product_units'] as List).firstWhere((u) => u['id'] == _selectedUnitId);
  @override Widget build(BuildContext context) {
    final units = widget.product['product_units'] as List;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.product['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(value: _selectedUnitId, decoration: const InputDecoration(labelText: 'الوحدة', border: OutlineInputBorder()),
          items: units.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'], child: Text(u['unit_name'] ?? ''))).toList(),
          onChanged: (v) => setState(() { _selectedUnitId = v; _priceCtrl.text = (_cur['sell_price'] ?? 0).toString(); })),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()), onChanged: (_) => setState((){}))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder()), onChanged: (_) => setState((){}))),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: FilledButton(
          onPressed: qty > 0 ? () => Navigator.pop(context, {'product_id': widget.product['id'], 'product_name': widget.product['name'], 'unit_id': _selectedUnitId, 'unit_name': _cur['unit_name'], 'qty': qty, 'price': price}) : null,
          child: const Text('إضافة إلى السلة'),
        )),
      ]),
    );
  }
}

// ============ اختيار العميل ============
class _CustomerPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  const _CustomerPickerSheet({required this.customers});
  @override State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}
class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _q = '';
  @override Widget build(BuildContext context) {
    final f = widget.customers.where((c) => (c['name'] ?? '').toString().contains(_q)).toList();
    return Container(padding: const EdgeInsets.all(16), height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        const Text('اختيار العميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(decoration: const InputDecoration(hintText: 'بحث...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: f.length, itemBuilder: (_, i) => ListTile(title: Text(f[i]['name']), subtitle: Text(f[i]['phone'] ?? ''), onTap: () => Navigator.pop(context, f[i])))),
      ]),
    );
  }
}

// ============ الدفع ============
class _PaymentSheet extends StatefulWidget {
  final String companyId; final List<Map<String, dynamic>> cart;
  final Map<String, dynamic>? customer; final double discount, total, customerBalance;
  const _PaymentSheet({required this.companyId, required this.cart, this.customer, required this.discount, required this.total, required this.customerBalance});
  @override State<_PaymentSheet> createState() => _PaymentSheetState();
}
class _PaymentSheetState extends State<_PaymentSheet> {
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
      if (isCredit && widget.customer == null) throw 'الآجل يتطلب عميل';
      final items = widget.cart.map((i) => {'product_id': i['product_id'], 'unit_id': i['unit_id'], 'quantity': i['qty'], 'unit_price': i['price']}).toList();
      await Supabase.instance.client.rpc('create_rep_sale', params: {
        'p_company_id': widget.companyId, 'p_client_uuid': const Uuid().v4(),
        'p_payload': {'customer_id': widget.customer?['id'], 'items': items, 'payment_method': isCredit ? null : _method, 'paid_amount': isCredit ? 0 : paid, 'discount': widget.discount},
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('إتمام الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('الإجمالي: ${widget.total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'cash', label: Text('نقدي')), ButtonSegment(value: 'credit', label: Text('آجل'))],
          selected: {_method}, onSelectionChanged: (s) => setState(() => _method = s.first)),
        if (_method != 'credit') ...[
          const SizedBox(height: 12),
          TextField(controller: _paidCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المدفوع', border: OutlineInputBorder())),
        ],
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'جارٍ الحفظ...' : 'تأكيد'))),
      ])),
    );
  }
}

// ============ السكانر ============
class _ScannerPage extends StatelessWidget {
  const _ScannerPage();
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('مسح')), body: MobileScanner(onDetect: (c) {
      for (final b in c.barcodes) { if (b.rawValue != null) { Navigator.pop(context, b.rawValue); break; } }
    }));
  }
}
