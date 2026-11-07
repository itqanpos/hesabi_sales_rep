import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PosBarcodeScannerPage extends StatefulWidget {
  const PosBarcodeScannerPage({super.key});

  @override
  State<PosBarcodeScannerPage> createState() =>
      _PosBarcodeScannerPageState();
}

class _PosBarcodeScannerPageState
    extends State<PosBarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasResult) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _hasResult = true;
      Navigator.of(context).pop(raw.trim());
      return;
    }
  }

  Future<void> _manualEntry() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدخال باركود يدوياً'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'الباركود',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.qr_code),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('مسح الباركود'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: () => _controller.toggleTorch(),
                tooltip: 'الفلاش',
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // إطار المسح
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
              ),
              child: Center(
                child: Container(
                  width: 260,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
          ),
          // نص تلميحي
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'وجّه الكاميرا نحو الباركود',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          // زر الإدخال اليدوي
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: TextButton.icon(
                onPressed: _manualEntry,
                icon: const Icon(Icons.keyboard,
                    color: Colors.white),
                label: const Text('إدخال يدوي',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
