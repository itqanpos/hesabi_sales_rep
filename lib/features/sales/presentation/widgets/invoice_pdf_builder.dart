import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/invoice_settings_repository.dart';
import '../../domain/sales_models.dart';

class PdfInvoiceBuilder {
  static Future<Uint8List> build({
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
    required InvoiceSettings settings,
    String? repName,
  }) async {
    final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final fontBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // 1. تحميل اللوجو
    pw.Image? companyLogo;
    if (settings.logoUrl != null && settings.logoUrl!.trim().isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(settings.logoUrl!));
        if (response.statusCode == 200) {
          companyLogo = pw.Image(
            pw.MemoryImage(response.bodyBytes),
            height: 40,
            fit: pw.BoxFit.contain,
          );
        }
      } catch (_) {}
    }

    // 2. حساب الارتفاع بشكل مرن (لضمان عدم قطع النص من الأعلى)
    final lineCount = sale.items.length;
    final baseMm = 170.0 + (lineCount * 15.0);
    final pageFormat = PdfPageFormat(
      settings.paperWidthMm * PdfPageFormat.mm,
      baseMm * PdfPageFormat.mm,
    );

    final document = pw.Document(
      theme: theme,
      title: 'Invoice ${sale.invoiceNumber ?? ''}',
      author: companyName,
    );

    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(6), // هوامش مناسبة للإيصالات
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) => pw.Container(
          color: PdfColors.white,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                title: 'فاتورة مبيعات',
                companyName: companyName,
                branchName: branchName,
                companyPhone: companyPhone,
                logo: companyLogo,
                settings: settings,
              ),
              pw.SizedBox(height: 6),
              _divider(),
              pw.SizedBox(height: 6),
              _buildMetaBlock(sale, repName: repName, settings: settings),
              pw.SizedBox(height: 6),
              _divider(),
              pw.SizedBox(height: 6),
              _buildItemsTable(sale, settings),
              pw.SizedBox(height: 8),
              _buildTotalsSection(sale, settings),
              if (settings.showQrOnPrint) ...[
                pw.SizedBox(height: 8),
                _buildQrCode(sale),
              ],
              pw.SizedBox(height: 12),
              _buildFooter(settings),
            ],
          ),
        ),
      ),
    );

    return document.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   التنسيق الأساسي (مع تثبيت حجم الخط للجداول لمنع التشوه)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.TextStyle _style({
    required double baseSize,
    required InvoiceSettings settings,
    bool forceBold = false,
  }) {
    // لا نطبق fontScale على الجداول حتى لا تتشوه، نطبقه فقط على العناوين الكبيرة
    final size = baseSize * (baseSize > 10 ? settings.fontScale : 1.0);
    return pw.TextStyle(
      fontSize: size,
      fontWeight: (forceBold || settings.isBold)
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
      color: PdfColors.black,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   Header
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader({
    required String title,
    required String companyName,
    required String branchName,
    required String companyPhone,
    required pw.Image? logo,
    required InvoiceSettings settings,
  }) {
    return pw.Column(
      children: [
        if (logo != null) ...[
          pw.Center(child: logo),
          pw.SizedBox(height: 4),
        ],
        pw.Text(
          companyName,
          style: _style(baseSize: 12, settings: settings, forceBold: true),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          branchName,
          style: _style(baseSize: 8, settings: settings),
          textAlign: pw.TextAlign.center,
        ),
        if (companyPhone.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            companyPhone,
            style: _style(baseSize: 8, settings: settings),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              title,
              style: _style(baseSize: 10, settings: settings, forceBold: true),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   Meta Block (تنسيق أفضل للبيانات)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildMetaBlock(
    SaleDetail sale, {
    String? repName,
    required InvoiceSettings settings,
  }) {
    final dayName = DateFormat('EEEE', 'ar').format(sale.saleDate);
    final datePart = DateFormat('yyyy/MM/dd', 'en').format(sale.saleDate);
    final hour = sale.saleDate.hour;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minute = sale.saleDate.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'م' : 'ص';
    final formattedDate = '$dayName $datePart - ${hour12.toString().padLeft(2, '0')}:$minute $ampm';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _metaRow('رقم الفاتورة', sale.invoiceNumber ?? '-', settings: settings),
        _metaRow('التاريخ', formattedDate, settings: settings),
        if (repName != null && repName.trim().isNotEmpty)
          _metaRow('المندوب', repName, settings: settings),
        if (sale.customerName.isNotEmpty)
          _metaRow('العميل', sale.customerName, settings: settings),
        if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
          _metaRow('هاتف العميل', sale.customerPhone!, settings: settings),
      ],
    );
  }

  static pw.Widget _metaRow(
    String label,
    String value, {
    required InvoiceSettings settings,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 60, // عرض ثابت للعنوان
            child: pw.Text(
              '$label:',
              style: _style(baseSize: 8, settings: settings, forceBold: true),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value,
              style: _style(baseSize: 8, settings: settings),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   Items Table (عرض أعمدة متناسب مع 80mm)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildItemsTable(
    SaleDetail sale,
    InvoiceSettings settings,
  ) {
    // نسب العرض لضمان عدم التشوه
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.5), // م
      1: const pw.FlexColumnWidth(2.5), // الإجمالي
      2: const pw.FlexColumnWidth(1.5), // السعر
      3: const pw.FlexColumnWidth(1.5), // الكمية
      4: const pw.FlexColumnWidth(4.0), // الصنف
    };

    double totalQuantity = 0;
    for (final line in sale.items) {
      totalQuantity += line.quantity;
    }

    final rows = <pw.TableRow>[
      // Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('م', settings: settings, bold: true, center: true),
          _cell('الإجمالي', settings: settings, bold: true, center: true),
          _cell('السعر', settings: settings, bold: true, center: true),
          _cell('الكمية', settings: settings, bold: true, center: true),
          _cell('الصنف', settings: settings, bold: true, right: true),
        ],
      ),
    ];

    // Data
    for (int i = 0; i < sale.items.length; i++) {
      final line = sale.items[i];
      rows.add(pw.TableRow(
        children: [
          _cell('${i + 1}', settings: settings, center: true),
          _cell(_money(line.lineTotal, settings), settings: settings, center: true, bold: true),
          _cell(_money(line.unitPrice, settings), settings: settings, center: true),
          _cell('${_formatQty(line.quantity)}\n${line.unitName}', settings: settings, center: true),
          _cell(line.productName, settings: settings, right: true),
        ],
      ));
    }

    // Footer
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        _cell('', settings: settings),
        _cell(_money(sale.total, settings), settings: settings, center: true, bold: true),
        _cell('', settings: settings),
        _cell(_formatQty(totalQuantity), settings: settings, center: true, bold: true),
        _cell('المجموع الفرعي', settings: settings, bold: true, right: true),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.4),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static pw.Widget _cell(
    String text, {
    required InvoiceSettings settings,
    bool bold = false,
    bool center = false,
    bool right = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Text(
        text,
        style: _style(baseSize: 7, settings: settings, forceBold: bold),
        textAlign: center
            ? pw.TextAlign.center
            : (right ? pw.TextAlign.right : pw.TextAlign.left),
        maxLines: 2, // يسمح بسطرين للاسم والكمية
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   Totals
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildTotalsSection(
    SaleDetail sale,
    InvoiceSettings settings,
  ) {
    final remaining = sale.total - sale.paidAmount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _row('إجمالي الفاتورة', _money(sale.total, settings), settings: settings, bold: false),
          _miniDivider(),
          _row('المطلوب', _money(sale.total, settings), settings: settings, bold: true),
          _miniDivider(),
          _row('المدفوع', _money(sale.paidAmount, settings), settings: settings, bold: true),
          if (remaining.abs() > 0.001) ...[
            _miniDivider(),
            _row('المتبقي', _money(remaining, settings), settings: settings, bold: true),
          ],
        ],
      ),
    );
  }

  static pw.Widget _row(
    String label,
    String value, {
    required InvoiceSettings settings,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: _style(baseSize: bold ? 9 : 8, settings: settings, forceBold: bold),
          ),
          pw.Text(
            value,
            style: _style(baseSize: bold ? 9 : 8, settings: settings, forceBold: bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniDivider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Container(height: 0.3, color: PdfColors.grey500),
      );

  static pw.Widget _divider() => pw.Container(height: 0.5, color: PdfColors.grey600);

  // ═══════════════════════════════════════════════════════════════════════════
  //   QR & Footer
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildQrCode(SaleDetail sale) {
    final data = 'INV:${sale.invoiceNumber ?? ''}|TOTAL:${sale.total.toStringAsFixed(2)}';
    return pw.Center(
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: data,
        width: 55,
        height: 55,
      ),
    );
  }

  static pw.Widget _buildFooter(InvoiceSettings settings) {
    return pw.Center(
      child: pw.Text(
        settings.receiptFooter,
        style: _style(baseSize: 8, settings: settings, forceBold: true),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   Helpers
  // ═══════════════════════════════════════════════════════════════════════════
  static String _money(double value, InvoiceSettings settings) {
    final formatted = NumberFormat('#,##0.00', 'en').format(value);
    return settings.showCurrencySymbol ? '$formatted ج.م' : formatted;
  }

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
