import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/pos_models.dart';
import '../../data/pos_repository.dart';

// ============================================================
// ألوان Hesabi الرسمية (مطابقة للصور)
// ============================================================
class _C {
  static const primary       = Color(0xFF00897B);
  static const primaryDark   = Color(0xFF00695C);
  static const primaryLight  = Color(0xFFE0F2F1);
  static const success       = Color(0xFF2E7D32);
  static const successLight  = Color(0xFFE8F5E9);
  static const warning       = Color(0xFFE65100);
  static const warningLight  = Color(0xFFFFF3E0);
  static const danger        = Color(0xFFC62828);
  static const dangerLight   = Color(0xFFFFEBEE);
  static const surface       = Colors.white;
  static const surfaceGray   = Color(0xFFF5F5F5);
  static const border        = Color(0xFFE0E0E0);
  static const text          = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg            = Color(0xFFFAFAFA);
}

class PosPage extends StatefulWidget {
  final String companyId;
  final String branchId;
  const PosPage({super.key, required this.companyId, required this.branchId});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final PosRepository _repo;

  List<PosProduct> _products = [];
  List<PosCustomer> _customers = [];
  String _companyName = '';

  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  PosCustomer? _selectedCustomer;
  List<PosCartLine> _cart = [];
  double _discount = 0;
  String? _focusedLineKey;

  @override
  void initState() {
    super.initState();
    _repo = PosRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final productsF = _repo.loadProducts(widget.companyId, widget.branchId);
      final customersF = _repo.loadCustomers(widget.companyId);
      final companyF = Supabase.instance.client
          .from('companies')
          .select('name')
          .eq('id', widget.companyId)
          .maybeSingle();

      final products = await productsF;
      final customers = await customersF;
      final companyRes = await companyF;

      if (!mounted) return;
      setState(() {
        _products = products;
        _customers = customers;
        _companyName = ((companyRes)?['name'] as String?) ?? 'الشركة';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

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

  void _addToCart(PosCartLine line) {
    FocusScope.of(context).unfocus();
    setState(() {
      final i = _cart.indexWhere((l) => l.key == line.key);
      if (i >= 0) {
        _cart[i] = _cart[i].copyWith(quantity: _cart[i].quantity + line.quantity);
      } else {
        _cart.add(line);
      }
      _focusedLineKey = line.key;
      _searchQuery = '';
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

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openScanner() async {
    final barcode = await Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
    if (barcode != null && barcode.isNotEmpty) {
      setState(() => _searchQuery = barcode);
      if (_filteredProducts.length == 1) _openUnitSelector(_filteredProducts.first);
    }
  }

  Future<void> _openCustomerPicker() async {
    final picked = await showModalBottomSheet<PosCustomer>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(customers: _customers),
    );
    if (picked != null) setState(() => _selectedCustomer = picked);
  }

  Future<void> _openUnitSelector(PosProduct product) async {
    final line = await showModalBottomSheet<PosCartLine>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnitSelectorSheet(product: product),
    );
    if (line != null) _addToCart(line);
  }

  Future<void> _openPayment() async {
    if (_cart.isEmpty) return;
    final result = await showModalBottomSheet<PosCartLine>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        repository: _repo,
        companyId: widget.companyId,
        companyName: _companyName,
        cart: _cart,
        customer: _selectedCustomer,
        discount: _discount,
        total: _total,
        customerBalance: _customerBalance,
      ),
    );
    if (result != null) {
      setState(() { _cart.clear(); _discount = 0; _selectedCustomer = null; _searchQuery = ''; });
      _load();
    }
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الفاتورة'),
        content: const Text('هل تريد مسح جميع المنتجات من السلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _C.danger),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() { _cart.clear(); _discount = 0; _selectedCustomer = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('نقطة البيع',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _C.text)),
        iconTheme: const IconThemeData(color: _C.text),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _C.primary));
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error, color: _C.danger, size: 48),
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
      if (!_isSearching)
        _BottomPanel(
          itemCount: _cart.length,
          discount: _discount,
          total: _total,
          onDiscountChanged: (v) => setState(() => _discount = v),
          onPay: _cart.isNotEmpty ? _openPayment : null,
          onCancel: _cart.isNotEmpty ? _confirmCancel : null,
        ),
    ]);
  }

  Widget _buildSplitView() {
    return Column(children: [
      const _SectionLabel(icon: Icons.search, label: 'نتائج البحث'),
      Flexible(
        flex: 2,
        child: _ResultsList(products: _filteredProducts, onTap: _openUnitSelector),
      ),
      const Divider(height: 1, color: _C.border),
      const _SectionLabel(icon: Icons.shopping_cart_outlined, label: 'السلة'),
      Flexible(flex: 3, child: _buildCart()),
    ]);
  }

  Widget _buildCart() {
    if (_cart.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('السلة فارغة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('ابحث عن منتج أو امسح الباركود لإضافته.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]));
    }
    return ListView.separated(
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border),
      itemBuilder: (_, i) {
        final line = _cart[i];
        return _CartLineTile(
          key: ValueKey(line.key),
          line: line,
          shouldFocus: _focusedLineKey == line.key,
          onFocusReceived: () {
            if (_focusedLineKey == line.key) setState(() => _focusedLineKey = null);
          },
          onQtyChanged: (q) => _updateQty(i, q),
          onPriceChanged: (p) => _updatePrice(i, p),
          onRemove: () => _removeLine(i),
        );
      },
    );
  }
}

