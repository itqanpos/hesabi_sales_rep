import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/sales_models.dart';

class PdfInvoiceBuilder {
  static Future<Uint8List> build({
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final fontBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    // ⬇️⬇️⬇️ التغيير الأساسي: 80mm بدل A4
    // ارتفاع ديناميكي بناءً على عدد المنتجات
    final lineCount = sale.items.length;
    final baseMm = 160.0 + (lineCount * 12.0);
    final pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      baseMm * PdfPageFormat.mm,
    );
    const padding = 4.0;

    final document = pw.Document(
      theme: theme,
      title: 'Invoice ${sale.invoiceNumber ?? ''}',
      author: companyName,
    );

    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(padding),
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
              ),
              pw.SizedBox(height: 6),
              _buildMetaBlock(sale),
              pw.SizedBox(height: 6),
              _divider(),
              pw.SizedBox(height: 4),
              _buildItemsTable(sale),
              pw.SizedBox(height: 6),
              _buildTotalsSection(sale),
              pw.SizedBox(height: 10),
              _divider(),
              pw.SizedBox(height: 4),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );

    return document.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   الرأس (مختصر — إيصال ضيق)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader({
    required String title,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          companyName,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          branchName,
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
        if (companyPhone.isNotEmpty)
          pw.Text(
            companyPhone,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   بيانات الفاتورة (رقم، تاريخ، عميل)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildMetaBlock(SaleDetail sale) {
    // اسم اليوم بالعربي + أرقام إنجليزية (بدون مربعات)
    final dayName = DateFormat('EEEE', 'ar').format(sale.saleDate);
    final datePart = DateFormat('yyyy/MM/dd', 'en').format(sale.saleDate);
    final hour = sale.saleDate.hour;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minute = sale.saleDate.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'م' : 'ص';
    final timePart = '${hour12.toString().padLeft(2, '0')}:$minute $ampm';
    final formattedDate = '$dayName $datePart - $timePart';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _metaRow('رقم الفاتورة', sale.invoiceNumber, emphasized: true),
        _metaRow('التاريخ', formattedDate),
        if (sale.customerName.isNotEmpty)
          _metaRow('العميل', sale.customerName),
        if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
          _metaRow('هاتف العميل', sale.customerPhone!),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String? value,
      {bool emphasized = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 50,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                  fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(width: 2),
          pw.Expanded(
            child: pw.Text(
              value ?? '-',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: emphasized
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   جدول المنتجات (5 أعمدة — عرض 80mm)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildItemsTable(SaleDetail sale) {
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(14),   // م
      1: const pw.FlexColumnWidth(3),     // الصنف
      2: const pw.FixedColumnWidth(30),   // الكمية
      3: const pw.FixedColumnWidth(32),   // السعر
      4: const pw.FixedColumnWidth(40),   // الإجمالي
    };

    double totalQuantity = 0;
    for (final line in sale.items) {
      totalQuantity += line.quantity;
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('م', bold: true, center: true),
          _cell('الصنف', bold: true, right: true),
          _cell('الكمية', bold: true, center: true),
          _cell('السعر', bold: true, center: true),
          _cell('الإجمالي', bold: true, center: true),
        ],
      ),
    ];

    for (int i = 0; i < sale.items.length; i++) {
      final line = sale.items[i];
      rows.add(pw.TableRow(
        children: [
          _cell('${i + 1}', center: true),
          _cell(line.productName, right: true),
          _cell('${_formatQty(line.quantity)}\n${line.unitName}',
              center: true),
          _cell(_money(line.unitPrice), center: true),
          _cell(_money(line.lineTotal), center: true, bold: true),
        ],
      ));
    }

    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        _cell('', center: true),
        _cell('المجموع الفرعي', bold: true, right: true),
        _cell(_formatQty(totalQuantity), center: true, bold: true),
        _cell('', center: true),
        _cell(_money(sale.total), center: true, bold: true),
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
    bool bold = false,
    bool center = false,
    bool right = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: center
            ? pw.TextAlign.center
            : (right ? pw.TextAlign.right : pw.TextAlign.left),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   الإجماليات (في مربع — زي صورة Hesabi)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildTotalsSection(SaleDetail sale) {
    final remaining = sale.total - sale.paidAmount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _row('إجمالي الفاتورة', _money(sale.total), bold: false),
          _miniDivider(),
          _row('المطلوب', _money(sale.total), bold: true),
          _miniDivider(),
          _row('المدفوع', _money(sale.paidAmount), bold: true),
          if (remaining.abs() > 0.001) ...[
            _miniDivider(),
            _row('المتبقي', _money(remaining), bold: true),
          ],
        ],
      ),
    );
  }

  static pw.Widget _row(String label, String value, {bool bold = false}) {
    final fontSize = bold ? 9.0 : 7.5;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniDivider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Container(height: 0.3, color: PdfColors.grey500),
      );

  static pw.Widget _divider() =>
      pw.Container(height: 0.5, color: PdfColors.grey600);

  // ═══════════════════════════════════════════════════════════════════════════
  //   التذييل (بدون italic + بدون تنوين = بدون مربعات)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'شكرا لتعاملكم معنا',
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   Helpers
  // ═══════════════════════════════════════════════════════════════════════════
  static String _money(double value) =>
      NumberFormat('#,##0.00', 'en').format(value);

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
