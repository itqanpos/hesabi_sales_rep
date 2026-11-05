import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/pos_models.dart';
import '../../data/pos_repository.dart';

class PosPage extends StatefulWidget {
  final String companyId;
  final String branchId;
  const PosPage({super.key, required this.companyId, required this.branchId});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final PosRepository _repo;

  // البيانات
  List<PosProduct> _products = [];
  List<PosCustomer> _customers = [];

  // الحالة
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  PosCustomer? _selectedCustomer;
  List<PosCartLine> _cart = [];
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _repo = PosRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _repo.loadProducts(widget.companyId, widget.branchId),
        _repo.loadCustomers(widget.companyId),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<PosProduct>;
        _customers = results[1] as List<PosCustomer>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─── Derived state ───
  List<PosProduct> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    final q = _searchQuery.toLowerCase();
    return _products.where((p) =>
      p.name.toLowerCase().contains(q) ||
      (p.barcode?.contains(q) ?? false) ||
      (p.sku?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  bool get _isSearching => _searchQuery.isNotEmpty;
  double get _subtotal => _cart.fold(0, (s, l) => s + l.lineTotal);
  double get _total => _subtotal - _discount;
  double get _customerBalance => _selectedCustomer?.balance ?? 0;

  // ─── Cart operations ───
  void _addToCart(PosCartLine line) {
    setState(() {
      final i = _cart.indexWhere((l) => l.key == line.key);
      if (i >= 0) {
        _cart[i] = _cart[i].copyWith(quantity: _cart[i].quantity + line.quantity);
      } else {
        _cart.add(line);
      }
    });
  }

  void _updateQty(int i, double qty) {
    if (qty <= 0) return;
    setState(() => _cart[i] = _cart[i].copyWith(quantity: qty));
  }

  void _updatePrice(int i, double price) {
    final line = _cart[i];
    if (price < 0) return;
    if (line.minPrice != null && price < line.minPrice!) {
      _snack('السعر أقل من الحد الأدنى (${line.minPrice!.toStringAsFixed(2)})');
      return;
    }
    if (line.maxPrice != null && price > line.maxPrice!) {
      _snack('السعر أعلى من الحد الأقصى (${line.maxPrice!.toStringAsFixed(2)})');
      return;
    }
    setState(() => _cart[i] = _cart[i].copyWith(unitPrice: price));
  }

  void _removeLine(int i) => setState(() => _cart.removeAt(i));

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Dialogs ───
  Future<void> _openScanner() async {
    final barcode = await Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
    if (barcode != null && barcode.isNotEmpty) {
      setState(() => _searchQuery = barcode);
      if (_filteredProducts.length == 1) {
        _openUnitSelector(_filteredProducts.first);
      }
    }
  }

  Future<void> _openCustomerPicker() async {
    final picked = await showModalBottomSheet<PosCustomer>(
      context: context, isScrollControlled: true,
      builder: (_) => _CustomerPickerSheet(customers: _customers),
    );
    if (picked != null) setState(() => _selectedCustomer = picked);
  }

  Future<void> _openUnitSelector(PosProduct product) async {
    final line = await showModalBottomSheet<PosCartLine>(
      context: context, isScrollControlled: true,
      builder: (_) => _UnitSelectorSheet(product: product),
    );
    if (line != null) {
      _addToCart(line);
      setState(() => _searchQuery = '');
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _openPayment() async {
    if (_cart.isEmpty) return;
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (_) => _PaymentSheet(
        repository: _repo,
        companyId: widget.companyId,
        cart: _cart,
        customer: _selectedCustomer,
        discount: _discount,
        total: _total,
        customerBalance: _customerBalance,
      ),
    );
    if (ok == true) {
      setState(() { _cart.clear(); _discount = 0; _selectedCustomer = null; _searchQuery = ''; });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: () => setState(() => _cart.clear()),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ]),
      ));
    }

    return Column(children: [
      _CustomerBar(
        customer: _selectedCustomer,
        onTap: _openCustomerPicker,
        onClear: () => setState(() => _selectedCustomer = null),
      ),
      _SearchField(
        value: _searchQuery,
        onChanged: (v) => setState(() => _searchQuery = v),
        onScan: _openScanner,
      ),
      Expanded(child: _isSearching ? _buildSplitView() : _buildCart()),
      if (!_isSearching && _cart.isNotEmpty)
        _BottomPanel(
          subtotal: _subtotal,
          discount: _discount,
          total: _total,
          onDiscountChanged: (v) => setState(() => _discount = v),
          onPay: _openPayment,
        ),
    ]);
  }

  Widget _buildSplitView() {
    return Column(children: [
      const _SectionLabel(icon: Icons.search, label: 'نتائج البحث'),
      Flexible(
        flex: 2,
        child: _ResultsList(
          products: _filteredProducts,
          onTap: _openUnitSelector,
        ),
      ),
      const Divider(height: 1),
      const _SectionLabel(icon: Icons.shopping_cart_outlined, label: 'السلة'),
      Flexible(
        flex: 3,
        child: _buildCart(),
      ),
    ]);
  }

  Widget _buildCart() {
    if (_cart.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('السلة فارغة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('ابحث عن منتج أو امسح الباركود', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]));
    }
    return ListView.separated(
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _CartLineTile(
        line: _cart[i],
        onQtyChanged: (q) => _updateQty(i, q),
        onPriceChanged: (p) => _updatePrice(i, p),
        onRemove: () => _removeLine(i),
      ),
    );
  }
}