// ============================================================
// Widgets
// ============================================================

class _CustomerBar extends StatelessWidget {
  final PosCustomer? customer;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _CustomerBar({this.customer, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final has = customer != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: _C.surfaceGray,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12), onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(has ? Icons.person : Icons.person_outline,
                  color: _C.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Text(has ? customer!.name : 'عميل نقدي',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 14, color: _C.text)),
                  if (has && customer!.hasDebt)
                    Text('الرصيد: ${customer!.balance.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(color: _C.danger,
                            fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              )),
              if (has)
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClear)
              else
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('تغيير', style: TextStyle(
                      color: _C.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Icon(Icons.chevron_left, color: _C.primary, size: 20),
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
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: _C.text),
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم أو الكود أو امسح الباركود',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          filled: true,
          fillColor: _C.surface,
          prefixIcon: const Icon(Icons.search, color: _C.textSecondary),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: _C.textSecondary),
              onPressed: widget.onScan,
            ),
            if (_ctrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, color: _C.textSecondary),
                onPressed: () { _ctrl.clear(); widget.onChanged(''); },
              ),
          ]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(children: [
        Icon(icon, size: 15, color: _C.primary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.bold, color: _C.primary)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: _C.primary.withOpacity(0.15))),
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
      separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border),
      itemBuilder: (_, i) {
        final p = products[i];
        final (bg, fg, label) = p.stockQty <= 0
            ? (_C.dangerLight, _C.danger, 'نفد')
            : p.stockQty <= 10
                ? (_C.warningLight, _C.warning, '${p.stockQty.toInt()} متبقٍ')
                : (_C.successLight, _C.success, '${p.stockQty.toInt()} متاح');
        return InkWell(
          onTap: () => onTap(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_outlined,
                    size: 20, color: _C.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14, color: _C.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(p.defaultUnitName,
                      style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: fg.withOpacity(0.3)),
                ),
                child: Text(label, style: TextStyle(fontSize: 10.5,
                    color: fg, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text('${p.defaultPrice.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      color: _C.primary, fontSize: 14)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, size: 18, color: _C.textSecondary),
            ]),
          ),
        );
      },
    );
  }
}

class _CartLineTile extends StatefulWidget {
  final PosCartLine line;
  final bool shouldFocus;
  final VoidCallback? onFocusReceived;
  final ValueChanged<double> onQtyChanged;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onRemove;

  const _CartLineTile({
    Key? key,
    required this.line,
    required this.shouldFocus,
    this.onFocusReceived,
    required this.onQtyChanged,
    required this.onPriceChanged,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<_CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends State<_CartLineTile> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  final _qtyFocus = FocusNode();
  final _priceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: _fmt(widget.line.quantity));
    _priceCtrl = TextEditingController(text: _fmt(widget.line.unitPrice));
    if (widget.shouldFocus) _requestQtyFocus();
  }

  @override
  void didUpdateWidget(covariant _CartLineTile old) {
    super.didUpdateWidget(old);
    if (old.line.quantity != widget.line.quantity && !_qtyFocus.hasFocus) {
      _qtyCtrl.text = _fmt(widget.line.quantity);
    }
    if (old.line.unitPrice != widget.line.unitPrice && !_priceFocus.hasFocus) {
      _priceCtrl.text = _fmt(widget.line.unitPrice);
    }
    if (widget.shouldFocus && !old.shouldFocus) _requestQtyFocus();
  }

