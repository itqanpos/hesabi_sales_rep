import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/pos_models.dart';

class PosCartLineTile extends StatelessWidget {
  final PosCartLine line;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onRemove;

  const PosCartLineTile({
    super.key,
    required this.line,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
  });

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
          // اسم المنتج (يمين — Expanded)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.productName,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  line.unitName,
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
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              controller: TextEditingController(
                  text: _fmtQty(line.quantity))
                ..selection = TextSelection.collapsed(
                    offset: _fmtQty(line.quantity).length),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800),
              onChanged: (v) {
                final n = double.tryParse(v) ?? 0;
                if (n > 0) onQuantityChanged(n);
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
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              controller: TextEditingController(
                  text: line.unitPrice.toStringAsFixed(2))
                ..selection = TextSelection.collapsed(
                    offset: line.unitPrice.toStringAsFixed(2).length),
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
              onChanged: (v) {
                final n = double.tryParse(v) ?? 0;
                if (n > 0) onPriceChanged(n);
              },
              decoration: _inputDec(),
            ),
          ),
          const SizedBox(width: 6),

          // الإجمالي
          SizedBox(
            width: 66,
            child: Text(
              '${line.lineTotal.toStringAsFixed(2)} ج.م',
              textAlign: TextAlign.left,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _C.primary),
            ),
          ),
          const SizedBox(width: 2),

          // زر الحذف (يسار)
          InkWell(
            onTap: onRemove,
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
