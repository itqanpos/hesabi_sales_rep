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

  static Future<String?> show(
    BuildContext context, {
    required String companyId,
    required PosCartState cart,
    required PosRepository repo,
  }) {
    return showModalBottomSheet<String>(
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
    // القيمة الافتراضية = الإجمالي المطلوب (رصيد سابق + فاتورة)
    _payments = [
      _PaymentInput(method: 'cash', amount: _settlementTotal),
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
    final r = _settlementTotal - _totalPaid;
    return r > 0 ? r : 0;
  }

  double get _overpay {
    final o = _totalPaid - _settlementTotal;
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
    if (!_isCredit &&
        _totalPaid < _cartTotal &&
        !widget.cart.hasCustomer) {
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

      final saleId = await widget.repo.createSale(
        companyId: widget.companyId,
        customerId: widget.cart.customer?.id,
        lines: widget.cart.lines,
        payments: payments,
        discount: widget.cart.discount,
      );

      if (!mounted) return;
      Navigator.pop(context, saleId);
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
                // Handle
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
                // Title
                Row(
                  children: [
                    const Text('الدفع',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                // Customer
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _C.surfaceGray,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.person,
                          color: _C.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.cart.customer?.name ?? 'عميل نقدي',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Settlement Totals (Previous Balance + Invoice + Total Required)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _C.surfaceGray,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      if (widget.cart.hasCustomer && _customerBalance != 0) ...[
                        _row('الرصيد السابق',
                            '${_customerBalance.toStringAsFixed(2)} ج.م',
                            color: _customerBalance > 0
                                ? _C.danger
                                : _C.success),
                        const SizedBox(height: 6),
                      ],
                      _row('قيمة الفاتورة',
                          '${_cartTotal.toStringAsFixed(2)} ج.م'),
                      const Divider(height: 16),
                      _row('الإجمالي المطلوب',
                          '${_settlementTotal.toStringAsFixed(2)} ج.م',
                          emphasized: true, color: _C.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Pay / Credit toggle
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
                const SizedBox(height: 16),

                if (!_isCredit) ...[
                  // Payment methods section title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('طرق الدفع',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  // Payment methods rows
                  for (int i = 0; i < _payments.length; i++) ...[
                    _paymentRow(i),
                    const SizedBox(height: 8),
                  ],
                  // Add payment method
                  TextButton.icon(
                    onPressed: _addPayment,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة طريقة دفع'),
                  ),
                  const SizedBox(height: 12),
                  // Status banner (green if settled, red if remaining)
                  _remainingBanner(),
                ] else ...[
                  // Credit info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: _C.warningLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: _C.warning),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سيتم إضافة كامل قيمة الفاتورة إلى رصيد العميل.',
                            style: TextStyle(
                                fontSize: 13,
                                color: _C.warning,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                // Big green submit button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _saving ? 'جاري الحفظ...' : 'إتمام البيع',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _C.border,
                      disabledForegroundColor: _C.textSecondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool emphasized = false, Color? color}) {
    final fontSize = emphasized ? 20.0 : 14.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: fontSize - 2,
                fontWeight:
                    emphasized ? FontWeight.w800 : FontWeight.w600,
                color: color ?? _C.text)),
        Text(value,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                color: color ?? _C.text)),
      ],
    );
  }

  Widget _paymentRow(int i) {
    final p = _payments[i];
    return Row(
      children: [
        // Method dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: _C.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: p.method,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.arrow_drop_down, color: _C.primaryDark),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.primaryDark),
            items: PaymentEntry.methods.map((m) {
              return DropdownMenuItem(
                value: m,
                child: Text(PaymentEntry.label(m)),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => p.method = v);
            },
          ),
        ),
        const SizedBox(width: 8),
        // Amount input
        Expanded(
          child: TextField(
            controller: p.controller,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'ج.م',
              filled: true,
              fillColor: _C.surfaceGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            onChanged: (v) {
              setState(
                  () => p.amount = double.tryParse(v) ?? 0);
            },
          ),
        ),
        if (_payments.length > 1) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, color: _C.danger, size: 20),
            onPressed: () => _removePayment(i),
          ),
        ],
      ],
    );
  }

  Widget _remainingBanner() {
    final Color color;
    final IconData icon;
    final String label;
    if (_remaining > 0.001) {
      color = _C.danger;
      icon = Icons.pending_outlined;
      label = 'المتبقي: ${_remaining.toStringAsFixed(2)} ج.م';
    } else if (_overpay > 0.001) {
      color = _C.success;
      icon = Icons.trending_up;
      label = 'زيادة: ${_overpay.toStringAsFixed(2)} ج.م (تُضاف للرصيد)';
    } else {
      color = _C.success;
      icon = Icons.check_circle;
      label = 'المدفوع مطابق للمطلوب';
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const warningLight = Color(0xFFFFF3E0);
  static const danger = Color(0xFFC62828);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