// ============================================================
// Sub-widgets
// ============================================================

class _CustomerBar extends StatelessWidget {
  final PosCustomer? customer;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _CustomerBar({this.customer, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final has = customer != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12), onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(has ? Icons.person : Icons.person_outline, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Text(has ? customer!.name : 'عميل نقدي',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  if (has && customer!.hasDebt)
                    Text('الرصيد: ${customer!.balance.toStringAsFixed(2)} ج.م',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                ],
              )),
              if (has)
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClear)
              else
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('تغيير', style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_left, color: theme.colorScheme.primary, size: 18),
                ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onScan;
  const _SearchField({required this.value, required this.onChanged, required this.onScan});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم أو الباركود أو الكود',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: widget.onScan),
            if (_ctrl.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.close),
                  onPressed: () { _ctrl.clear(); widget.onChanged(''); }),
          ]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(children: [
        Icon(icon, size: 14, color: c.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary)),
      ]),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<PosProduct> products;
  final ValueChanged<PosProduct> onTap;
  const _ResultsList({required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(child: Text('لا توجد منتجات مطابقة',
          style: TextStyle(color: Colors.grey.shade500)));
    }
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = products[i];
        final theme = Theme.of(context);
        return InkWell(
          onTap: () => onTap(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(Icons.inventory_2_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${p.defaultUnitName} · ${p.stockQty.toStringAsFixed(0)} متاح',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              )),
              Text('${p.defaultPrice.toStringAsFixed(2)} ج.م',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13)),
            ]),
          ),
        );
      },
    );
  }
}

class _CartLineTile extends StatefulWidget {
  final PosCartLine line;
  final ValueChanged<double> onQtyChanged;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onRemove;
  const _CartLineTile({required this.line, required this.onQtyChanged,
    required this.onPriceChanged, required this.onRemove});

  @override
  State<_CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends State<_CartLineTile> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: _fmt(widget.line.quantity));
    _priceCtrl = TextEditingController(text: _fmt(widget.line.unitPrice));
  }

  @override
  void didUpdateWidget(covariant _CartLineTile old) {
    super.didUpdateWidget(old);
    if (old.line.quantity != widget.line.quantity) _qtyCtrl.text = _fmt(widget.line.quantity);
    if (old.line.unitPrice != widget.line.unitPrice) _priceCtrl.text = _fmt(widget.line.unitPrice);
  }

  @override
  void dispose() { _qtyCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  void _commitQty() {
    final v = double.tryParse(_qtyCtrl.text);
    if (v != null && v > 0) { widget.onQtyChanged(v); }
    else { _qtyCtrl.text = _fmt(widget.line.quantity); }
  }

  void _commitPrice() {
    final v = double.tryParse(_priceCtrl.text);
    if (v != null) { widget.onPriceChanged(v); }
    else { _priceCtrl.text = _fmt(widget.line.unitPrice); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.line.productName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(widget.line.unitName,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        ),
        const SizedBox(width: 4),
        SizedBox(width: 52, height: 38, child: TextField(
          controller: _qtyCtrl, textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: OutlineInputBorder()),
          onSubmitted: (_) => _commitQty(),
          onTapOutside: (_) { FocusScope.of(context).unfocus(); _commitQty(); },
        )),
        const SizedBox(width: 4),
        SizedBox(width: 72, height: 38, child: TextField(
          controller: _priceCtrl, textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: OutlineInputBorder()),
          onSubmitted: (_) => _commitPrice(),
          onTapOutside: (_) { FocusScope.of(context).unfocus(); _commitPrice(); },
        )),
        const SizedBox(width: 6),
        SizedBox(width: 72, child: Text(widget.line.lineTotal.toStringAsFixed(2),
            textAlign: TextAlign.end, style: TextStyle(
              fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 12))),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
          onPressed: widget.onRemove,
        ),
      ]),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final double subtotal, discount, total;
  final ValueChanged<double> onDiscountChanged;
  final VoidCallback onPay;
  const _BottomPanel({required this.subtotal, required this.discount,
    required this.total, required this.onDiscountChanged, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('المجموع الفرعي', style: TextStyle(fontSize: 13)),
          Text('${subtotal.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('الخصم', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            SizedBox(width: 80, height: 28, child: TextField(
              keyboardType: TextInputType.number, textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(contentPadding: EdgeInsets.zero, isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => onDiscountChanged(double.tryParse(v) ?? 0),
            )),
          ]),
          Text('- ${discount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 13, color: Colors.red)),
        ]),
        const Divider(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('الإجمالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('${total.toStringAsFixed(2)} ج.م',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
          onPressed: onPay,
          icon: const Icon(Icons.payment),
          label: const Text('الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}

// ============================================================
// Dialogs
// ============================================================

class _ScannerPage extends StatelessWidget {
  const _ScannerPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح الباركود')),
      body: MobileScanner(onDetect: (c) {
        for (final b in c.barcodes) {
          if (b.rawValue != null) { Navigator.pop(context, b.rawValue); break; }
        }
      }),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<PosCustomer> customers;
  const _CustomerPickerSheet({required this.customers});
  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty ? widget.customers
        : widget.customers.where((c) =>
            c.name.toLowerCase().contains(_q.toLowerCase()) ||
            (c.phone?.contains(_q) ?? false)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              const Text('اختيار العميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: filtered.isEmpty
            ? const Center(child: Text('لا يوجد عملاء مطابقون', style: TextStyle(color: Colors.grey)))
            : ListView.separated(
                controller: scroll, itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.name),
                    subtitle: c.phone != null ? Text(c.phone!) : null,
                    trailing: c.hasDebt
                      ? Text('${c.balance.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                      : null,
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              )),
        ]),
      ),
    );
  }
}

