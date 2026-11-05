import 'package:flutter/material.dart';

class PosSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onScan;
  final VoidCallback onClear;

  const PosSearchField({super.key, required this.controller, required this.focusNode, required this.onScan, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم أو الكود أو امسح الباركود',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: onScan),
              if (controller.text.isNotEmpty) IconButton(icon: const Icon(Icons.close), onPressed: onClear),
            ],
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: EdgeInsets.zero,
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
