import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/sales_models.dart';
import 'direct_invoice_printer.dart';
import 'invoice_pdf_builder.dart';

class InvoicePrinter {
  static const _C_primary = Color(0xFF00897B);
  static const _C_danger = Color(0xFFC62828);

  /// الطباعة — توجّه تلقائياً حسب المنصة
  static Future<void> print({
    required BuildContext context,
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    // Android → طباعة مباشرة عبر البلوتوث
    if (!kIsWeb && Platform.isAndroid) {
      return DirectInvoicePrinter.print(
        context: context,
        sale: sale,
        companyName: companyName,
        branchName: branchName,
        companyPhone: companyPhone,
      );
    }

    // Web / iOS → معاينة PDF (للاختبار)
    return _printViaPdf(
      context: context,
      sale: sale,
      companyName: companyName,
      branchName: branchName,
      companyPhone: companyPhone,
    );
  }

  /// مشاركة الفاتورة (PDF) — يعمل على جميع المنصات
  static Future<void> share({
    required BuildContext context,
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    return _shareViaPdf(
      context: context,
      sale: sale,
      companyName: companyName,
      branchName: branchName,
      companyPhone: companyPhone,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   PDF Fallback (Web + iOS)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> _printViaPdf({
    required BuildContext context,
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    _showLoading(context);
    try {
      final bytes = await PdfInvoiceBuilder.build(
        sale: sale,
        companyName: companyName,
        branchName: branchName,
        companyPhone: companyPhone,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: 'Invoice_${sale.invoiceNumber}',
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _snack(context, 'تعذر الطباعة: $e');
    }
  }

  static Future<void> _shareViaPdf({
    required BuildContext context,
    required SaleDetail sale,
    required String companyName,
    required String branchName,
    required String companyPhone,
  }) async {
    _showLoading(context);
    try {
      final bytes = await PdfInvoiceBuilder.build(
        sale: sale,
        companyName: companyName,
        branchName: branchName,
        companyPhone: companyPhone,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'فاتورة_${sale.invoiceNumber}.pdf',
        subject: 'فاتورة رقم ${sale.invoiceNumber}',
        body: 'مرحباً، هذه فاتورتكم من $companyName',
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _snack(context, 'تعذر المشاركة: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //   Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _C_primary),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _C_danger,
      ),
    );
  }

  /// إعادة تعيين الطابعة المحفوظة (للاستخدام من الإعدادات)
  static Future<void> resetSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printer_address');
    await prefs.remove('printer_name');
  }
}
