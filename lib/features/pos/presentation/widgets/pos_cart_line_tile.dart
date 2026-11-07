import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/pos_models.dart';

class PosCartLineTile extends StatefulWidget {
  final PosCartLine line;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onRemove;

  /// عند `true`، يُركَّز تلقائياً على حقل الكمية ثم يستدعي [onFocusConsumed]
  final bool shouldFocus;
  final VoidCallback? onFocusConsumed;

  const PosCartLineTile({
    super.key,
    required this.line,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
    this.shouldFocus = false,
    this.onFocusConsumed,
  });

  @override
  State<PosCartLineTile> createState() => _PosCartLineTileState();
}

class _PosCartLineTileState extends State<PosCartLineTile> {
  late final FocusNode _qtyFocusNode;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();

    _qtyFocusNode = FocusNode();
    final qtyText = _fmtQty(widget.line.quantity);
    _qtyCtrl = TextEditingController(text: qtyText);
    _qtyCtrl.selection = TextSelection.collapsed(offset: qtyText.length);

    final priceText = widget.line.unitPrice.toStringAsFixed(2);
    _priceCtrl = TextEditingController(text: priceText);
    _priceCtrl.selection = TextSelection.collapsed(offset: priceText.length);

    // ⬇️ إذا ظهر السطر لأول مرة وshouldFocus=true → ركّز
    if (widget.shouldFocus) {
      _requestFocus();
    }
  }

  @override
  void didUpdateWidget(covariant PosCartLineTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // مزامنة الكمية عند التغيير الخارجي (بدون تركيز)
    if (widget.line.quantity != oldWidget.line.quantity &&
        !_qtyFocusNode.hasFocus) {
      final text = _fmtQty(widget.line.quantity);
      _qtyCtrl.text = text;
      _qtyCtrl.selection = TextSelection.collapsed(offset: text.length);
    }

    // مزامنة السعر
    if (widget.line.unitPrice != oldWidget.line.unitPrice) {
      final text = widget.line.unitPrice.toStringAsFixed(2);
      _priceCtrl.text = text;
    }

    // ⬇️ عند تغيّر shouldFocus من false → true → ركّز
    if (widget.shouldFocus && !oldWidget.shouldFocus) {
      _requestFocus();
    }
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qtyFocusNode.requestFocus();
      // حدد كل النص — كتابة الرقم الجديد تستبدل القديم
      _qtyCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _qtyCtrl.text.length,
      );
      widget.onFocusConsumed?.call();
    });
  }

  @override
  void dispose() {
    _qtyFocusNode.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _C.border, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // اسم المنتج
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.line.productName,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.line.unitName,
                  style: const TextStyle(
                      fontSize: 10, color: _C.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // حقل الكمية
          SizedBox(
            width: 46,
            height: 30,
            child: TextField(
              controller: _qtyCtrl,
              focusNode: _qtyFocusNode,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800),
              onChanged: (v) {
                final n = double.tryParse(v) ?? 0;
                if (n > 0) widget.onQuantityChanged(n);
              },
              decoration: _inputDec(),
            ),
          ),
          const SizedBox(width: 4),

          // حقل السعر
          SizedBox(
            width: 64,
            height: 30,
            child: TextField(
              controller: _priceCtrl,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
              onChanged: (v) {
                final n = double.tryParse(v) ?? 0;
                if (n > 0) widget.onPriceChanged(n);
              },
              decoration: _inputDec(),
            ),
          ),
          const SizedBox(width: 6),

          // الإجمالي
          SizedBox(
            width: 66,
            child: Text(
              '${widget.line.lineTotal.toStringAsFixed(2)} ج.م',
              textAlign: TextAlign.left,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _C.primary),
            ),
          ),
          const SizedBox(width: 2),

          // زر الحذف
          InkWell(
            onTap: widget.onRemove,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close,
                  size: 16, color: _C.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtQty(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  InputDecoration _inputDec() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _C.surfaceGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _C.border),
        ),
      );
}

class _C {
  static const primary = Color(0xFF00897B);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF757575);
}
