import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/collections_repository.dart';
import '../../domain/collection_models.dart';

class NewPaymentSheet extends StatefulWidget {
  final String companyId;
  final CollectionsRepository repo;
  const NewPaymentSheet({
    super.key,
    required this.companyId,
    required this.repo,
  });

  @override
  State<NewPaymentSheet> createState() => _NewPaymentSheetState();
}

class _NewPaymentSheetState extends State<NewPaymentSheet> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loadingCustomers = true;
  String? _customersError;
  List<CollectionCustomer> _customers = const [];

  CollectionCustomer? _selectedCustomer;

  bool _loadingInvoices = false;
  List<CustomerInvoice> _invoices = const [];

  String _method = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _loadingCustomers = true;
      _customersError = null;
    });
    try {
      final list = await widget.repo.searchCustomers(
        companyId: widget.companyId,
        query: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _customers = list;
        _loadingCustomers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _customersError = e.toString();
        _loadingCustomers = false;
      });
    }
  }

  Future<void> _selectCustomer(CollectionCustomer c) async {
    setState(() {
      _selectedCustomer = c;
      _loadingInvoices = true;
      _invoices = const [];
    });
    try {
      final invoices = await widget.repo.getCustomerInvoices(
        companyId: widget.companyId,
        customerId: c.id,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _loadingInvoices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoices = const [];
        _loadingInvoices = false;
      });
      _snack('تعذر تحميل الفواتير: $e', isError: true);
    }
  }

  Future<void> _save() async {
    final cust = _selectedCustomer;
    if (cust == null) {
      _snack('اختر العميل أولاً', isError: true);
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _snack('أدخل مبلغاً صحيحاً أكبر من صفر', isError: true);
      return;
    }
    if (amount > cust.balance + 0.001) {
      _snack('المبلغ أكبر من رصيد العميل (${_fmt(cust.balance)})',
          isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repo.createPayment(
        companyId: widget.companyId,
        customerId: cust.id,
        amount: amount,
        method: _method,
        reference: _referenceCtrl.text,
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

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.danger : _C.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(),
              _title(),
              const Divider(height: 1, color: _C.border),
              Flexible(child: _body()),
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

  Widget _title() {
    final canPop = _selectedCustomer == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          if (!canPop)
            IconButton(
              onPressed: () => setState(() {
                _selectedCustomer = null;
                _invoices = const [];
                _amountCtrl.clear();
              }),
              icon: const Icon(Icons.arrow_back, color: _C.text),
            )
          else
            const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'تسجيل دفعة',
              style: TextStyle(
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
    if (_selectedCustomer == null) return _customerPicker();
    return _paymentForm();
  }

  // ── Step 1: pick customer ─────────────────────────────────────────────
  Widget _customerPicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ابحث باسم العميل أو الهاتف',
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
            onChanged: (_) => _loadCustomers(),
          ),
        ),
        if (_loadingCustomers)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: _C.primary),
          )
        else if (_customersError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _customersError!,
              style: const TextStyle(color: _C.danger),
            ),
          )
        else if (_customers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لا يوجد عملاء',
              style: TextStyle(color: _C.textSecondary),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: _customers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = _customers[i];
                return ListTile(
                  onTap: () => _selectCustomer(c),
                  title: Text(
                    c.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle:
                      c.phone != null ? Text(c.phone!) : null,
                  trailing: Text(
                    _fmt(c.balance),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: c.balance > 0 ? _C.danger : _C.success,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Step 2: enter payment ─────────────────────────────────────────────
  Widget _paymentForm() {
    final cust = _selectedCustomer!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _customerCard(cust),
          const SizedBox(height: 14),
          _label('فواتير العميل السابقة'),
          const SizedBox(height: 6),
          _invoicesBlock(),
          const SizedBox(height: 14),
          _label('المبلغ المحصَّل'),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: '0.00',
              suffixText: 'ج.م',
              filled: true,
              fillColor: _C.surfaceGray,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('طريقة الدفع'),
          const SizedBox(height: 6),
          _methodChips(),
          const SizedBox(height: 14),
          _label('مرجع (اختياري)'),
          const SizedBox(height: 6),
          TextField(
            controller: _referenceCtrl,
            decoration: _inputDec('رقم التحويل أو الإيصال'),
          ),
          const SizedBox(height: 10),
          _label('ملاحظات (اختياري)'),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: _inputDec('ملاحظات إضافية'),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(CollectionCustomer c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: _C.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: _C.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                if (c.phone != null)
                  Text(
                    c.phone!,
                    style: const TextStyle(
                        fontSize: 12, color: _C.textSecondary),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'الرصيد المستحق',
                style: TextStyle(
                    fontSize: 11, color: _C.textSecondary),
              ),
              Text(
                _fmt(c.balance),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _C.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _invoicesBlock() {
    if (_loadingInvoices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _C.primary),
          ),
        ),
      );
    }
    if (_invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.surfaceGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'لا توجد فواتير سابقة',
          style: TextStyle(fontSize: 13, color: _C.textSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final inv in _invoices.take(5))
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${inv.invoiceNumber}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _fmtDate(inv.saleDate),
                        style: const TextStyle(
                            fontSize: 11,
                            color: _C.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmt(inv.total),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _C.text),
                    ),
                    if (!inv.fullyPaidAtSale)
                      Text(
                        'مدفوع مقدم: ${_fmt(inv.paidAtSale)}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _C.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (_invoices.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${_invoices.length - 5} فاتورة أخرى',
              style: const TextStyle(
                  fontSize: 12, color: _C.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _methodChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kPaymentMethods.map((m) {
        final selected = _method == m;
        return ChoiceChip(
          label: Text(methodLabelOf(m)),
          selected: selected,
          onSelected: (_) => setState(() => _method = m),
          selectedColor: _C.primaryLight,
          labelStyle: TextStyle(
            color: selected ? _C.primaryDark : _C.text,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
              color: selected ? _C.primary : _C.border),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed:
              (_selectedCustomer == null || _saving) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : Text(
                  _selectedCustomer == null
                      ? 'اختر عميلاً'
                      : 'حفظ الدفعة',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _C.surfaceGray,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

// ─── Helpers ────────────────────────────────────────────────────────────────

String _fmt(double v) {
  final f = NumberFormat('#,##0.00', 'en');
  return '${f.format(v)} ج.م';
}

String _fmtDate(DateTime d) =>
    DateFormat('yyyy/MM/dd', 'en').format(d);

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFC62828);
  static const surface = Colors.white;
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
