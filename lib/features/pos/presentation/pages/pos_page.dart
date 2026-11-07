import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../sales/data/invoice_settings_repository.dart';
import '../../../sales/data/sales_history_repository.dart';
import '../../../sales/domain/sales_models.dart';
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

enum _PostSaleAction { later, print, share }

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

  String _companyName = 'شركة';
  String _companyPhone = '';
  String _repName = '';
  InvoiceSettings _invoiceSettings = InvoiceSettings.defaults();

  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  String? _focusLineKey;

  static DateTime? _lastLoad;
  static List<PosProduct>? _cachedProducts;
  static List<PosCustomer>? _cachedCustomers;

  @override
  void initState() {
    super.initState();
    _repo = PosRepository(Supabase.instance.client);
    _salesRepo = SalesHistoryRepository(Supabase.instance.client);
    _loadData();
  }

  @override
  void dispose() {
    _cart.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool force = false}) async {
    if (!force &&
        _lastLoad != null &&
        DateTime.now().difference(_lastLoad!).inMinutes < 5 &&
        _cachedProducts != null &&
        _cachedCustomers != null) {
      setState(() {
        _allProducts = _cachedProducts!;
        _customers = _cachedCustomers!;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      final productsFuture =
          _repo.loadProducts(widget.companyId, widget.branchId);
      final customersFuture = _repo.loadCustomers(widget.companyId);
      final settingsFuture =
          InvoiceSettingsRepository(client).loadEffective(widget.companyId);

      Future<Map<String, dynamic>?>? companyFuture;
      if (userId != null) {
        companyFuture = client
            .from('company_members')
            .select('companies(name, phone)')
            .eq('user_id', userId)
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();
      }

      final products = await productsFuture;
      final customers = await customersFuture;
      _invoiceSettings = await settingsFuture;

      if (companyFuture != null) {
        final member = await companyFuture;
        if (member != null) {
          final comp = member['companies'] as Map?;
          _companyName = (comp?['name'] as String?) ?? 'شركة';
          _companyPhone = (comp?['phone'] as String?) ?? '';
        }
        _repName =
            client.auth.currentUser?.userMetadata?['full_name'] as String? ??
                client.auth.currentUser?.email ??
                '';
      }

      _cachedProducts = products;
      _cachedCustomers = customers;
      _lastLoad = DateTime.now();

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

  // ⬇️ التعديل: تفريغ البحث بعد الإضافة + التركيز على حقل الكمية
  Future<void> _addProduct(PosProduct product) async {
    final unit = await PosUnitSelectorSheet.show(context, product);
    if (unit == null) return;

    final lineKey = '${product.id}::${unit.unitId}';
    final price = unit.effectivePrice(product.defaultPrice);

    _cart.addLine(
      productId: product.id,
      productName: product.name,
      unitId: unit.unitId,
      unitName: unit.unitName,
      quantity: 1,
      unitPrice: price,
      minPrice: unit.effectiveMin(product.minPrice),
      maxPrice: unit.effectiveMax(product.maxPrice),
    );

    // ✅ تفريغ البحث + التركيز على حقل الكمية
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _focusLineKey = lineKey;
    });
  }

  void _onQuantityChanged(int i, double q) => _cart.updateQuantity(i, q);
  void _onPriceChanged(int i, double p) => _cart.updatePrice(i, p);
  void _onRemoveLine(int i) => _cart.removeLine(i);
  void _onDiscountChanged(double d) => _cart.setDiscount(d);

  void _onClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الفاتورة'),
        content: const Text('هل تريد حذف جميع الأصناف من السلة؟'),
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
    final action = await showDialog<_PostSaleAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: _C.success, size: 28),
            SizedBox(width: 8),
            Text('تم البيع بنجاح'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('هل تريد طباعة أو مشاركة الإيصال؟'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, _PostSaleAction.print),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('طباعة الإيصال'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, _PostSaleAction.share),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('مشاركة الفاتورة'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: _C.primary,
                side: const BorderSide(color: _C.primary, width: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PostSaleAction.later),
            child: const Text('لاحقاً'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == _PostSaleAction.print) {
      await _printSale(saleId);
    } else if (action == _PostSaleAction.share) {
      await _shareSale(saleId);
    }
  }

  Future<void> _printSale(String saleId) async {
    final saleDetail = await _loadSaleDetail(saleId);
    if (!mounted) return;
    if (saleDetail == null) {
      _snack('تعذر تحميل الفاتورة للطباعة');
      return;
    }
    await InvoicePrinter.print(
      context: context,
      sale: saleDetail,
      companyName: _companyName,
      branchName: widget.branchName ?? 'الفرع الرئيسي',
      companyPhone: _companyPhone,
      settings: _invoiceSettings,
      repName: _repName,
    );
  }

  Future<void> _shareSale(String saleId) async {
    final saleDetail = await _loadSaleDetail(saleId);
    if (!mounted) return;
    if (saleDetail == null) {
      _snack('تعذر تحميل الفاتورة للمشاركة');
      return;
    }
    await InvoicePrinter.share(
      context: context,
      sale: saleDetail,
      companyName: _companyName,
      branchName: widget.branchName ?? 'الفرع الرئيسي',
      companyPhone: _companyPhone,
      settings: _invoiceSettings,
      repName: _repName,
    );
  }

  Future<SaleDetail?> _loadSaleDetail(String saleId) async {
    try {
      return await _salesRepo.getSaleDetail(
        saleId: saleId,
        companyId: widget.companyId,
      );
    } catch (e) {
      _snack('فشل تحميل الفاتورة: $e');
      return null;
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
      MaterialPageRoute(builder: (_) => const PosBarcodeScannerPage()),
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
                    onPressed: () => _loadData(force: true),
                    child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }

    final isSearching = _searchQuery.trim().isNotEmpty;

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
          ValueListenableBuilder<PosCartState>(
            valueListenable: _cart,
            builder: (_, cart, __) => PosCustomerBar(
              customer: cart.customer,
              onTap: _openCustomerPicker,
              onClear: () => _cart.setCustomer(null),
            ),
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
            child: ValueListenableBuilder<PosCartState>(
              valueListenable: _cart,
              builder: (_, cart, __) {
                if (isSearching) {
                  final filtered = _filteredProducts;
                  return Column(
                    children: [
                      _sectionLabel(
                          text: 'نتائج البحث',
                          icon: Icons.search,
                          accent: true),
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
                          icon: Icons.shopping_cart_outlined),
                      Flexible(
                        flex: 3,
                        child: PosCartList(
                          lines: cart.lines,
                          focusLineKey: _focusLineKey,
                          onFocusConsumed: () {
                            if (_focusLineKey != null) {
                              setState(() => _focusLineKey = null);
                            }
                          },
                          onQuantityChanged: _onQuantityChanged,
                          onPriceChanged: _onPriceChanged,
                          onRemove: _onRemoveLine,
                        ),
                      ),
                    ],
                  );
                }
                return PosCartList(
                  lines: cart.lines,
                  focusLineKey: _focusLineKey,
                  onFocusConsumed: () {
                    if (_focusLineKey != null) {
                      setState(() => _focusLineKey = null);
                    }
                  },
                  onQuantityChanged: _onQuantityChanged,
                  onPriceChanged: _onPriceChanged,
                  onRemove: _onRemoveLine,
                );
              },
            ),
          ),
          MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: ValueListenableBuilder<PosCartState>(
              valueListenable: _cart,
              builder: (_, cart, __) => PosBottomPanel(
                cart: cart,
                onDiscountChanged: _onDiscountChanged,
                onClearTap: _onClearCart,
                onPayTap: _openPayment,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel({
    required String text,
    required IconData icon,
    bool accent = false,
  }) {
    final color = accent ? _C.primary : _C.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              color: color.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
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

class _CustomerPickerSheet extends StatefulWidget {
  final List<PosCustomer> customers;
  const _CustomerPickerSheet({required this.customers});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        return ListTile(
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle:
                              c.phone != null ? Text(c.phone!) : null,
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
