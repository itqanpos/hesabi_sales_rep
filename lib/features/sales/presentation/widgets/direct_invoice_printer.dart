import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

import '../../domain/sales_models.dart';
import 'bluetooth_printer_service.dart';

class DirectInvoicePrinter {
  static const _C_primary = Color(0xFF00897B);
  static const _C_danger = Color(0xFFC62828);
  static const _C_success = Color(0xFF2E7D32);

  static Future<void> print({
    required BuildContext context,
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    _showLoading(context);

    try {
      final printers = await BluetoothPrinterService.discoverPrinters();

      if (printers.isEmpty) {
        throw 'لا توجد طابعات بلوتوث مقترنة. اذهب لإعدادات البلوتوث واقترن بالطابعة أولاً.';
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();

      final selected = await showModalBottomSheet<PrinterDevice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PrinterSelectSheet(printers: printers),
      );
      if (selected == null) return;

      if (!context.mounted) return;
      _showLoading(context);

      final connected = await BluetoothPrinterService.connect(selected);
      if (!connected) {
        throw 'تعذر الاتصال بالطابعة. تأكد من تشغيلها.';
      }

      final fontSize = await BluetoothPrinterService.getFontSize();
      final fontBold = await BluetoothPrinterService.getFontBold();

      final bytes = await _buildEscPosBytes(
        sale: sale,
        companyName: companyName,
        branchName: branchName,
        companyPhone: companyPhone,
        fontSize: fontSize,
        fontBold: fontBold,
      );

      final sent = await BluetoothPrinterService.writeBytes(bytes);
      if (!sent) throw 'فشل إرسال البيانات للطابعة';

      await BluetoothPrinterService.disconnect();

      if (!context.mounted) return;
      Navigator.of(context).pop();
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

  // دالة جديدة لطباعة صفحة تجريبية
  static Future<void> printTest(BuildContext context) async {
    _showLoading(context);
    try {
      final address = await BluetoothPrinterService.getSavedPrinterAddress();
      if (address == null) throw 'لم يتم العثور على طابعة محفوظة';
      
      final printers = await BluetoothPrinterService.discoverPrinters();
      final device = printers.firstWhere((d) => d.address == address, orElse: () => throw 'الطابعة المحفوظة غير متاحة');
      
      final connected = await BluetoothPrinterService.connect(device);
      if (!connected) throw 'تعذر الاتصال بالطابعة';

      final fontSize = await BluetoothPrinterService.getFontSize();
      final fontBold = await BluetoothPrinterService.getFontBold();
      
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final List<int> bytes = <int>[];

      bytes.addAll(<int>[0x1B, 0x74, 22]);
      bytes.addAll(generator.text('اختبار الطباعة', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB)));
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text('شركة حسابي', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, fontType: PosFontType.fontB)));
      bytes.addAll(generator.hr());
      
      // تطبيق حجم الخط والوزن
      final sizeEnum = fontSize == 1.0 ? PosTextSize.size1 : (fontSize == 2.0 ? PosTextSize.size2 : PosTextSize.size3);
      bytes.addAll(generator.text(
        'هذا نص تجريبي لتوضيح حجم الخط.',
        styles: PosStyles(align: PosAlign.center, bold: fontBold, height: sizeEnum, width: sizeEnum, fontType: PosFontType.fontB),
      ));
      
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text('إذا كانت القراءة واضحة، فالطباعة تعمل بنجاح.', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB)));
      bytes.addAll(generator.feed(3));
      bytes.addAll(generator.cut());

      final sent = await BluetoothPrinterService.writeBytes(bytes);
      if (!sent) throw 'فشل إرسال البيانات';

