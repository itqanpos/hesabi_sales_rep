import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../sales/data/invoice_settings_repository.dart';
import '../../../sales/data/sales_history_repository.dart';
import '../../../sales/presentation/widgets/invoice_printer.dart';
import '../../data/pos_repository.dart';
import '../../domain/pos_models.dart';
import '../state/pos_cart_state.dart';
import '../widgets/pos_actions_sheet.dart';
import '../widgets/pos_bottom_panel.dart';
import '../widgets/pos_cart_list.dart';
import '../widgets/pos_customer_bar.dart';
import '../widgets/pos_payment_sheet.dart';
import '../widgets/pos_results_list.dart';
import '../widgets/pos_search_field.dart';
import '../widgets/pos_unit_selector_sheet.dart';
import 'pos_barcode_scanner_page.dart';

class PosPage extends StatefulWidget {
  final String companyId;
  final String branchId;
  final String? branchName;

  const PosPage({
    super.key,
    required this.companyId,
    required this.branchId,
    this.branchName,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final PosRepository _repo;
  late final SalesHistoryRepository _salesRepo;
  final _cart = PosCartController();
  final _searchCtrl = TextEditingController();

  List<PosProduct> _allProducts = [];
  List<PosCustomer> _customers = [];
  PosCartState? _heldCart;

  // Company info for printing
  String _companyName = 'شركة';
  String _companyPhone = '';
  String _repName = '';
  InvoiceSettings _invoiceSettings = InvoiceSettings.defaults();

  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repo = PosRepository(Supabase.instance.client);
    _salesRepo = SalesHistoryRepository(Supabase.instance.client);
    _cart.addListener(_onCartChanged);
    _loadData();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _cart.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Load company info (for print)
      if (userId != null) {
        final member = await client
            .from('company_members')
            .select('companies(name, phone)')
            .eq('user_id', userId)
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();
        final comp = member?['companies'] as Map?;
        _companyName = (comp?['name'] as String?) ?? 'شركة';
        _companyPhone = (comp?['phone'] as String?) ?? '';
        _repName =
            client.auth.currentUser?.userMetadata?['full_name'] as String? ??
                client.auth.currentUser?.email ??
                '';

        final settingsRepo = InvoiceSettingsRepository(client);
        _invoiceSettings =
            await settingsRepo.loadEffective(widget.companyId);
      }

      final products =
          await _repo.loadProducts(widget.companyId, widget.branchId);
      final customers = await _repo.loadCustomers(widget.companyId);

      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _customers = customers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<PosProduct> get _filteredProducts {
    if (_searchQuery.trim().isEmpty) return const [];
    final q = _searchQuery.trim().toLowerCase();
    return _allProducts.where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.barcode ?? '').toLowerCase().contains(q) ||
          (p.sku ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addProduct(PosProduct product) async {
    final unit = await PosUnitSelectorSheet.show(context, product);
    if (unit == null) return;

    final price = unit.effectivePrice(product.defaultPrice);
    final merged = _cart.addLine(
      productId: product.id,
      productName: product.name,
      unitId: unit.unitId,
      unitName: unit.unitName,
      quantity: 1,
      unitPrice: price,
      minPrice: unit.effectiveMin(product.minPrice),
      maxPrice: unit.effectiveMax(product.maxPrice),
    );
    if (merged) _snack('تمت زيادة الكمية في السلة');
  }

  void _onQuantityChanged(int i, double q) => _cart.updateQuantity(i, q);
  void _onRemoveLine(int i) => _cart.removeLine(i);
  void _onDiscountChanged(double d) => _cart.setDiscount(d);

  void _onClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الفاتورة'),
        content:
            const Text('هل تريد حذف جميع الأصناف من السلة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.danger),
            onPressed: () {
              _cart.clear();
              Navigator.pop(ctx);
            },
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPayment() async {
    final saleId = await PosPaymentSheet.show(
      context,
      companyId: widget.companyId,
      cart: _cart.state,
      repo: _repo,
    );
    if (saleId != null) {
      _cart.clear();
      await _showSuccessDialog(saleId);
    }
  }

  Future<void> _showSuccessDialog(String saleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: _C.success, size: 28),
            SizedBox(width: 8),
            Text('تم البيع بنجاح'),
          ],
        ),
        content: const Text('هل تريد طباعة الإيصال؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لاحقاً'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('طباعة'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _printSale(saleId);
    }
  }

  Future<void> _printSale(String saleId) async {
    try {
      final saleDetail = await _salesRepo.getSaleDetail(
        saleId: saleId,
        companyId: widget.companyId,
      );
      if (!mounted) return;
      await InvoicePrinter.print(
        context: context,
        sale: saleDetail,
        companyName: _companyName,
        branchName: widget.branchName ?? 'الفرع الرئيسي',
        companyPhone: _companyPhone,
        settings: _invoiceSettings,
        repName: _repName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشلت الطباعة: $e'),
          backgroundColor: _C.danger,
        ),
      );
    }
  }

  Future<void> _openCustomerPicker() async {
    final picked = await showModalBottomSheet<PosCustomer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(customers: _customers),
    );
    if (picked != null) _cart.setCustomer(picked);
  }

