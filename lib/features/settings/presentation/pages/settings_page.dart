import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

import '../../../sales/presentation/widgets/bluetooth_printer_service.dart';
import '../../../sales/presentation/widgets/direct_invoice_printer.dart';

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const surface = Colors.white;
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _printerName;
  String? _printerAddress;
  
  double _fontSize = 1.0; // 1.0, 2.0, 3.0
  bool _fontBold = false;
  
  bool _loadingPrinter = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final name = await BluetoothPrinterService.getSavedPrinterName();
    final address = await BluetoothPrinterService.getSavedPrinterAddress();
    final size = await BluetoothPrinterService.getFontSize();
    final bold = await BluetoothPrinterService.getFontBold();

    if (mounted) {
      setState(() {
        _printerName = name;
        _printerAddress = address;
        _fontSize = size;
        _fontBold = bold;
      });
    }
  }

  Future<void> _selectPrinter() async {
    setState(() => _loadingPrinter = true);
    final printers = await BluetoothPrinterService.discoverPrinters();
    
    if (!mounted) return;
    setState(() => _loadingPrinter = false);

    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد طابعات مقترنة. اذهب لإعدادات البلوتوث أولاً.'), backgroundColor: _C.danger),
      );
      return;
    }

    final selected = await showModalBottomSheet<PrinterDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrinterSelectSheet(printers: printers),
    );

    if (selected != null && selected.address != null) {
      await BluetoothPrinterService.savePrinter(
        address: selected.address!,
        name: selected.name ?? 'طابعة',
      );
      _loadSettings();
    }
  }

  Future<void> _saveFontSize(double val) async {
    setState(() => _fontSize = val);
    await BluetoothPrinterService.saveFontSize(val);
  }

  Future<void> _saveFontBold(bool val) async {
    setState(() => _fontBold = val);
    await BluetoothPrinterService.saveFontBold(val);
  }

  Future<void> _testPrint() async {
    if (_printerAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ربط الطابعة أولاً'), backgroundColor: _C.danger),
      );
      return;
    }
    await DirectInvoicePrinter.printTest(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.text),
        title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.bold, color: _C.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('الطابعة'),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.print, color: _C.primary),
                  title: const Text('الطابعة المتصلة'),
                  subtitle: Text(_printerName ?? 'لم يتم ربط طابعة'),
                  trailing: TextButton(
                    onPressed: _selectPrinter,
                    child: _loadingPrinter 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('تغيير'),
                  ),
                ),
                const Divider(height: 1, color: _C.border),
                ListTile(
                  leading: const Icon(Icons.receipt, color: _C.success),
                  title: const Text('طباعة فاتورة تجريبية'),
                  subtitle: const Text('للتأكد من جودة الطباعة والإعدادات'),
                  onTap: _testPrint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('تنسيق الطباعة (حجم الخط)'),
          _buildCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('صغير', style: TextStyle(fontSize: 12, color: _C.textSecondary)),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 1.0,
                        max: 3.0,
                        divisions: 2,
                        activeColor: _C.primary,
                        label: _fontSize == 1.0 ? 'صغير' : (_fontSize == 2.0 ? 'متوسط' : 'كبير'),
                        onChanged: (val) => _saveFontSize(val),
                      ),
                    ),
                    const Text('كبير', style: TextStyle(fontSize: 12, color: _C.textSecondary)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('خط عريض (Bold)'),
                      Switch(
                        value: _fontBold,
                        activeColor: _C.primary,
                        onChanged: _saveFontBold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Hesabi Sales Rep - v0.1.0',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 8, left: 8),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _C.textSecondary)),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }
}

// نافذة اختيار الطابعة
class _PrinterSelectSheet extends StatelessWidget {
  final List<PrinterDevice> printers;
  const _PrinterSelectSheet({required this.printers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 42, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر الطابعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: printers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = printers[i];
                  return ListTile(
                    leading: const Icon(Icons.print, color: _C.primary),
                    title: Text(d.name ?? 'طابعة غير معروفة'),
                    subtitle: Text(d.address ?? ''),
                    onTap: () => Navigator.pop(context, d),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