  void _requestQtyFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qtyFocus.requestFocus();
      _qtyCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _qtyCtrl.text.length,
      );
      try { SystemChannels.textInput.invokeMethod<void>('TextInput.show').ignore(); } catch (_) {}
      widget.onFocusReceived?.call();
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose(); _priceCtrl.dispose();
    _qtyFocus.dispose(); _priceFocus.dispose();
    super.dispose();
  }

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: _C.surface,
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Text(widget.line.productName,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.text),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 54, height: 36, child: TextField(
          controller: _qtyCtrl, focusNode: _qtyFocus, textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _qtyFocus.hasFocus ? _C.primary : _C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _C.primary, width: 1.8)),
          ),
          onSubmitted: (_) => _commitQty(),
          onTapOutside: (_) { FocusScope.of(context).unfocus(); _commitQty(); },
        )),
        const SizedBox(width: 4),
        SizedBox(width: 44, child: Text(widget.line.unitName,
            style: const TextStyle(fontSize: 11, color: _C.textSecondary),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
        SizedBox(width: 64, height: 36, child: TextField(
          controller: _priceCtrl, focusNode: _priceFocus, textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _C.primary, width: 1.8)),
          ),
          onSubmitted: (_) => _commitPrice(),
          onTapOutside: (_) { FocusScope.of(context).unfocus(); _commitPrice(); },
        )),
        const SizedBox(width: 6),
        SizedBox(width: 70, child: Text('${widget.line.lineTotal.toStringAsFixed(2)} ج.م',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold,
                color: _C.primary, fontSize: 12.5),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: _C.textSecondary),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          onPressed: widget.onRemove,
        ),
      ]),
    );
  }
}

class _BottomPanel extends StatefulWidget {
  final int itemCount;
  final double discount;
  final double total;
  final ValueChanged<double> onDiscountChanged;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;

  const _BottomPanel({
    required this.itemCount, required this.discount, required this.total,
    required this.onDiscountChanged, required this.onPay, required this.onCancel,
  });

  @override
  State<_BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<_BottomPanel> {
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(
        text: widget.discount == 0 ? '0' : widget.discount.toStringAsFixed(2));
  }

  @override
  void dispose() { _discountCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('الأصناف: ${widget.itemCount}',
                    style: const TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 13, color: _C.text)),
                const SizedBox(width: 6),
                const Icon(Icons.shopping_bag_outlined, size: 18, color: _C.textSecondary),
              ]),
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.ltr,
                children: [
                  const Text('الخصم',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 13, color: _C.text)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60, height: 30,
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _C.text),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero, isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _C.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _C.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _C.primary, width: 1.5)),
                      ),
                      onChanged: (v) => widget.onDiscountChanged(double.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('ج.م',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 13, color: _C.text)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الصافي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _C.text)),
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.ltr,
                children: [
                  Text('${widget.total.toStringAsFixed(2)} ج.م',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _C.primary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('إلغاء', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                foregroundColor: _C.textSecondary,
                side: const BorderSide(color: _C.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.onPay,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('دفع',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _C.border,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ]),
        ],
      ),
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
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              const Text('اختيار العميل',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _C.text)),
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
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.primary, width: 1.5)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: filtered.isEmpty
            ? const Center(child: Text('لا يوجد عملاء مطابقون', style: TextStyle(color: _C.textSecondary)))
            : ListView.separated(
                controller: scroll, itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border),
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _C.primaryLight,
                      child: const Icon(Icons.person, color: _C.primary),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: c.phone != null ? Text(c.phone!) : null,
                    trailing: c.hasDebt
                      ? Text('${c.balance.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(color: _C.danger, fontWeight: FontWeight.bold))
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
      quantity: qty, unitPrice: price,
      minPrice: min, maxPrice: max,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final min = _selectedUnit.effectiveMin(widget.product.minPrice);
    final max = _selectedUnit.effectiveMax(widget.product.maxPrice);
    final valid = (min == null || price >= min) &&
        (max == null || price <= max) && qty > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(widget.product.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _C.text))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<PosProductUnit>(
            value: _selectedUnit,
            decoration: InputDecoration(
              labelText: 'الوحدة',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.primary, width: 1.5)),
              isDense: true,
            ),
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
              decoration: InputDecoration(
                labelText: 'الكمية',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.primary, width: 1.5)),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _priceCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'السعر',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.primary, width: 1.5)),
                isDense: true,
                errorText: valid ? null : (qty <= 0 ? 'كمية غير صحيحة' : 'سعر خارج النطاق'),
              ),
              onChanged: (_) => setState(() {}),
            )),
          ]),
          if (min != null || max != null) ...[
            const SizedBox(height: 8),
            Text('النطاق المسموح: ${min?.toStringAsFixed(2) ?? '—'} - ${max?.toStringAsFixed(2) ?? '—'} ج.م',
                style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 50, child: FilledButton(
            onPressed: valid ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: _C.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('إضافة للسلة (${(qty * price).toStringAsFixed(2)} ج.م)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          )),
        ]),
      ),
    );
  }
}

