import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/returns_repository.dart';
import '../../domain/return_models.dart';

class NewReturnSheet extends StatefulWidget {
  final String companyId;
  final ReturnsRepository repo;
  final ReturnableSale? initialSale;
  final ReturnCustomer? initialCustomer;
  const NewReturnSheet({
    super.key,
    required this.companyId,
    required this.repo,
    this.initialSale,
    this.initialCustomer,
  });

  @override
  State<NewReturnSheet> createState() => _NewReturnSheetState();
}

enum _Mode { picker, linked, free }

class _NewReturnSheetState extends State<NewReturnSheet> {
  _Mode _mode = _Mode.picker;
  bool _saving = false;

  // Shared
  ReturnCustomer? _customer;
  String _refund = 'credit_note';
  final _notesCtrl = TextEditingController();

  // Linked flow
  bool _loadingSales = false;
  List<ReturnableSale> _sales = const [];
  ReturnableSale? _selectedSale;
  bool _loadingItems = false;
  List<ReturnableSaleItem> _saleItems = const [];
  final Map<String, double> _returnQty = {};

  // Free flow
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _hasSearchText = false;
  bool _loadingProducts = false;
  String _searchingQuery = '';
  List<FreeReturnProduct> _searchResults = const [];
  final List<FreeReturnCartLine> _cart = [];

  // Free flow: cart/filter view
  bool _showOnlyCartItems = false;

