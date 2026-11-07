import 'package:supabase_flutter/supabase_flutter.dart';

/// Mirrors Hesabi's `company_settings` table for printing preferences.
class InvoiceSettings {
  final String? logoUrl;
  final String paperWidth;
  final double fontScale;
  final String fontWeight;
  final String receiptFooter;
  final bool showCurrencySymbol;
  final bool showQrOnPrint;

  const InvoiceSettings({
    this.logoUrl,
    required this.paperWidth,
    required this.fontScale,
    required this.fontWeight,
    required this.receiptFooter,
    required this.showCurrencySymbol,
    required this.showQrOnPrint,
  });

  factory InvoiceSettings.defaults() => const InvoiceSettings(
        paperWidth: '80mm',
        fontScale: 1.0,
        fontWeight: 'normal',
        receiptFooter: 'شكرا لتعاملكم معنا',
        showCurrencySymbol: false,
        showQrOnPrint: false,
      );

  factory InvoiceSettings.fromJson(Map<String, dynamic> j) {
    return InvoiceSettings(
      logoUrl: _sanitizeUrl(j['logo_url'] as String?),
      paperWidth: (j['paper_width'] as String?) ?? '80mm',
      fontScale: (j['print_font_scale'] as num?)?.toDouble() ?? 1.0,
      fontWeight: (j['print_font_weight'] as String?) ?? 'normal',
      receiptFooter: _sanitizeFooter(
        (j['receipt_footer'] as String?) ?? 'شكرا لتعاملكم معنا',
      ),
      showCurrencySymbol: (j['show_currency_symbol'] as bool?) ?? false,
      showQrOnPrint: (j['show_qr_on_print'] as bool?) ?? false,
    );
  }

  /// Fix `supabase.co//storage` → `supabase.co/storage`
  static String? _sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceAllMapped(
      RegExp(r'(\.co)/+storage'),
      (_) => '.co/storage',
    );
  }

  /// Remove Arabic diacritics (tanween, harakat) — causes □□□ in PDF Cairo
  static String _sanitizeFooter(String text) {
    return text
        .replaceAll('ً', '')
        .replaceAll('ٌ', '')
        .replaceAll('ٍ', '')
        .replaceAll('َ', '')
        .replaceAll('ُ', '')
        .replaceAll('ِ', '')
        .replaceAll('ّ', '')
        .replaceAll('ْ', '');
  }

  bool get is58mm => paperWidth == '58mm';
  double get paperWidthMm => is58mm ? 58 : 80;
  bool get isBold => fontWeight == 'bold';
}

class InvoiceSettingsRepository {
  final SupabaseClient _sb;
  InvoiceSettingsRepository(this._sb);

  Future<InvoiceSettings> load(String companyId) async {
    try {
      final res = await _sb
          .from('company_settings')
          .select(
            'logo_url, paper_width, print_font_scale, '
            'print_font_weight, receipt_footer, '
            'show_currency_symbol, show_qr_on_print',
          )
          .eq('company_id', companyId)
          .maybeSingle();
      if (res == null) return InvoiceSettings.defaults();
      return InvoiceSettings.fromJson(res);
    } catch (_) {
      return InvoiceSettings.defaults();
    }
  }
}
