import 'package:flutter/material.dart';

class PosSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onScannerTap;
  final VoidCallback? onClear;

  const PosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onScannerTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: _C.text),
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم أو الكود أو امسح الباركود',
          hintStyle: const TextStyle(
              fontSize: 13, color: _C.textSecondary),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search,
              color: _C.primary, size: 22),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: onClear,
                  color: _C.textSecondary,
                  tooltip: 'مسح',
                ),
              if (onScannerTap != null)
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  onPressed: onScannerTap,
                  color: _C.primary,
                  tooltip: 'مسح باركود',
                ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.primary, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.primary, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
