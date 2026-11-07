import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/pos_repository.dart';
import '../../domain/pos_models.dart';
import '../state/pos_cart_state.dart';

class PosPaymentSheet extends StatefulWidget {
  final String companyId;
  final PosCartState cart;
  final PosRepository repo;

  const PosPaymentSheet({
    super.key,
    required this.companyId,
    required this.cart,
    required this.repo,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String companyId,
    required PosCartState cart,
    required PosRepository repo,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosPaymentSheet(
        companyId: companyId,
        cart: cart,
        repo: repo,
      ),
    );
  }

  @override
  State<PosPaymentSheet> createState() => _PosPaymentSheetState();
}

class _PaymentInput {
  String method;
  double amount;
  final TextEditingController controller;
  _PaymentInput({required this.method, required this.amount})
      : controller = TextEditingController(
            text: amount == 0 ? '' : amount.toStringAsFixed(2));
  void dispose() => controller.dispose();
}

class _PosPaymentSheetState extends State<PosPaymentSheet> {
  late List<_PaymentInput> _payments;
  bool _isCredit = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _payments = [
      _PaymentInput(method: 'cash', amount: widget.cart.total),
    ];
  }

  @override
  void dispose() {
    for (final p in _payments) {
      p.dispose();
    }
    super.dispose();
  }

  double get _cartTotal => widget.cart.total;
  double get _customerBalance => widget.cart.customerBalance;
  double get _settlementTotal => _customerBalance + _cartTotal;
  double get _totalPaid =>
      _payments.fold(0.0, (s, p) => s + p.amount);

  double get _remaining {
    final r = _cartTotal - _totalPaid;
    return r > 0 ? r : 0;
  }

  double get _overpay {
    final o = _totalPaid - _cartTotal;
    return o > 0 ? o : 0;
  }

  void _addPayment() {
    setState(() {
      _payments.add(_PaymentInput(
        method: 'cash',
        amount: _remaining > 0 ? _remaining : 0,
      ));
    });
  }

  void _removePayment(int i) {
    setState(() {
      _payments[i].dispose();
      _payments.removeAt(i);
      if (_payments.isEmpty) {
        _payments.add(_PaymentInput(method: 'cash', amount: 0));
      }
    });
  }

  Future<void> _submit() async {
    if (widget.cart.isEmpty) return;
    if (!_isCredit && _payments.isEmpty) return;

    if (_isCredit && !widget.cart.hasCustomer) {
      _snack('البيع الآجل يتطلب اختيار عميل', isError: true);
      return;
    }
    if (!_isCredit && _totalPaid <= 0) {
      _snack('أدخل مبلغاً أكبر من صفر', isError: true);
      return;
    }
    if (!_isCredit && _totalPaid < _cartTotal && !widget.cart.hasCustomer) {
      _snack('الدفع الجزئي يتطلب اختيار عميل', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final payments = _isCredit
          ? <PaymentEntry>[]
          : _payments
              .where((p) => p.amount > 0)
              .map((p) =>
                  PaymentEntry(method: p.method, amount: p.amount))
              .toList();

      await widget.repo.createSale(
        companyId: widget.companyId,
        customerId: widget.cart.customer?.id,
        lines: widget.cart.lines,
        payments: payments,
        discount: widget.cart.discount,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('فشل: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.danger : _C.success,
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
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _C.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: [
                    const Text('الدفع',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                // العميل
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: _C.surfaceGray,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: _C.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.cart.customer?.name ?? 'عميل نقدي',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // الإجماليات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي المطلوب:',
                        style: TextStyle(fontSize: 14)),
                    Text('${_settlementTotal.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _C.primary)),
                  ],
                ),
                const Divider(),
                // Toggle Pay/Credit
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false,
                        label: Text('دفع'),
                        icon: Icon(Icons.payments, size: 16)),
                    ButtonSegment(
                        value: true,
                        label: Text('آجل'),
                        icon: Icon(Icons.schedule, size: 16)),
                  ],
                  selected: {_isCredit},
                  onSelectionChanged: (s) =>
                      setState(() => _isCredit = s.first),
                ),
                const SizedBox(height: 12),
                if (!_isCredit) ...[
                  for (int i = 0; i < _payments.length; i++) ...[
                    _paymentRow(i),
                    const SizedBox(height: 8),
                  ],
                  TextButton.icon(
                    onPressed: _addPayment,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة طريقة دفع'),
                  ),
                  const SizedBox(height: 8),
                  _remainingBanner(),
                ] else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _C.warningLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: _C.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سيتم إضافة كامل قيمة الفاتورة إلى رصيد العميل.',
                            style: TextStyle(fontSize: 12, color: _C.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white))
                        : const Text('إتمام البيع',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentRow(int i) {
    final p = _payments[i];
    return Row(
      children: [
        DropdownButton<String>(
          value: p.method,
          underline: const SizedBox.shrink(),
          items: PaymentEntry.methods.map((m) {
            return DropdownMenuItem(
              value: m,
              child: Text(PaymentEntry.label(m),
                  style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => p.method = v);
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: p.controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'ج.م',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            onChanged: (v) {
              setState(() => p.amount = double.tryParse(v) ?? 0);
            },
          ),
        ),
        if (_payments.length > 1)
          IconButton(
            icon: const Icon(Icons.close, color: _C.danger, size: 18),
            onPressed: () => _removePayment(i),
          ),
      ],
    );
  }

  Widget _remainingBanner() {
    final Color color;
    final String label;
    if (_remaining > 0.001) {
      color = _C.danger;
      label = 'المتبقي: ${_remaining.toStringAsFixed(2)} ج.م';
    } else if (_overpay > 0.001) {
      color = _C.success;
      label = 'زيادة: ${_overpay.toStringAsFixed(2)} ج.م (تُضاف للرصيد)';
    } else {
      color = _C.success;
      label = 'المدفوع مطابق للمطلوب';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
              _remaining > 0.001
                  ? Icons.pending_outlined
                  : Icons.check_circle,
              size: 18,
              color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
          Text('${_totalPaid.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const warningLight = Color(0xFFFFF3E0);
  static const danger = Color(0xFFC62828);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
}
