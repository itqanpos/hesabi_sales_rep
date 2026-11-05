import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PosScannerPage extends StatelessWidget {
  const PosScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح الباركود')),
      body: MobileScanner(
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          for (final b in barcodes) {
            if (b.rawValue != null) {
              Navigator.pop(context, b.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}
