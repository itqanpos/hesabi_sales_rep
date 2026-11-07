import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../sales/data/invoice_settings_repository.dart';
import '../../domain/customer_models.dart';

class StatementPdfBuilder {
  static Future<Uint8List> build({
    required String customerName,
    required String? customerPhone,
    required double currentBalance,
    required List<StatementEntry> entries,
    required String companyName,
    required String branchName,
    required String companyPhone,
    required InvoiceSettings settings,
  }) async {
    final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final fontBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // Logo
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

    // Dynamic height
    final lineCount = entries.length;
    final baseMm = 170.0 + (lineCount * 15.0);
    final pageFormat = PdfPageFormat(
      settings.paperWidthMm * PdfPageFormat.mm,
      baseMm * PdfPageFormat.mm,
    );

    final document = pw.Document(
      theme: theme,
      title: 'كشف حساب $customerName',
      author: companyName,
    );

    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(6),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) => pw.Container(
          color: PdfColors.white,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                title: 'كشف حساب عميل',
                companyName: companyName,
                branchName: branchName,
                companyPhone: companyPhone,
                logo: companyLogo,
                settings: settings,
              ),
              pw.SizedBox(height: 6),
              _divider(),
              pw.SizedBox(height: 6),
              _buildCustomerInfo(
                  customerName, customerPhone, settings),
              pw.SizedBox(height: 6),
              _divider(),
              pw.SizedBox(height: 6),
              _buildEntriesTable(entries, settings),
              pw.SizedBox(height: 10),
              _buildBalanceSummary(currentBalance, settings),
              pw.SizedBox(height: 12),
              _buildFooter(settings),
            ],
          ),
        ),
      ),
    );

    return document.save();
  }

  static pw.TextStyle _style({
    required double baseSize,
    required InvoiceSettings settings,
    bool forceBold = false,
  }) {
    final size = baseSize * (baseSize > 10 ? settings.fontScale : 1.0);
    return pw.TextStyle(
      fontSize: size,
      fontWeight: (forceBold || settings.isBold)
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
      color: PdfColors.black,
    );
  }

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
        pw.Text(companyName,
            style: _style(baseSize: 12, settings: settings, forceBold: true),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text(branchName,
            style: _style(baseSize: 8, settings: settings),
            textAlign: pw.TextAlign.center),
        if (companyPhone.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(companyPhone,
              style: _style(baseSize: 8, settings: settings),
              textAlign: pw.TextAlign.center),
        ],
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(title,
                style: _style(
                    baseSize: 10, settings: settings, forceBold: true)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(
      String name, String? phone, InvoiceSettings settings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text('العميل:',
                style: _style(
                    baseSize: 8, settings: settings, forceBold: true),
                textAlign: pw.TextAlign.right),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(name,
                style: _style(baseSize: 8, settings: settings)),
          ),
        ]),
        if (phone != null && phone.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.SizedBox(
              width: 60,
              child: pw.Text('الهاتف:',
                  style: _style(
                      baseSize: 8, settings: settings, forceBold: true),
                  textAlign: pw.TextAlign.right),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Text(phone,
                  style: _style(baseSize: 8, settings: settings)),
            ),
          ]),
        ],
      ],
    );
  }

  static pw.Widget _buildEntriesTable(
      List<StatementEntry> entries, InvoiceSettings settings) {
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.5), // التاريخ
      1: const pw.FlexColumnWidth(4.0), // البيان
      2: const pw.FlexColumnWidth(2.0), // مدين (فاتورة)
      3: const pw.FlexColumnWidth(2.0), // دائن (دفعة)
    };

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('التاريخ', settings: settings, bold: true, center: true),
          _cell('البيان', settings: settings, bold: true, right: true),
          _cell('مدين', settings: settings, bold: true, center: true),
          _cell('دائن', settings: settings, bold: true, center: true),
        ],
      ),
    ];

    for (final entry in entries) {
      final dateStr = DateFormat('yyyy/MM/dd', 'en').format(entry.date);
      final isSale = entry.isSale;
      final desc = isSale ? 'فاتورة #${entry.refNumber ?? ''}' : 'دفعة ${entry.methodLabel}';

      rows.add(pw.TableRow(
        children: [
          _cell(dateStr, settings: settings, center: true),
          _cell(desc, settings: settings, right: true),
          _cell(isSale ? _money(entry.amount, settings) : '', settings: settings, center: true),
          _cell(!isSale ? _money(entry.amount, settings) : '', settings: settings, center: true),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.4),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static pw.Widget _buildBalanceSummary(double balance, InvoiceSettings settings) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('الرصيد الحالي المستحق:',
              style: _style(baseSize: 10, settings: settings, forceBold: true)),
          pw.Text(_money(balance.abs(), settings),
              style: _style(baseSize: 10, settings: settings, forceBold: true)),
        ],
      ),
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
        maxLines: 2,
      ),
    );
  }

  static pw.Widget _divider() =>
      pw.Container(height: 0.5, color: PdfColors.grey600);

  static pw.Widget _buildFooter(InvoiceSettings settings) {
    return pw.Center(
      child: pw.Text(
        settings.receiptFooter,
        style: _style(baseSize: 8, settings: settings, forceBold: true),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static String _money(double value, InvoiceSettings settings) {
    final formatted = NumberFormat('#,##0.00', 'en').format(value);
    return settings.showCurrencySymbol ? '$formatted ج.م' : formatted;
  }
}
