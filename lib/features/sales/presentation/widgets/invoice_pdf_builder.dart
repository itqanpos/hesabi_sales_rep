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

    const pageFormat = PdfPageFormat.a4;
    const padding = 28.0;

    final document = pw.Document(
      theme: theme,
      title: 'فاتورة ${sale.invoiceNumber ?? ''}',
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
              pw.SizedBox(height: 16),
              _buildMetaBlock(sale),
              pw.SizedBox(height: 16),
              _buildDivider(double: true),
              pw.SizedBox(height: 10),
              _buildItemsTable(sale),
              pw.SizedBox(height: 16),
              _buildTotalsSection(sale),
              pw.SizedBox(height: 24),
              _buildDivider(),
              pw.SizedBox(height: 10),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );

    return document.save();
  }

  static pw.Widget _buildHeader({
    required String title,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) {
    return pw.Column(
      children: [
        pw.Text(companyName,
            style:
                pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(branchName, style: const pw.TextStyle(fontSize: 12)),
        if (companyPhone.isNotEmpty)
          pw.Text(companyPhone, style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaBlock(SaleDetail sale) {
    final dateFormat = DateFormat('EEEE، yyyy/MM/dd — hh:mm a', 'ar');
    final formattedDate = dateFormat.format(sale.saleDate);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _metaRow('رقم الفاتورة', sale.invoiceNumber, emphasized: true),
        _metaRow('التاريخ', formattedDate),
        if (sale.customerName.isNotEmpty)
          _metaRow('العميل', sale.customerName),
      ],
    );
  }

  /// ⬇️ يقبل `String?` ويعالج الـ null داخلياً
  static pw.Widget _metaRow(String label, String? value,
      {bool emphasized = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value ?? '—',
              style: pw.TextStyle(
                fontSize: 10,
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

  static pw.Widget _buildItemsTable(SaleDetail sale) {
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.4),
      1: const pw.FlexColumnWidth(1.2),
      2: const pw.FlexColumnWidth(1.3),
      3: const pw.FlexColumnWidth(2.5),
      4: const pw.FixedColumnWidth(24),
    };

    double totalQuantity = 0;
    for (final line in sale.items) {
      totalQuantity += line.quantity;
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('الإجمالي', bold: true),
          _cell('السعر', bold: true, center: true),
          _cell('الكمية', bold: true, center: true),
          _cell('الصنف', bold: true),
          _cell('م', bold: true, center: true),
        ],
      ),
    ];

    for (int i = 0; i < sale.items.length; i++) {
      final line = sale.items[i];
      rows.add(pw.TableRow(
        children: [
          _cell(_money(line.lineTotal), bold: true, center: true),
          _cell(_money(line.unitPrice), center: true),
          _cell('${_formatQty(line.quantity)} ${line.unitName}',
              center: true),
          _cell(line.productName),
          _cell('${i + 1}', center: true),
        ],
      ));
    }

    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        _cell(_money(sale.total), bold: true, center: true),
        _cell(''),
        _cell(_formatQty(totalQuantity), center: true),
        _cell('المجموع الفرعي', bold: true),
        _cell(''),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static pw.Widget _cell(String text,
      {bool bold = false, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
      ),
    );
  }

  static pw.Widget _buildTotalsSection(SaleDetail sale) {
    final remaining = sale.total - sale.paidAmount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _pdfRow('إجمالي الفاتورة', _money(sale.total)),
          _pdfDivider(),
          _pdfRow('المطلوب', _money(sale.total), bold: true),
          _pdfDivider(),
          _pdfRow('المدفوع', _money(sale.paidAmount), bold: true),
          _pdfDivider(),
          _pdfRow('الرصيد المتبقي', _money(remaining), bold: true),
        ],
      ),
    );
  }

  static pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: bold ? 12 : 10,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 12 : 10,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Container(height: 0.5, color: PdfColors.grey600),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'شكراً لتعاملكم معنا',
        style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildDivider({bool double = false}) {
    if (double) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(height: 0.6, color: PdfColors.grey600),
          pw.SizedBox(height: 2),
          pw.Container(height: 0.6, color: PdfColors.grey600),
        ],
      );
    }
    return pw.Container(height: 0.6, color: PdfColors.grey600);
  }

  static String _money(double value) =>
      NumberFormat('#,##0.00', 'en').format(value);

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
