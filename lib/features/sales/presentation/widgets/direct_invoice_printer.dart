import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';

import '../../domain/sales_models.dart';
import 'bluetooth_printer_service.dart';

class DirectInvoicePrinter {
  static const _C_primary = Color(0xFF00897B);
  static const _C_danger = Color(0xFFC62828);
  static const _C_success = Color(0xFF2E7D32);

  /// الدالة الرئيسية للطباعة المباشرة
  static Future<void> print({
    required BuildContext context,
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    // 1. تحقق من وجود طابعة محفوظة
    final savedAddress = await BluetoothPrinterService.getSavedPrinterAddress();

    // 2. إذا لم تكن هناك طابعة، اعرض قائمة الاختيار
    if (savedAddress == null) {
      final selected = await showModalBottomSheet<BluetoothDevice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _PrinterSelectSheet(),
      );
      if (selected == null || selected.address == null) return;
    }

    // 3. أعرض مؤشر تحميل
    if (!context.mounted) return;
    _showLoading(context);

    try {
      final address = await BluetoothPrinterService.getSavedPrinterAddress();
      if (address == null) throw 'لم يتم اختيار طابعة';

      // 4. الاتصال بالطابعة
      final connected = await BluetoothPrinterService.connect(address);
      if (!connected) {
        throw 'تعذر الاتصال بالطابعة. تأكد من تشغيلها وتفعيل البلوتوث.';
      }

      // 5. بناء أوامر ESC/POS
      final bytes = await _buildEscPosBytes(
        sale: sale,
        companyName: companyName,
        branchName: branchName,
        companyPhone: companyPhone,
      );

      // 6. إرسال للطباعة
      final sent = await BluetoothPrinterService.writeBytes(bytes);
      if (!sent) throw 'فشل إرسال البيانات للطابعة';

      // 7. قطع الاتصال (اختياري)
      await BluetoothPrinterService.disconnect();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // أغلق مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال الفاتورة للطابعة'),
          backgroundColor: _C_success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشلت الطباعة: $e'),
          backgroundColor: _C_danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _C_primary),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   بناء أوامر ESC/POS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<int>> _buildEscPosBytes({
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    // ⚠️ محاولة ضبط كود الصفحة العربية (cp864)
    try {
      bytes += generator.setGlobalCodeTable(CodePage.cp864);
    } catch (_) {
      // بعض الطابعات لا تدعم — تجاهل
    }

    // ─── 1. الرأس ──────────────────────────────────────────────────────────
    bytes += generator.text(
      companyName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        fontType: PosFontType.fontB,
      ),
    );
    bytes += generator.text(
      branchName,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        fontType: PosFontType.fontB,
      ),
    );
    if (companyPhone.isNotEmpty) {
      bytes += generator.text(
        companyPhone,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          fontType: PosFontType.fontB,
        ),
      );
    }
    bytes += generator.feed(1);