// ============================================================
// Payment Sheet
// ============================================================
class _PaymentSheet extends StatefulWidget {
  final PosRepository repository;
  final String companyId;
  final String companyName;
  final List<PosCartLine> cart;
  final PosCustomer? customer;
  final double discount, total, customerBalance;
  const _PaymentSheet({
    required this.repository, required this.companyId, required this.companyName,
    required this.cart, this.customer, required this.discount,
    required this.total, required this.customerBalance,
  });

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
      setState(() => _error = 'البيع الآجل يتطلب اختيار عميل'); return;
    }
    if (!_isCredit) {
      if (_payments.isEmpty) { setState(() => _error = 'أضف طريقة دفع'); return; }
      if (_totalPaid <= 0) { setState(() => _error = 'أدخل مبلغاً أكبر من صفر'); return; }
      if (_totalPaid > _totalRequired && widget.customer == null) {
        setState(() => _error = 'الدفع الزائد يتطلب اختيار عميل'); return;
      }
    }

    setState(() => _saving = true);
    try {
      final saleId = await widget.repository.createSale(
        companyId: widget.companyId,
        customerId: widget.customer?.id,
        lines: widget.cart,
        payments: _isCredit ? [] : _payments,
        discount: widget.discount,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await _showSuccessDialog(saleId);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  Future<void> _showSuccessDialog(String saleId) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(
        companyName: widget.companyName,
        cart: widget.cart,
        payments: _isCredit ? [] : _payments,
        customer: widget.customer,
        discount: widget.discount,
        subtotal: widget.total + widget.discount,
        total: widget.total,
        saleId: saleId,
      ),
    );
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
    return DraggableScrollableSheet(
      initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(children: [
                const Text('الدفع',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _C.text)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: _C.text),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Expanded(child: ListView(controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              _buildCustomerRow(),
              const SizedBox(height: 14),
              _buildTotalCard(),
              const SizedBox(height: 16),
              Container(
                height: 46,
                decoration: BoxDecoration(
                  border: Border.all(color: _C.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isCredit = false),
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(24), right: Radius.zero),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isCredit ? _C.primaryLight : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.zero, left: Radius.circular(24)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check, size: 18,
                              color: !_isCredit ? _C.primaryDark : _C.textSecondary),
                          const SizedBox(width: 6),
                          Text('دفع', style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: !_isCredit ? _C.primaryDark : _C.textSecondary)),
                        ]),
                      ),
                    ),
                  ),
                  Container(width: 1, color: _C.border),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isCredit = true),
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.zero, right: Radius.circular(24)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isCredit ? _C.primaryLight : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.zero, right: Radius.circular(24)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.schedule, size: 18,
                              color: _isCredit ? _C.primaryDark : _C.textSecondary),
                          const SizedBox(width: 6),
                          Text('آجل', style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _isCredit ? _C.primaryDark : _C.textSecondary)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (!_isCredit) ..._buildPayments() else _buildCreditInfo(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _C.dangerLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 18, color: _C.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(color: _C.danger, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
            ])),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 22),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'إتمام البيع',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
              )),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCustomerRow() {
    final c = widget.customer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: _C.surfaceGray,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(c != null ? Icons.person : Icons.person_outline, color: _C.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(c?.name ?? 'عميل نقدي',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _C.text))),
      ]),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(color: _C.primaryLight,
          borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        const Text('الإجمالي المطلوب',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.primaryDark)),
        const SizedBox(height: 8),
        Text('${_totalRequired.toStringAsFixed(2)} ج.م',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _C.primaryDark)),
        if (widget.customerBalance != 0) ...[
          const SizedBox(height: 8),
          Text('يشمل رصيد سابق ${widget.customerBalance.toStringAsFixed(2)} ج.م',
              style: const TextStyle(fontSize: 11, color: _C.primaryDark)),
        ],
      ]),
    );
  }

  List<Widget> _buildPayments() {
    return [
      const Text('طرق الدفع',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _C.text)),
      const SizedBox(height: 10),
      for (int i = 0; i < _payments.length; i++) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _C.surfaceGray,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _payments[i].method,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: _C.primaryDark),
                style: const TextStyle(fontWeight: FontWeight.w700,
                    color: _C.primaryDark, fontSize: 13),
                items: PaymentEntry.methods.map((m) => DropdownMenuItem(
                  value: m,
                  child: Row(children: [
                    Icon(_methodIcon(m), size: 16, color: _C.primaryDark),
                    const SizedBox(width: 4),
                    Text(PaymentEntry.label(m)),
                  ]),
                )).toList(),
                onChanged: (m) => setState(() => _payments[i] =
                    PaymentEntry(method: m!, amount: _payments[i].amount)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _payments[i].amount.toStringAsFixed(2),
                keyboardType: TextInputType.number, textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: const TextStyle(fontWeight: FontWeight.bold,
                    color: _C.text, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixText: 'ج.م',
                  suffixStyle: const TextStyle(color: _C.textSecondary, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _C.primary, width: 1.5)),
                ),
                onChanged: (v) => setState(() =>
                    _payments[i] = PaymentEntry(method: _payments[i].method,
                        amount: double.tryParse(v) ?? 0)),
              ),
            ),
            if (_payments.length > 1)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _C.textSecondary),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: () => _removePayment(i),
              ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      TextButton.icon(
        onPressed: _addPayment,
        icon: const Icon(Icons.add, size: 18, color: _C.primary),
        label: const Text('إضافة طريقة دفع',
            style: TextStyle(color: _C.primary, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _remaining.abs() <= 0.01 ? _C.successLight
              : _remaining > 0 ? _C.warningLight : _C.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _remaining.abs() <= 0.01 ? _C.success.withOpacity(0.3)
                : _remaining > 0 ? _C.warning.withOpacity(0.3) : _C.primary.withOpacity(0.3),
          ),
        ),
        child: Row(children: [
          Icon(
            _remaining.abs() <= 0.01 ? Icons.check_circle
                : _remaining > 0 ? Icons.pending_outlined : Icons.trending_up,
            size: 20,
            color: _remaining.abs() <= 0.01 ? _C.success
                : _remaining > 0 ? _C.warning : _C.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            _remaining.abs() <= 0.01 ? 'المدفوع مطابق للمطلوب'
                : _remaining > 0 ? 'المتبقي' : 'زيادة (تُضاف للرصيد)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                color: _remaining.abs() <= 0.01 ? _C.success
                    : _remaining > 0 ? _C.warning : _C.primary),
          )),
          Text(_remaining.abs().toStringAsFixed(2),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                  color: _remaining.abs() <= 0.01 ? _C.success
                      : _remaining > 0 ? _C.warning : _C.primary)),
        ]),
      ),
    ];
  }

  Widget _buildCreditInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _C.warningLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.warning.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.info_outline, color: _C.warning, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text(
          'سيتم إضافة كامل قيمة الفاتورة إلى رصيد العميل.',
          style: TextStyle(color: _C.warning, fontSize: 13, fontWeight: FontWeight.w600),
        )),
      ]),
    );
  }

  IconData _methodIcon(String m) => {
    'cash': Icons.payments_outlined, 'card': Icons.credit_card,
    'instapay': Icons.phone_iphone, 'bank_transfer': Icons.account_balance_outlined,
    'other': Icons.more_horiz,
  }[m] ?? Icons.more_horiz;
}