class _UnitSelectorSheet extends StatefulWidget {
  final PosProduct product;
  const _UnitSelectorSheet({required this.product});
  @override
  State<_UnitSelectorSheet> createState() => _UnitSelectorSheetState();
}

class _UnitSelectorSheetState extends State<_UnitSelectorSheet> {
  late PosProductUnit _selectedUnit;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.product.allUnits.first;
    _qtyCtrl = TextEditingController(text: '1');
    _priceCtrl = TextEditingController(
      text: _selectedUnit.effectivePrice(widget.product.defaultPrice).toStringAsFixed(2));
  }

  @override
  void dispose() { _qtyCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }

  void _submit() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (qty <= 0) return;

    final min = _selectedUnit.effectiveMin(widget.product.minPrice);
    final max = _selectedUnit.effectiveMax(widget.product.maxPrice);
    if (min != null && price < min) return;
    if (max != null && price > max) return;

    Navigator.pop(context, PosCartLine(
      productId: widget.product.id,
      productName: widget.product.name,
      unitId: _selectedUnit.unitId,
      unitName: _selectedUnit.unitName,
      quantity: qty,
      unitPrice: price,
      minPrice: min,
      maxPrice: max,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final min = _selectedUnit.effectiveMin(widget.product.minPrice);
    final max = _selectedUnit.effectiveMax(widget.product.maxPrice);
    final valid = (min == null || price >= min) && (max == null || price <= max) && qty > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(widget.product.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<PosProductUnit>(
            initialValue: _selectedUnit,
            decoration: const InputDecoration(labelText: 'الوحدة', border: OutlineInputBorder(), isDense: true),
            items: widget.product.allUnits.map((u) => DropdownMenuItem(
              value: u, child: Text(u.unitName))).toList(),
            onChanged: (u) {
              if (u == null) return;
              setState(() {
                _selectedUnit = u;
                _priceCtrl.text = u.effectivePrice(widget.product.defaultPrice).toStringAsFixed(2);
              });
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder(), isDense: true),
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _priceCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'السعر', border: const OutlineInputBorder(), isDense: true,
                errorText: valid ? null : (qty <= 0 ? 'كمية' : 'سعر خارج النطاق'),
              ),
              onChanged: (_) => setState(() {}),
            )),
          ]),
          if (min != null || max != null) ...[
            const SizedBox(height: 8),
            Text('النطاق المسموح: ${min?.toStringAsFixed(2) ?? '—'} - ${max?.toStringAsFixed(2) ?? '—'}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48, child: FilledButton(
            onPressed: valid ? _submit : null,
            child: Text('إضافة للسلة (${(qty * price).toStringAsFixed(2)} ج.م)'),
          )),
        ]),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  final PosRepository repository;
  final String companyId;
  final List<PosCartLine> cart;
  final PosCustomer? customer;
  final double discount, total, customerBalance;
  const _PaymentSheet({required this.repository, required this.companyId,
    required this.cart, this.customer, required this.discount,
    required this.total, required this.customerBalance});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late List<PaymentEntry> _payments;
  bool _isCredit = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _payments = [PaymentEntry(method: 'cash', amount: widget.total)];
  }

  double get _totalRequired => widget.total + widget.customerBalance;
  double get _totalPaid => _payments.fold(0, (s, p) => s + p.amount);
  double get _remaining => _totalRequired - _totalPaid;

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_isCredit && widget.customer == null) {
      setState(() => _error = 'البيع الآجل يتطلب اختيار عميل');
      return;
    }
    if (!_isCredit) {
      if (_payments.isEmpty) { setState(() => _error = 'أضف طريقة دفع واحدة على الأقل'); return; }
      if (_totalPaid <= 0) { setState(() => _error = 'أدخل مبلغاً أكبر من صفر'); return; }
      if (_totalPaid > _totalRequired && widget.customer == null) {
        setState(() => _error = 'الدفع الزائد يتطلب اختيار عميل');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await widget.repository.createSale(
        companyId: widget.companyId,
        customerId: widget.customer?.id,
        lines: widget.cart,
        payments: _isCredit ? [] : _payments,
        discount: widget.discount,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  void _addPayment() {
    setState(() => _payments.add(PaymentEntry(
      method: 'cash', amount: _remaining > 0 ? _remaining : 0)));
  }

  void _removePayment(int i) {
    setState(() {
      _payments.removeAt(i);
      if (_payments.isEmpty) _payments.add(const PaymentEntry(method: 'cash', amount: 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                const Text('الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              _buildCustomerRow(theme),
              const SizedBox(height: 12),
              _buildTotalsCard(theme),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('دفع'), icon: Icon(Icons.payments, size: 16)),
                  ButtonSegment(value: true, label: Text('آجل'), icon: Icon(Icons.schedule, size: 16)),
                ],
                selected: {_isCredit},
                onSelectionChanged: (s) => setState(() => _isCredit = s.first),
              ),
              const SizedBox(height: 12),
              if (!_isCredit) ..._buildPayments(theme) else _buildCreditInfo(theme),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.error_outline, size: 18, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
            ])),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'تأكيد البيع'),
              )),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCustomerRow(ThemeData theme) {
    final c = widget.customer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(c != null ? Icons.person : Icons.person_outline, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(c?.name ?? 'عميل نقدي',
            style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _buildTotalsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        if (widget.customerBalance != 0) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('الرصيد السابق'),
            Text(widget.customerBalance.toStringAsFixed(2)),
          ]),
          const SizedBox(height: 4),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('قيمة الفاتورة'),
          Text(widget.total.toStringAsFixed(2)),
        ]),
        const Divider(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('الإجمالي المطلوب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(_totalRequired.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ]),
    );
  }

  List<Widget> _buildPayments(ThemeData theme) {
    return [
      Row(children: [
        const Text('طرق الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton.icon(
          onPressed: _addPayment,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('إضافة'),
        ),
      ]),
      for (int i = 0; i < _payments.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _payments[i].method,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: PaymentEntry.methods.map((m) =>
                    DropdownMenuItem(value: m, child: Text(PaymentEntry.label(m)))).toList(),
                onChanged: (m) => setState(() =>
                    _payments[i] = PaymentEntry(method: m!, amount: _payments[i].amount)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: TextEditingController(text: _payments[i].amount.toStringAsFixed(2)),
                keyboardType: TextInputType.number, textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), isDense: true, suffixText: 'ج.م'),
                onChanged: (v) => setState(() =>
                    _payments[i] = PaymentEntry(method: _payments[i].method, amount: double.tryParse(v) ?? 0)),
              ),
            ),
            if (_payments.length > 1)
              IconButton(icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removePayment(i)),
          ]),
        ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _remaining <= 0.01 && _remaining >= -0.01
              ? Colors.green.shade50
              : _remaining > 0 ? Colors.orange.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _remaining <= 0.01 && _remaining >= -0.01 ? Colors.green
                : _remaining > 0 ? Colors.orange : Colors.blue,
            width: 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            _remaining.abs() <= 0.01 ? 'مطابق' : _remaining > 0 ? 'المتبقي' : 'زيادة (تُضاف للرصيد)',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: _remaining.abs() <= 0.01 ? Colors.green.shade800
                    : _remaining > 0 ? Colors.orange.shade900 : Colors.blue.shade900),
          ),
          Text(_remaining.abs().toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
    ];
  }

  Widget _buildCreditInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('سيتم إضافة كامل قيمة الفاتورة إلى رصيد العميل',
            style: TextStyle(color: Colors.orange))),
      ]),
    );
  }
}