      await BluetoothPrinterService.disconnect();

      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إرسال ورقة الاختبار'), backgroundColor: _C_success),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاختبار: $e'), backgroundColor: _C_danger),
      );
    }
  }

  static void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _C_primary)),
    );
  }

  static Future<List<int>> _buildEscPosBytes({
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
    required double fontSize,
    required bool fontBold,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final List<int> bytes = <int>[];

    bytes.addAll(<int>[0x1B, 0x74, 22]);

    // حجم الخط الرئيسي للفاتورة
    final sizeEnum = fontSize == 1.0 ? PosTextSize.size1 : (fontSize == 2.0 ? PosTextSize.size2 : PosTextSize.size3);

    bytes.addAll(generator.text(
      companyName,
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        fontType: PosFontType.fontB,
      ),
    ));
    bytes.addAll(generator.text(
      branchName,
      styles: PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        fontType: PosFontType.fontB,
      ),
    ));
    if (companyPhone.isNotEmpty) {
      bytes.addAll(generator.text(
        companyPhone,
        styles: PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          fontType: PosFontType.fontB,
        ),
      ));
    }
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'فاتورة مبيعات',
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        fontType: PosFontType.fontB,
      ),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text(
      'رقم الفاتورة: ${sale.invoiceNumber ?? '—'}',
      styles: PosStyles(align: PosAlign.right, fontType: PosFontType.fontB, height: sizeEnum),
    ));
    final dateStr = '${sale.saleDate.year}/${sale.saleDate.month.toString().padLeft(2, '0')}/${sale.saleDate.day.toString().padLeft(2, '0')}';
    bytes.addAll(generator.text(
      'التاريخ: $dateStr',
      styles: PosStyles(align: PosAlign.right, fontType: PosFontType.fontB, height: sizeEnum),
    ));
    if (sale.customerName.isNotEmpty) {
      bytes.addAll(generator.text(
        'العميل: ${sale.customerName}',
        styles: PosStyles(align: PosAlign.right, fontType: PosFontType.fontB, height: sizeEnum),
      ));
    }
    bytes.addAll(generator.hr());

    // جدول المنتجات
    bytes.addAll(generator.row([
      PosColumn(text: 'الإجمالي', width: 3, styles: PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB, height: sizeEnum)),
      PosColumn(text: 'السعر', width: 2, styles: PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB, height: sizeEnum)),
      PosColumn(text: 'الكمية', width: 2, styles: PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB, height: sizeEnum)),
      PosColumn(text: 'الصنف', width: 5, styles: PosStyles(align: PosAlign.right, bold: true, fontType: PosFontType.fontB, height: sizeEnum)),
    ]));
    bytes.addAll(generator.hr(ch: '-', len: 48));

    for (final line in sale.items) {
      bytes.addAll(generator.row([
        PosColumn(text: line.lineTotal.toStringAsFixed(2), width: 3, styles: PosStyles(align: PosAlign.center, fontType: PosFontType.fontB, height: sizeEnum, bold: fontBold)),
        PosColumn(text: line.unitPrice.toStringAsFixed(2), width: 2, styles: PosStyles(align: PosAlign.center, fontType: PosFontType.fontB, height: sizeEnum, bold: fontBold)),
        PosColumn(text: _fmtQty(line.quantity), width: 2, styles: PosStyles(align: PosAlign.center, fontType: PosFontType.fontB, height: sizeEnum, bold: fontBold)),
        PosColumn(text: line.productName, width: 5, styles: PosStyles(align: PosAlign.right, fontType: PosFontType.fontB, height: sizeEnum, bold: fontBold)),
      ]));
    }
    bytes.addAll(generator.hr(ch: '-', len: 48));

    bytes.addAll(_totalRow(generator, label: 'إجمالي الفاتورة', value: sale.total.toStringAsFixed(2), fontSize: sizeEnum, fontBold: fontBold));
    bytes.addAll(_totalRow(generator, label: 'المدفوع', value: sale.paidAmount.toStringAsFixed(2), fontSize: sizeEnum, fontBold: fontBold));
    final remaining = sale.total - sale.paidAmount;
    if (remaining.abs() > 0.001) {
      bytes.addAll(_totalRow(generator, label: 'المتبقي', value: remaining.toStringAsFixed(2), fontSize: sizeEnum, fontBold: true));
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'شكراً لتعاملكم معنا',
      styles: PosStyles(align: PosAlign.center, fontType: PosFontType.fontB, height: sizeEnum),
    ));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static List<int> _totalRow(Generator generator, {required String label, required String value, required PosTextSize fontSize, required bool fontBold}) {
    return generator.row([
      PosColumn(text: value, width: 4, styles: PosStyles(align: PosAlign.left, bold: fontBold, fontType: PosFontType.fontB, height: fontSize)),
      PosColumn(text: label, width: 8, styles: PosStyles(align: PosAlign.right, bold: fontBold, fontType: PosFontType.fontB, height: fontSize)),
    ]);
  }

  static String _fmtQty(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

// ... (نافذة _PrinterSelectSheet كما هي)
class _PrinterSelectSheet extends StatefulWidget {
  final List<PrinterDevice> printers;
  const _PrinterSelectSheet({required this.printers});

  @override
  State<_PrinterSelectSheet> createState() => _PrinterSelectSheetState();
}

class _PrinterSelectSheetState extends State<_PrinterSelectSheet> {
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: widget.printers.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
                itemBuilder: (_, i) {
                  final d = widget.printers[i];
                  final displayName = d.name ?? 'طابعة غير معروفة';
                  final displayAddress = d.address ?? 'بدون عنوان';
                  return ListTile(
                    leading: const Icon(Icons.print_outlined, color: Color(0xFF00897B)),
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(displayAddress),
                    onTap: () async {
                      if (d.address == null) return;
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