// ============================================================
// Success Dialog
// ============================================================
class _SuccessDialog extends StatelessWidget {
  final String companyName;
  final List<PosCartLine> cart;
  final List<PaymentEntry> payments;
  final PosCustomer? customer;
  final double discount, subtotal, total;
  final String saleId;

  const _SuccessDialog({
    required this.companyName, required this.cart, required this.payments,
    this.customer, required this.discount, required this.subtotal,
    required this.total, required this.saleId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90, height: 90,
            decoration: const BoxDecoration(color: _C.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 56, color: _C.primaryDark),
          ),
          const SizedBox(height: 20),
          const Text('تم البيع بنجاح',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _C.text)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await showDialog(
                  context: context,
                  builder: (_) => _ReceiptDialog(
                    companyName: companyName, cart: cart, payments: payments,
                    customer: customer, discount: discount,
                    subtotal: subtotal, total: total, saleId: saleId,
                  ),
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة الإيصال',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('مشاركة'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                side: const BorderSide(color: _C.border),
                foregroundColor: _C.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('فاتورة جديدة'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                side: const BorderSide(color: _C.border),
                foregroundColor: _C.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ============================================================
// Receipt Dialog
// ============================================================
class _ReceiptDialog extends StatelessWidget {
  final String companyName;
  final List<PosCartLine> cart;
  final List<PaymentEntry> payments;
  final PosCustomer? customer;
  final double discount, subtotal, total;
  final String saleId;

  const _ReceiptDialog({
    required this.companyName, required this.cart, required this.payments,
    this.customer, required this.discount, required this.subtotal,
    required this.total, required this.saleId,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final invoiceNum = 'INV-${now.year}-${saleId.substring(0, 4).toUpperCase()}';
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            const Text('معاينة الإيصال',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _C.text)),
            const SizedBox(width: 8),
            const Icon(Icons.print_outlined, color: _C.primary),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Icon(Icons.zoom_in, color: _C.textSecondary, size: 20),
            const Text('100%', style: TextStyle(fontSize: 12, color: _C.textSecondary)),
            const Icon(Icons.zoom_out, color: _C.textSecondary, size: 20),
          ]),
          const SizedBox(height: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.surface,
                border: Border.all(color: _C.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(child: Text(companyName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _C.text))),
                  const SizedBox(height: 4),
                  const Center(child: Text('الفرع الرئيسي',
                      style: TextStyle(fontSize: 11, color: _C.textSecondary))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: _C.text)),
                    child: const Center(child: Text('فاتورة مبيعات',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('رقم الفاتورة:', invoiceNum, isBold: true),
                  _infoRow('التاريخ:', '$dateStr — ${now.hour}:${now.minute.toString().padLeft(2, '0')}'),
                  _infoRow('الكاشير:', customer?.name ?? 'عميل نقدي'),
                  const Divider(height: 16),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: _C.text)),
                    child: Column(children: [
                      Container(
                        color: _C.surfaceGray,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: const [
                          Expanded(flex: 1, child: _T('م', bold: true)),
                          Expanded(flex: 4, child: _T('الصنف', bold: true)),
                          Expanded(flex: 2, child: _T('الكمية', bold: true)),
                          Expanded(flex: 2, child: _T('السعر', bold: true)),
                          Expanded(flex: 2, child: _T('الإجمالي', bold: true)),
                        ]),
                      ),
                      for (int i = 0; i < cart.length; i++)
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: _C.text, width: 0.5)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Expanded(flex: 1, child: _T('${i + 1}')),
                            Expanded(flex: 4, child: _T(cart[i].productName)),
                            Expanded(flex: 2, child: _T('${cart[i].quantity.toInt()} ${cart[i].unitName}')),
                            Expanded(flex: 2, child: _T(cart[i].unitPrice.toStringAsFixed(0))),
                            Expanded(flex: 2, child: _T(cart[i].lineTotal.toStringAsFixed(0))),
                          ]),
                        ),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: _C.text, width: 0.5)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          const Expanded(flex: 7, child: _T('المجموع الفرعي', bold: true)),
                          Expanded(flex: 2, child: _T('', bold: true)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: _C.text)),
                    child: Column(children: [
                      if (discount > 0)
                        _totalRow('الخصم', '-${discount.toStringAsFixed(0)}', danger: true),
                      _totalRow('إجمالي الفاتورة', total.toStringAsFixed(0)),
                      for (final p in payments)
                        _totalRow(PaymentEntry.label(p.method), p.amount.toStringAsFixed(0)),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: _C.text, width: 0.5)),
                        ),
                        child: _totalRow(
                            'المدفوع',
                            payments.fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(0),
                            bold: true),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Center(child: Text('شكراً لتعاملكم معنا',
                      style: TextStyle(fontSize: 11, color: _C.textSecondary))),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, height: 46,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('مشاركة'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _C.border),
                foregroundColor: _C.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _C.text)),
        const SizedBox(width: 6),
        Expanded(child: Text(value, style: TextStyle(
            fontSize: 11, color: _C.text,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
      ]),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, bool danger = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.text, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
            fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: danger ? _C.danger : _C.text))),
        Text(value, style: TextStyle(
            fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: danger ? _C.danger : _C.text)),
      ]),
    );
  }
}

class _T extends StatelessWidget {
  final String text;
  final bool bold;
  const _T(this.text, {this.bold = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10.5, color: _C.text,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal));
}