  void _holdCart() {
    if (_cart.state.isEmpty) return;
    setState(() => _heldCart = _cart.state);
    _cart.clear();
    _snack('تم تعليق الفاتورة');
  }

  void _restoreCart() {
    final held = _heldCart;
    if (held == null) return;
    _cart.restore(held);
    setState(() => _heldCart = null);
    _snack('تم استعادة الفاتورة');
  }

  void _openActions() {
    PosActionsSheet.show(
      context,
      hasCart: _cart.state.isNotEmpty,
      heldCart: _heldCart,
      onHold: _holdCart,
      onRestore: _restoreCart,
      onReturns: () => _snack('قريباً: المرتجعات'),
    );
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const PosBarcodeScannerPage(),
      ),
    );
    if (result != null && result.isNotEmpty) {
      _searchCtrl.text = result;
      setState(() => _searchQuery = result);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: _C.primary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('نقطة البيع')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: _C.danger, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isSearching = _searchQuery.trim().isNotEmpty;
    final filtered = _filteredProducts;
    final cart = _cart.state;

    // ⬇️ resizeToAvoidBottomInset: false — لوحة المفاتيح لا ترفع الـ Bottom Panel
    return Scaffold(
      backgroundColor: _C.bg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _C.text),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'نقطة البيع',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _C.text),
            ),
            if (widget.branchName != null && widget.branchName!.isNotEmpty)
              Text(
                widget.branchName!,
                style: const TextStyle(
                    fontSize: 11, color: _C.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _openActions,
            tooltip: 'خيارات',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: Column(
        children: [
          PosCustomerBar(
            customer: cart.customer,
            onTap: _openCustomerPicker,
            onClear: () => _cart.setCustomer(null),
          ),
          PosSearchField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            onScannerTap: _openScanner,
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          ),
          Expanded(
            child: isSearching
                ? Column(
                    children: [
                      _sectionLabel(
                        text: 'نتائج البحث',
                        icon: Icons.search,
                        accent: true,
                      ),
                      Flexible(
                        flex: 2,
                        child: PosResultsList(
                          products: filtered,
                          onProductTap: _addProduct,
                        ),
                      ),
                      _thinDivider(),
                      _sectionLabel(
                        text: 'السلة',
                        icon: Icons.shopping_cart_outlined,
                      ),
                      Flexible(
                        flex: 3,
                        child: PosCartList(
                          lines: cart.lines,
                          onQuantityChanged: _onQuantityChanged,
                          onRemove: _onRemoveLine,
                        ),
                      ),
                    ],
                  )
                : PosCartList(
                    lines: cart.lines,
                    onQuantityChanged: _onQuantityChanged,
                    onRemove: _onRemoveLine,
                  ),
          ),
          PosBottomPanel(
            cart: cart,
            onDiscountChanged: _onDiscountChanged,
            onClearTap: _onClearCart,
            onPayTap: _openPayment,
          ),
        ],
      ),
    );
  }

  // ⬇️ مطابق لـ Hesabi: أيقونة + نص + مسافة + خط أفقي قصير
  Widget _sectionLabel({
    required String text,
    required IconData icon,
    bool accent = false,
  }) {
    final color = accent ? _C.primary : _C.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Container(
            width: 24,
            height: 2,
            decoration: BoxDecoration(
              color: color.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinDivider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: _C.border.withOpacity(0.5),
      );
}

// ─── Customer picker sheet ─────────────────────────────────────────────────
class _CustomerPickerSheet extends StatefulWidget {
  final List<PosCustomer> customers;
  const _CustomerPickerSheet({required this.customers});

  @override
  State<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _ctrl = TextEditingController();
  late List<PosCustomer> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
    _ctrl.addListener(_filter);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _ctrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.customers
          : widget.customers.where((c) {
              return c.name.toLowerCase().contains(q) ||
                  (c.phone ?? '').toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختيار عميل',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو الهاتف',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('لا يوجد عملاء',
                          style: TextStyle(color: _C.textSecondary)))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        return ListTile(
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle: c.phone != null
                              ? Text(c.phone!)
                              : null,
                          trailing: Text(
                            '${c.balance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: c.balance > 0
                                    ? _C.danger
                                    : _C.success),
                          ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}