    // ─── 2. العنوان ────────────────────────────────────────────────────────
    bytes += generator.text(
      'فاتورة مبيعات',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        fontType: PosFontType.fontB,
      ),
    );
    bytes += generator.feed(1);
    bytes += generator.hr();

    // ─── 3. بيانات الفاتورة ────────────────────────────────────────────────
    bytes += generator.text(
      'رقم الفاتورة: ${sale.invoiceNumber}',
      styles: const PosStyles(
        align: PosAlign.right,
        fontType: PosFontType.fontB,
      ),
    );
    final dateStr =
        '${sale.saleDate.year}/${sale.saleDate.month.toString().padLeft(2, '0')}/${sale.saleDate.day.toString().padLeft(2, '0')}';
    bytes += generator.text(
      'التاريخ: $dateStr',
      styles: const PosStyles(
        align: PosAlign.right,
        fontType: PosFontType.fontB,
      ),
    );
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      bytes += generator.text(
        'العميل: ${sale.customerName}',
        styles: const PosStyles(
          align: PosAlign.right,
          fontType: PosFontType.fontB,
        ),
      );
    }
    bytes += generator.hr();

    // ─── 4. جدول المنتجات ─────────────────────────────────────────────────
    // رأس الجدول
    bytes += generator.row([
      PosColumn(
        text: 'الإجمالي',
        width: 3,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          fontType: PosFontType.fontB,
        ),
      ),
      PosColumn(
        text: 'السعر',
        width: 2,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          fontType: PosFontType.fontB,
        ),
      ),
      PosColumn(
        text: 'الكمية',
        width: 2,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          fontType: PosFontType.fontB,
        ),
      ),
      PosColumn(
        text: 'الصنف',
        width: 5,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          fontType: PosFontType.fontB,
        ),
      ),
    ]);
    bytes += generator.hr(ch: '─', len: 48);

    // بنود الفاتورة
    for (final line in sale.items) {
      bytes += generator.row([
        PosColumn(
          text: line.lineTotal.toStringAsFixed(2),
          width: 3,
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        ),
        PosColumn(
          text: line.unitPrice.toStringAsFixed(2),
          width: 2,
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        ),
        PosColumn(
          text: _fmtQty(line.quantity),
          width: 2,
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        ),
        PosColumn(
          text: line.productName,
          width: 5,
          styles: const PosStyles(
            align: PosAlign.right,
            fontType: PosFontType.fontB,
          ),
        ),
      ]);
    }
    bytes += generator.hr(ch: '─', len: 48);

    // ─── 5. الإجماليات ────────────────────────────────────────────────────
    bytes += _totalRow(
      generator,
      label: 'إجمالي الفاتورة',
      value: sale.total.toStringAsFixed(2),
    );
    bytes += _totalRow(
      generator,
      label: 'المدفوع',
      value: sale.paidAmount.toStringAsFixed(2),
    );
    final remaining = sale.total - sale.paidAmount;
    if (remaining.abs() > 0.001) {
      bytes += _totalRow(
        generator,
        label: 'المتبقي',
        value: remaining.toStringAsFixed(2),
        bold: true,
      );
    }

    // ─── 6. التذييل ────────────────────────────────────────────────────────
    bytes += generator.feed(1);
    bytes += generator.hr();
    bytes += generator.text(
      'شكراً لتعاملكم معنا',
      styles: const PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontB,
      ),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  static List<int> _totalRow(
    Generator generator, {
    required String label,
    required String value,
    bool bold = false,
  }) {
    return generator.row([
      PosColumn(
        text: value,
        width: 4,
        styles: PosStyles(
          align: PosAlign.left,
          bold: bold,
          fontType: PosFontType.fontB,
        ),
      ),
      PosColumn(
        text: label,
        width: 8,
        styles: PosStyles(
          align: PosAlign.right,
          bold: bold,
          fontType: PosFontType.fontB,
        ),
      ),
    ]);
  }

  static String _fmtQty(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   نافذة اختيار الطابعة
// ═══════════════════════════════════════════════════════════════════════════

class _PrinterSelectSheet extends StatefulWidget {
  const _PrinterSelectSheet();

  @override
  State<_PrinterSelectSheet> createState() => _PrinterSelectSheetState();
}

class _PrinterSelectSheetState extends State<_PrinterSelectSheet> {
  bool _loading = true;
  String? _error;
  List<BluetoothDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await BluetoothPrinterService.getPairedDevices();
      if (!mounted) return;
      setState(() {
        _devices = list;
        _loading = false;
      });
      if (list.isEmpty) {
        setState(() {
          _error =
              'لا توجد طابعات مقترنة. اذهب لإعدادات البلوتوث واقترن بالطابعة أولاً.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

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
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.print, color: Color(0xFF00897B)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'اختر الطابعة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF00897B)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 40, color: Color(0xFFC62828)),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF757575)),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFE0E0E0)),
                  itemBuilder: (_, i) {
                    final d = _devices[i];
                    return ListTile(
                      leading: const Icon(Icons.print_outlined,
                          color: Color(0xFF00897B)),
                      title: Text(
                        d.name ?? 'طابعة غير معروفة',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(d.address ?? ''),
                      onTap: () async {
                        await BluetoothPrinterService.savePrinter(
                          address: d.address!,
                          name: d.name ?? '',
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context, d);
                      },
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
