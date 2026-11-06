import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/returns_repository.dart';
import '../../domain/return_models.dart';

class NewReturnSheet extends StatefulWidget {
  final String companyId;
  final ReturnsRepository repo;
  const NewReturnSheet({
    super.key,
    required this.companyId,
    required this.repo,
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
  String? _reason;
  final _notesCtrl = TextEditingController();

  // Linked flow
  bool _loadingSales = false;
  List<ReturnableSale> _sales = const [];
  ReturnableSale? _selectedSale;
  bool _loadingItems = false;
  List<ReturnableSaleItem> _saleItems = const [];
  final Map<String, double> _returnQty = {}; // saleItemId → qty

  // Free flow
  final _searchCtrl = TextEditingController();
  bool _loadingProducts = false;
  List<FreeReturnProduct> _searchResults = const [];
  final List<FreeReturnCartLine> _cart = [];

  @override
  void dispose() {
    _notesCtrl.dispose();
    _searchCtrl.dispose();
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

  bool get _hasLines {
    if (_mode == _Mode.linked) {
      return _returnQty.values.any((q) => q > 0);
    }
    return _cart.isNotEmpty;
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
      _searchCtrl.clear();
      _reason = null;
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
        _refund = 'cash'; // credit_note requires customer
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

  Future<void> _searchProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final list = await widget.repo.searchFreeReturnProducts(
        companyId: widget.companyId,
        query: _searchCtrl.text,
        limit: 30,
      );
      if (!mounted) return;
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

  void _addToCart(FreeReturnProduct p) {
    final existing = _cart.where((l) => l.product.id == p.id).firstOrNull;
    setState(() {
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _cart.add(FreeReturnCartLine(product: p, price: p.price));
      }
    });
  }

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
          if (l.product.unitId == null) continue;
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
        height: MediaQuery.of(context).size.height * 0.92,
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

  // ── Linked mode ────────────────────────────────────────────────────────

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
            for (final s in _sales)
              _saleTile(s),
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
                onPressed: () => setState(() {
                  _selectedSale = null;
                  _saleItems = const [];
                  _returnQty.clear();
                }),
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
                : 'الكمية المتاحة للإرجاع: ${_fmtNum(item.returnableQty)} ${item.unitName}',
            style: TextStyle(
                fontSize: 11,
                color: disabled ? _C.warning : _C.textSecondary),
          ),
          if (!disabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: qty > 0
                      ? () => setState(() =>
                          _returnQty[item.id] = (qty - 1).clamp(0, item.returnableQty))
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
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
                          _returnQty[item.id] = n.clamp(0, item.returnableQty));
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
                _QtyButton(
                  icon: Icons.add,
                  onTap: qty < item.returnableQty
                      ? () => setState(() =>
                          _returnQty[item.id] = (qty + 1).clamp(0, item.returnableQty))
                      : null,
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

  // ── Free mode ──────────────────────────────────────────────────────────

  Widget _freeBody() {
    return Column(
      children: [
        if (_customer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _customerBanner(),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: _C.warning, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'بدون عميل — الاسترداد نقدي فقط',
                      style: TextStyle(
                          fontSize: 12,
                          color: _C.warning,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _openCustomerPicker,
                    child: const Text('إضافة عميل'),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _searchProducts(),
            decoration: InputDecoration(
              hintText: 'ابحث باسم المنتج',
              prefixIcon: const Icon(Icons.search),
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
        ),
        if (_loadingProducts)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: _C.primary),
          )
        else if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _C.surfaceGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = _searchResults[i];
                return ListTile(
                  dense: true,
                  onTap: () => _addToCart(p),
                  title: Text(p.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${_fmt(p.price)} / ${p.unitName}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.add_circle,
                      color: _C.primary),
                );
              },
            ),
          ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لم تتم إضافة أي منتجات\nابحث وأضف منتجات للمرتجع',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: _C.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) => _cartLineTile(i),
                ),
        ),
        _footerExtras(),
      ],
    );
  }

  Widget _cartLineTile(int i) {
    final line = _cart[i];
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
                child: Text(line.product.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _cart.removeAt(i)),
                icon: const Icon(Icons.close,
                    size: 18, color: _C.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: line.quantity > 1
                    ? () => setState(() => line.quantity -= 1)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                      text: _fmtNum(line.quantity))
                    ..selection = TextSelection.collapsed(
                        offset: _fmtNum(line.quantity).length),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  onChanged: (v) {
                    final n = double.tryParse(v) ?? 0;
                    setState(() => line.quantity = n.clamp(0.01, 999));
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: line.product.unitName,
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
              _QtyButton(
                icon: Icons.add,
                onTap: () => setState(() => line.quantity += 1),
              ),
              const SizedBox(width: 12),
              Text(_fmt(line.lineTotal),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _C.danger)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer extras (refund + notes) + footer (total+save) ───────────────

  Widget _footerExtras() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      color: _C.surfaceGray,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('طريقة الاسترداد',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: kRefundMethods.map((m) {
              final enabled =
                  m != 'credit_note' || _customer != null;
              final selected = _refund == m;
              return ChoiceChip(
                label: Text(refundLabelOf(m)),
                selected: selected,
                onSelected: enabled
                    ? (_) => setState(() => _refund = m)
                    : null,
                selectedColor: _C.dangerLight,
                disabledColor: _C.border.withOpacity(0.3),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: enabled
                      ? (selected ? _C.danger : _C.text)
                      : _C.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                    color: selected ? _C.danger : _C.border),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'ملاحظات (اختياري)',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

  // ── Shared widgets ─────────────────────────────────────────────────────

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

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap == null ? _C.surfaceGray : _C.dangerLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: onTap == null
                  ? _C.border
                  : _C.danger.withOpacity(0.3)),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap == null ? _C.textSecondary : _C.danger),
      ),
    );
  }
}

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
