import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/pos_models.dart';

class PosCartLineTile extends StatelessWidget {
  final PosCartLine line;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;

  const PosCartLineTile({
    super.key,
    required this.line,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  line.productName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: _C.danger),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'حذف',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${line.unitPrice.toStringAsFixed(2)} ج.م / ${line.unitName}',
            style: const TextStyle(fontSize: 11, color: _C.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyBtn(
                icon: Icons.remove,
                onTap: () => onQuantityChanged(line.quantity - 1),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
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
                      fontSize: 15, fontWeight: FontWeight.w800),
                  onChanged: (v) {
                    final n = double.tryParse(v) ?? 0;
                    if (n > 0) onQuantityChanged(n);
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _QtyBtn(
                icon: Icons.add,
                onTap: () => onQuantityChanged(line.quantity + 1),
              ),
              const Spacer(),
              Text(
                '${line.lineTotal.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _C.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtQty(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _C.surfaceGray,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _C.border),
        ),
        child: Icon(icon, size: 16, color: _C.text),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const danger = Color(0xFFC62828);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
