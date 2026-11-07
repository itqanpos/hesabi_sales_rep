import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/pos_cart_state.dart';

class PosBottomPanel extends StatefulWidget {
  final PosCartState cart;
  final ValueChanged<double> onDiscountChanged;
  final VoidCallback onClearTap;
  final VoidCallback onPayTap;

  const PosBottomPanel({
    super.key,
    required this.cart,
    required this.onDiscountChanged,
    required this.onClearTap,
    required this.onPayTap,
  });

  @override
  State<PosBottomPanel> createState() => _PosBottomPanelState();
}

class _PosBottomPanelState extends State<PosBottomPanel> {
  late final TextEditingController _discountCtrl;
  final _discountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(
      text: widget.cart.discount > 0
          ? widget.cart.discount.toStringAsFixed(0)
          : '',
    );
    _discountCtrl.addListener(_onDiscountTextChanged);
  }

  @override
  void didUpdateWidget(PosBottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cart.discount != oldWidget.cart.discount &&
        !_discountFocus.hasFocus) {
      _discountCtrl.text = widget.cart.discount > 0
          ? widget.cart.discount.toStringAsFixed(0)
          : '';
    }
  }

  @override
  void dispose() {
    _discountCtrl.removeListener(_onDiscountTextChanged);
    _discountCtrl.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  void _onDiscountTextChanged() {
    final value = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    widget.onDiscountChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.cart.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: _C.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // ⬇️ SafeArea(bottom: true) مطلوب — لإضافة مساحة شريط الـ home indicator على iPhone
      // ولا يتعارض مع لوحة المفاتيح لأن PosPage يمرر MediaQuery.removeViewInsets
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── صف 1: الأصناف (يمين) + الخصم (يسار) ───
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 16, color: _C.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'الأصناف: ${widget.cart.lineCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Text('الخصم',
                      style: TextStyle(
                          fontSize: 12, color: _C.textSecondary)),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 70,
                    height: 30,
                    child: TextField(
                      controller: _discountCtrl,
                      focusNode: _discountFocus,
                      textAlign: TextAlign.center,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '0',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _C.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _C.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('ج.م',
                      style: TextStyle(
                          fontSize: 12, color: _C.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),

              // ─── صف 2: الصافي (يمين) + المبلغ (يسار كبير أخضر) ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'الصافي',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _C.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.cart.total.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _C.primary,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ─── صف 3: إلغاء (يمين) + دفع (يسار عريض) ───
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: isEmpty ? null : widget.onClearTap,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('إلغاء',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _C.textSecondary,
                          side: BorderSide(
                            color: isEmpty ? _C.border : _C.textSecondary,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: isEmpty ? null : widget.onPayTap,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text('دفع',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _C.border,
                          disabledForegroundColor: _C.textSecondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