  @override
  void initState() {
    super.initState();
    final initialSale = widget.initialSale;
    final initialCustomer = widget.initialCustomer;

    if (initialSale != null && initialCustomer != null) {
      // preselect: افتح linked مباشرة على الفاتورة
      _mode = _Mode.linked;
      _customer = initialCustomer;
      _selectedSale = initialSale;
      _loadingItems = true; // يمنع وميض "لا توجد بنود"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pickSale(initialSale);
      });
    } else {
      // الوضع الافتراضي: preload منتجات للمرتجع الحر
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchProducts(query: '');
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────

  double get _grandTotal {
    if (_mode == _Mode.linked) {
      return _saleItems.fold(0.0, (s, item) {
        final q = _returnQty[item.id] ?? 0;
        return s + q * item.unitPrice;
      });
    }
    return _cart.fold(0.0, (s, l) => s + l.lineTotal);
  }

  double get _cartTotal => _cart.fold(0.0, (s, l) => s + l.lineTotal);
  int get _cartLinesCount =>
      _cart.where((l) => l.quantity > 0).length;

  bool get _hasLines {
    if (_mode == _Mode.linked) {
      return _returnQty.values.any((q) => q > 0);
    }
    return _cartLinesCount > 0;
  }

  bool get _canSave {
    if (!_hasLines) return false;
    if (_refund == 'credit_note' && _customer == null) return false;
    return true;
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.danger : _C.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── flows ──────────────────────────────────────────────────────────────

  void _pickMode(_Mode m) {
    setState(() {
      _mode = m;
      _customer = null;
      _selectedSale = null;
      _sales = const [];
      _saleItems = const [];
      _returnQty.clear();
      _cart.clear();
      _searchResults = const [];
      _searchingQuery = '';
      _hasSearchText = false;
      _showOnlyCartItems = false;
      _searchCtrl.clear();
      _refund = 'credit_note';
      _notesCtrl.clear();
    });
    if (m == _Mode.linked || m == _Mode.free) {
      _openCustomerPicker();
    }
  }

  Future<void> _openCustomerPicker() async {
    final picked = await showModalBottomSheet<ReturnCustomer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        companyId: widget.companyId,
        repo: widget.repo,
        allowNone: _mode == _Mode.free,
      ),
    );
    if (!mounted) return;
    if (picked == null && _mode == _Mode.free) {
      setState(() {
        _customer = null;
        if (_refund == 'credit_note') _refund = 'cash';
      });
    } else if (picked != null) {
      setState(() => _customer = picked);
      if (_mode == _Mode.linked) _loadSales();
    }
  }

  Future<void> _loadSales() async {
    if (_customer == null) return;
    setState(() {
      _loadingSales = true;
      _sales = const [];
    });
    try {
      final list = await widget.repo.getReturnableSales(
        companyId: widget.companyId,
        customerId: _customer!.id,
      );
      if (!mounted) return;
      setState(() {
        _sales = list;
        _loadingSales = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSales = false);
      _snack('تعذر تحميل الفواتير: $e', isError: true);
    }
  }

  Future<void> _pickSale(ReturnableSale s) async {
    setState(() {
      _selectedSale = s;
      _loadingItems = true;
      _saleItems = const [];
      _returnQty.clear();
    });
    try {
      final items = await widget.repo.getReturnableSaleItems(
        companyId: widget.companyId,
        saleId: s.id,
      );
      if (!mounted) return;
      setState(() {
        _saleItems = items;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
      _snack('تعذر تحميل بنود الفاتورة: $e', isError: true);
    }
  }

  // ── Free flow: search ──────────────────────────────────────────────────

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    final hasText = v.trim().isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() {
        _hasSearchText = hasText;
        if (!hasText) _showOnlyCartItems = false;
      });
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchProducts(query: v),
    );
  }

  Future<void> _searchProducts({required String query}) async {
    final q = query.trim();
    setState(() {
      _loadingProducts = true;
      _searchingQuery = q;
    });
    try {
      final list = await widget.repo.searchFreeReturnProducts(
        companyId: widget.companyId,
        query: q,
        limit: 60,
      );
      if (!mounted || _searchingQuery != q) return;
      setState(() {
        _searchResults = list;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      _snack('تعذر تحميل المنتجات: $e', isError: true);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _hasSearchText = false;
      _searchResults = const [];
      _searchingQuery = '';
      _loadingProducts = false;
      _showOnlyCartItems = false;
    });
    _searchFocus.requestFocus();
  }

  // ── Free flow: cart ────────────────────────────────────────────────────

  void _incProduct(FreeReturnProduct p) {
    HapticFeedback.lightImpact();
    final existing = _cart.where((l) => l.product.id == p.id).firstOrNull;
    setState(() {
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _cart.add(FreeReturnCartLine(product: p, price: p.price));
      }
    });
  }

  void _decProduct(FreeReturnProduct p) {
    HapticFeedback.lightImpact();
    final existing = _cart.where((l) => l.product.id == p.id).firstOrNull;
    if (existing == null) return;
    setState(() {
      if (existing.quantity <= 1) {
        _cart.removeWhere((l) => l.product.id == p.id);
      } else {
        existing.quantity -= 1;
      }
    });
  }

  void _setProductQty(FreeReturnProduct p, double qty) {
    final existing = _cart.where((l) => l.product.id == p.id).firstOrNull;
    if (existing == null) {
      if (qty > 0) {
        setState(() => _cart.add(
            FreeReturnCartLine(product: p, price: p.price, quantity: qty)));
      }
      return;
    }
    setState(() {
      if (qty <= 0) {
        _cart.removeWhere((l) => l.product.id == p.id);
      } else {
        existing.quantity = qty;
      }
    });
  }

  double _cartQtyOf(FreeReturnProduct p) {
    return _cart
        .where((l) => l.product.id == p.id)
        .fold(0.0, (s, l) => s + l.quantity);
  }

  // ── Save ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    try {
      final lines = <ReturnLineInput>[];

      if (_mode == _Mode.linked) {
        for (final item in _saleItems) {
          final q = _returnQty[item.id] ?? 0;
          if (q <= 0) continue;
          lines.add(ReturnLineInput(
            productId: item.productId,
            unitId: item.unitId,
            quantity: q,
            unitPrice: item.unitPrice,
            saleItemId: item.id,
          ));
        }
      } else {
        for (final l in _cart) {
          if (l.product.unitId == null || l.quantity <= 0) continue;
          lines.add(ReturnLineInput(
            productId: l.product.id,
            unitId: l.product.unitId!,
            quantity: l.quantity,
            unitPrice: l.price,
          ));
        }
      }

      await widget.repo.createReturn(
        companyId: widget.companyId,
        customerId: _customer?.id,
        saleId: _mode == _Mode.linked ? _selectedSale?.id : null,
        refundMethod: _refund,
        items: lines,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('فشل الحفظ: $e', isError: true);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _handle(),
              _titleBar(),
              const Divider(height: 1, color: _C.border),
              Expanded(child: _body()),
              const Divider(height: 1, color: _C.border),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: _C.border,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _titleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          if (_mode != _Mode.picker)
            IconButton(
              onPressed: () => _pickMode(_Mode.picker),
              icon: const Icon(Icons.arrow_back, color: _C.text),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              _mode == _Mode.picker
                  ? 'تسجيل مرتجع'
                  : (_mode == _Mode.linked ? 'مرتجع من فاتورة' : 'مرتجع حر'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          if (_mode == _Mode.free && _cartLinesCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _C.dangerLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart, size: 14, color: _C.danger),
                  const SizedBox(width: 4),
                  Text('${_cartLinesCount}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _C.danger)),
                ],
              ),
            ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: _C.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_mode) {
      case _Mode.picker:
        return _modePicker();
      case _Mode.linked:
        return _linkedBody();
      case _Mode.free:
        return _freeBody();
    }
  }

  // ── Mode picker ────────────────────────────────────────────────────────

  Widget _modePicker() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('اختر نوع المرتجع',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _modeCard(
            title: 'مرتجع من فاتورة',
            subtitle: 'اختيار عميل ثم فاتورة وإرجاع بنود منها',
            icon: Icons.receipt_long,
            color: _C.primary,
            onTap: () => _pickMode(_Mode.linked),
          ),
          const SizedBox(height: 12),
          _modeCard(
            title: 'مرتجع حر',
            subtitle: 'إضافة منتجات مباشرة (بدون فاتورة)',
            icon: Icons.assignment_return,
            color: _C.danger,
            onTap: () => _pickMode(_Mode.free),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: _C.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: color),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //   FREE MODE — POS-like flow
  // ══════════════════════════════════════════════════════════════════════

  Widget _freeBody() {
    return Column(
      children: [
        _freeCustomerChip(),
        _freeSearchField(),
        Expanded(
          child: _showOnlyCartItems
              ? _cartView()
              : _unifiedView(),
        ),
        if (!_showOnlyCartItems && _cartLinesCount > 0)
          _cartMiniBar(),
        _footerExtras(),
      ],
    );
  }

  // ── Customer chip (compact, one line) ──────────────────────────────────

  Widget _freeCustomerChip() {
    final hasCustomer = _customer != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasCustomer
            ? _C.primary.withOpacity(0.08)
            : _C.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCustomer
              ? _C.primary.withOpacity(0.3)
              : _C.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasCustomer ? Icons.person : Icons.warning_amber_rounded,
            color: hasCustomer ? _C.primary : _C.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasCustomer ? _customer!.name : 'بدون عميل — نقدي فقط',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hasCustomer ? _C.primaryDark : _C.warning),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _openCustomerPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasCustomer ? _C.primary : _C.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasCustomer ? 'تغيير' : 'تعيين',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search field (always visible) ──────────────────────────────────────

  Widget _freeSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث باسم المنتج (أو اتركه فارغاً لعرض الكل)',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _C.textSecondary),
          suffixIcon: _hasSearchText
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearSearch,
                )
              : (_showOnlyCartItems
                  ? IconButton(
                      icon: const Icon(Icons.search, size: 20),
                      onPressed: () =>
                          setState(() => _showOnlyCartItems = false),
                    )
                  : null),
          filled: true,
          fillColor: _C.surfaceGray,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Unified view: search results + cart section ────────────────────────

  Widget _unifiedView() {
    if (_loadingProducts && _searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _C.primary),
              SizedBox(height: 12),
              Text('جاري التحميل...',
                  style:
                      TextStyle(fontSize: 13, color: _C.textSecondary)),
            ],
          ),
        ),
      );
    }

    final hasResults = _searchResults.isNotEmpty;
    final hasCart = _cart.isNotEmpty;

    if (!hasResults && !hasCart) {
      return _emptyProductState();
    }

    final displayList = _hasSearchText
        ? _searchResults
        : _cart.map((l) => l.product).toList();

    final showCartBelow = _hasSearchText && hasCart;

    return CustomScrollView(
      slivers: [
        if (displayList.isNotEmpty)
          SliverToBoxAdapter(
            child: _sectionHeader(
              _hasSearchText
                  ? 'نتائج البحث (${displayList.length})'
                  : 'المنتجات المتاحة',
              right: _hasSearchText
                  ? TextButton.icon(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear, size: 14),
                      label: const Text('مسح',
                          style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: _C.textSecondary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  : null,
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _searchRow(displayList[i]),
            childCount: displayList.length,
          ),
        ),
        if (showCartBelow) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(
              'في السلة (${_cart.length} صنف · ${_fmt(_cartTotal)})',
              top: 12,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _cartLineCard(i),
              childCount: _cart.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  Widget _sectionHeader(String title, {Widget? right, double top = 0}) {
    return Container(
      margin: EdgeInsets.only(top: top),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _C.text)),
          const Spacer(),
          if (right != null) right,
        ],
      ),
    );
  }

  // ── Search row with inline qty controls ────────────────────────────────

  Widget _searchRow(FreeReturnProduct p) {
    final qty = _cartQtyOf(p);
    return Container(
      color: Colors.white,
      child: InkWell(
        onTap: () => _incProduct(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: qty > 0
                      ? _C.success.withOpacity(0.12)
                      : _C.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  qty > 0 ? Icons.check_circle : Icons.inventory_2_outlined,
                  color: qty > 0 ? _C.success : _C.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt(p.price)} / ${p.unitName.isEmpty ? "—" : p.unitName}',
                      style: const TextStyle(
                          fontSize: 11, color: _C.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (qty == 0)
                _addButton()
              else
                _qtyStepper(p, qty),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _C.danger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16, color: Colors.white),
          SizedBox(width: 4),
          Text('إضافة',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _qtyStepper(FreeReturnProduct p, double qty) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperBtn(
          icon: Icons.remove,
          onTap: () => _decProduct(p),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 44),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _C.dangerLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _fmtNum(qty),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _C.danger),
          ),
        ),
        _stepperBtn(
          icon: Icons.add,
          onTap: () => _incProduct(p),
        ),
      ],
    );
  }

  Widget _stepperBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _C.dangerLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.danger.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: _C.danger),
      ),
    );
  }

  // ── Cart-only view (when user taps "عرض السلة") ────────────────────────

  Widget _cartView() {
    if (_cart.isEmpty) {
      return _emptyCartState();
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _cartLineCard(i),
    );
  }

  Widget _cartLineCard(int i) {
    final line = _cart[i];
    final lineQtyCtrl = TextEditingController(text: _fmtNum(line.quantity));
    lineQtyCtrl.selection = TextSelection.collapsed(
        offset: lineQtyCtrl.text.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _C.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle,
                color: _C.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.product.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${_fmt(line.price)} / ${line.product.unitName.isEmpty ? "—" : line.product.unitName}',
                  style: const TextStyle(
                      fontSize: 11, color: _C.textSecondary),
                ),
                const SizedBox(height: 4),
                Text('الإجمالي: ${_fmt(line.lineTotal)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _C.danger)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepperBtn(
                    icon: Icons.remove,
                    onTap: () => _decProduct(line.product),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: lineQtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                      onChanged: (v) {
                        final n = double.tryParse(v) ?? 0;
                        if (n > 0) {
                          setState(() => line.quantity = n);
                        }
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: _C.border),
                        ),
                      ),
                    ),
                  ),
                  _stepperBtn(
                    icon: Icons.add,
                    onTap: () => _incProduct(line.product),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _cart.removeAt(i));
                },
                child: const Text('حذف',
                    style: TextStyle(
                        fontSize: 11,
                        color: _C.danger,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty states ───────────────────────────────────────────────────────

  Widget _emptyProductState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: _C.surfaceGray,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search,
                  size: 40, color: _C.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('لا توجد منتجات',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.text)),
            const SizedBox(height: 6),
            const Text('جرّب البحث بكلمة أخرى',
                style:
                    TextStyle(fontSize: 12, color: _C.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _emptyCartState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: _C.surfaceGray,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 40, color: _C.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('لا توجد منتجات في السلة',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.text)),
            const SizedBox(height: 6),
            const Text('ابحث وأضف منتجات',
                style:
                    TextStyle(fontSize: 12, color: _C.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Cart mini bar (floating at bottom during search) ───────────────────

  Widget _cartMiniBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.danger,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text('${_cartLinesCount} صنف',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withOpacity(0.3),
          ),
          Text(_fmt(_cartTotal),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showOnlyCartItems = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('عرض السلة',
                  style: TextStyle(
                      color: _C.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //   LINKED MODE
  // ══════════════════════════════════════════════════════════════════════

  Widget _linkedBody() {
    if (_customer == null) {
      return _emptyState(
        icon: Icons.person_search,
        text: 'اختر عميلاً للبدء',
        action: _openCustomerPicker,
        actionLabel: 'اختيار عميل',
      );
    }

    if (_selectedSale == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _customerBanner(),
            const SizedBox(height: 14),
            const Text('اختر الفاتورة',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_loadingSales)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child:
                          CircularProgressIndicator(color: _C.primary))),
            if (!_loadingSales && _sales.isEmpty)
              _emptyBox('لا توجد فواتير لهذا العميل'),
            for (final s in _sales) _saleTile(s),
          ],
        ),
      );
    }

    return _linkedItemsBody();
  }

  Widget _saleTile(ReturnableSale s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: ListTile(
        onTap: () => _pickSale(s),
        leading: const Icon(Icons.receipt_long, color: _C.primary),
        title: Text('#${s.invoiceNumber}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(_fmtDate(s.saleDate),
            style:
                const TextStyle(fontSize: 11, color: _C.textSecondary)),
        trailing: Text(_fmt(s.total),
            style:
                const TextStyle(fontWeight: FontWeight.w800, color: _C.text)),
      ),
    );
  }

  Widget _linkedItemsBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedSale = null;
                    _saleItems = const [];
                    _returnQty.clear();
                  });
                  if (_customer != null) _loadSales();
                },
                icon: const Icon(Icons.arrow_back, color: _C.text),
              ),
              Expanded(
                child: Text('فاتورة #${_selectedSale!.invoiceNumber}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text(_fmt(_selectedSale!.total),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _C.primary)),
            ],
          ),
        ),
        Expanded(
          child: _loadingItems
              ? const Center(
                  child: CircularProgressIndicator(color: _C.primary))
              : _saleItems.isEmpty
                  ? _emptyBox('لا توجد بنود في هذه الفاتورة')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _saleItems.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _linkedItemTile(_saleItems[i]),
                    ),
        ),
        _footerExtras(),
      ],
    );
  }

  Widget _linkedItemTile(ReturnableSaleItem item) {
    final qty = _returnQty[item.id] ?? 0;
    final disabled = !item.canReturn;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: disabled ? _C.textSecondary : _C.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(_fmt(item.unitPrice),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            disabled
                ? 'تم إرجاع كل الكمية'
                : 'الكمية المتاحة: ${_fmtNum(item.returnableQty)} ${item.unitName}',
            style: TextStyle(
                fontSize: 11,
                color: disabled ? _C.warning : _C.textSecondary),
          ),
          if (!disabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _stepperBtn(
                  icon: Icons.remove,
                  onTap: qty > 0
                      ? () => setState(() =>
                          _returnQty[item.id] =
                              (qty - 1).clamp(0, item.returnableQty))
                      : () {},
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    controller: TextEditingController(
                        text: qty == 0 ? '' : _fmtNum(qty))
                      ..selection = TextSelection.collapsed(
                          offset: qty == 0 ? 0 : _fmtNum(qty).length),
                    onChanged: (v) {
                      final n = double.tryParse(v) ?? 0;
                      setState(() =>
                          _returnQty[item.id] =
                              n.clamp(0, item.returnableQty));
                    },
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: item.unitName,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _C.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _stepperBtn(
                  icon: Icons.add,
                  onTap: qty < item.returnableQty
                      ? () => setState(() =>
                          _returnQty[item.id] =
                              (qty + 1).clamp(0, item.returnableQty))
                      : () {},
                ),
                const SizedBox(width: 12),
                Text(_fmt(qty * item.unitPrice),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _C.danger)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Balance impact preview ────────────────────────────────────────────
  // يعرض للمندوب قبل الحفظ: ماذا سيحدث لرصيد العميل

  Widget _balancePreview() {
    final total = _grandTotal;
    if (total <= 0) return const SizedBox.shrink();

    final isCredit = _refund == 'credit_note';
    final cust = _customer;

    // لا عميل → cash إجباري (credit_note معطّل بدون عميل)
    if (cust == null) {
      return _previewTile(
        bg: _C.surfaceGray,
        fg: _C.textSecondary,
        icon: Icons.payments_outlined,
        text: 'استرداد نقدي: ${_fmt(total)}',
      );
    }

    final oldBal = cust.balance;

    // ── استرداد نقدي ──
    if (!isCredit) {
      if (oldBal > 0) {
        return _previewTile(
          bg: _C.warning.withOpacity(0.08),
          fg: _C.warning,
          icon: Icons.warning_amber_rounded,
          text:
              'تنبيه: العميل مدين بـ ${_fmt(oldBal)}\nالاسترداد النقدي لن يخصم من المديونية',
        );
      }
      return _previewTile(
        bg: _C.surfaceGray,
        fg: _C.textSecondary,
        icon: Icons.payments_outlined,
        text: 'استرداد نقدي: ${_fmt(total)} — لن يتغير رصيد العميل',
      );
    }

    // ── رصيد دائن (credit_note) ──
    final newBal = oldBal - total;

    if (oldBal > 0) {
      final becomesCredit = newBal < -0.001;
      return _previewTile(
        bg: becomesCredit
            ? _C.success.withOpacity(0.08)
            : _C.warning.withOpacity(0.08),
        fg: becomesCredit ? _C.success : _C.warning,
        icon: Icons.trending_down,
        text: becomesCredit
            ? 'خصم ${_fmt(total)} من المديونية + رصيد دائن ${_fmt(-newBal)}\n(${_fmt(oldBal)} → ${_fmt(newBal)})'
            : 'خصم ${_fmt(total)} من المديونية: ${_fmt(oldBal)} → ${_fmt(newBal)}',
      );
    }

    // لا مديونية → يُضاف رصيد دائن
    return _previewTile(
      bg: _C.success.withOpacity(0.08),
      fg: _C.success,
      icon: Icons.add_circle_outline,
      text:
          'إضافة ${_fmt(total)} رصيدًا دائنًا للعميل\n(${_fmt(oldBal)} → ${_fmt(newBal)})',
    );
  }

  Widget _previewTile({
    required Color bg,
    required Color fg,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared: extras + footer ────────────────────────────────────────────

  Widget _footerExtras() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      color: _C.surfaceGray,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('الاسترداد:',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              ...kRefundMethods.map((m) {
                final enabled = m != 'credit_note' || _customer != null;
                final selected = _refund == m;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text(
                      refundLabelOf(m),
                      style: TextStyle(
                          fontSize: 10,
                          color: enabled
                              ? (selected ? _C.danger : _C.text)
                              : _C.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500),
                    ),
                    selected: selected,
                    onSelected: enabled
                        ? (_) => setState(() => _refund = m)
                        : null,
                    selectedColor: _C.dangerLight,
                    disabledColor: _C.border.withOpacity(0.3),
                    side: BorderSide(
                        color: selected ? _C.danger : _C.border),
                    backgroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
            ],
          ),
          // ⬇️ معاينة أثر الرصيد (جديد)
          if (_grandTotal > 0) ...[
            const SizedBox(height: 8),
            _balancePreview(),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 1,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'ملاحظات (اختياري)',
              hintStyle:
                  const TextStyle(fontSize: 11, color: _C.textSecondary),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _C.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الإجمالي',
                  style: TextStyle(
                      fontSize: 11, color: _C.textSecondary)),
              Text(_fmt(_grandTotal),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _C.danger)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (_mode == _Mode.picker || !_canSave || _saving)
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('حفظ المرتجع',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared small widgets ───────────────────────────────────────────────

  Widget _customerBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: _C.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_customer?.name ?? 'بدون عميل',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (_customer?.phone != null)
                  Text(_customer!.phone!,
                      style: const TextStyle(
                          fontSize: 11, color: _C.textSecondary)),
              ],
            ),
          ),
          if (_mode == _Mode.free)
            TextButton(
              onPressed: _openCustomerPicker,
              child: const Text('تغيير'),
            ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String text,
    required VoidCallback action,
    required String actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _C.textSecondary),
            const SizedBox(height: 12),
            Text(text,
                style: const TextStyle(
                    color: _C.textSecondary, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: action,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyBox(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surfaceGray,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(msg,
            style: const TextStyle(
                fontSize: 12, color: _C.textSecondary)),
      );
}

// ─── Customer picker sheet ──────────────────────────────────────────────────

class _CustomerPickerSheet extends StatefulWidget {
  final String companyId;
  final ReturnsRepository repo;
  final bool allowNone;
  const _CustomerPickerSheet({
    required this.companyId,
    required this.repo,
    required this.allowNone,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<ReturnCustomer> _list = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.repo.searchCustomers(
        companyId: widget.companyId,
        query: _ctrl.text,
      );
      if (!mounted) return;
      setState(() {
        _list = list;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: _C.surface,
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
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Text('اختيار عميل',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (widget.allowNone)
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text('تخطي'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: _C.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _C.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو الهاتف',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: _C.surfaceGray,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: _C.primary))
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: _C.danger)))
                      : _list.isEmpty
                          ? const Center(
                              child: Text('لا يوجد عملاء',
                                  style: TextStyle(
                                      color: _C.textSecondary)))
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: _list.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final c = _list[i];
                                return ListTile(
                                  onTap: () =>
                                      Navigator.pop(context, c),
                                  title: Text(c.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: c.phone != null
                                      ? Text(c.phone!)
                                      : null,
                                  trailing: Text(
                                    _fmt(c.balance),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: c.balance > 0
                                          ? _C.danger
                                          : _C.success,
                                    ),
                                  ),
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

// ─── Helpers ────────────────────────────────────────────────────────────────

String _fmt(double v) {
  final f = NumberFormat('#,##0.00', 'en');
  return '${f.format(v)} ج.م';
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

String _fmtDate(DateTime d) => DateFormat('yyyy/MM/dd', 'en').format(d);

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const surface = Colors.white;
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
