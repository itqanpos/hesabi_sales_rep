import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mirrors Hesabi's `company_settings` table — READ ONLY from app.
class InvoiceSettings {
  final String? logoUrl;
  final String paperWidth;
  final double fontScale;
  final String fontWeight;
  final String receiptFooter;
  final bool showCurrencySymbol;
  final bool showQrOnPrint;
  final bool showTaxNumberOnPrint;
  final bool showCommercialRegisterOnPrint;
  final bool printDirectEnabled;

  const InvoiceSettings({
    this.logoUrl,
    required this.paperWidth,
    required this.fontScale,
    required this.fontWeight,
    required this.receiptFooter,
    required this.showCurrencySymbol,
    required this.showQrOnPrint,
    required this.showTaxNumberOnPrint,
    required this.showCommercialRegisterOnPrint,
    required this.printDirectEnabled,
  });

  factory InvoiceSettings.defaults() => const InvoiceSettings(
        paperWidth: '80mm',
        fontScale: 1.0,
        fontWeight: 'normal',
        receiptFooter: 'شكرا لتعاملكم معنا',
        showCurrencySymbol: false,
        showQrOnPrint: false,
        showTaxNumberOnPrint: false,
        showCommercialRegisterOnPrint: false,
        printDirectEnabled: true,
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
      showTaxNumberOnPrint:
          (j['show_tax_number_on_print'] as bool?) ?? false,
      showCommercialRegisterOnPrint:
          (j['show_commercial_register_on_print'] as bool?) ?? false,
      printDirectEnabled: (j['print_direct_enabled'] as bool?) ?? true,
    );
  }

  InvoiceSettings copyWith({
    String? paperWidth,
    double? fontScale,
  }) {
    return InvoiceSettings(
      logoUrl: logoUrl,
      paperWidth: paperWidth ?? this.paperWidth,
      fontScale: fontScale ?? this.fontScale,
      fontWeight: fontWeight,
      receiptFooter: receiptFooter,
      showCurrencySymbol: showCurrencySymbol,
      showQrOnPrint: showQrOnPrint,
      showTaxNumberOnPrint: showTaxNumberOnPrint,
      showCommercialRegisterOnPrint: showCommercialRegisterOnPrint,
      printDirectEnabled: printDirectEnabled,
    );
  }

  bool get is58mm => paperWidth == '58mm';
  double get paperWidthMm => is58mm ? 58 : 80;
  bool get isBold => fontWeight == 'bold';

  static String? _sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceAllMapped(
      RegExp(r'(\.co)/+storage'),
      (_) => '.co/storage',
    );
  }

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
}

/// Local overrides stored on device — not synced to Hesabi.
class LocalPrintOverrides {
  final String? paperWidth; // '58mm' | '80mm' | null
  final double? fontScale;  // null = use Hesabi

  const LocalPrintOverrides({this.paperWidth, this.fontScale});

  bool get isEmpty => paperWidth == null && fontScale == null;
}

class InvoiceSettingsRepository {
  final SupabaseClient _sb;
  InvoiceSettingsRepository(this._sb);

  static const _kLocalPaperWidth = 'local_paper_width';
  static const _kLocalFontScale = 'local_font_scale';

  /// Read Hesabi company_settings (read-only).
  Future<InvoiceSettings> load(String companyId) async {
    try {
      final res = await _sb
          .from('company_settings')
          .select('*')
          .eq('company_id', companyId)
          .maybeSingle();
      if (res == null) return InvoiceSettings.defaults();
      return InvoiceSettings.fromJson(res);
    } catch (_) {
      return InvoiceSettings.defaults();
    }
  }

  /// Read local overrides from SharedPreferences.
  Future<LocalPrintOverrides> loadLocalOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalPrintOverrides(
      paperWidth: prefs.getString(_kLocalPaperWidth),
      fontScale: prefs.getDouble(_kLocalFontScale),
    );
  }

  /// Save local overrides.
  Future<void> saveLocalOverrides(LocalPrintOverrides overrides) async {
    final prefs = await SharedPreferences.getInstance();
    if (overrides.paperWidth == null) {
      await prefs.remove(_kLocalPaperWidth);
    } else {
      await prefs.setString(_kLocalPaperWidth, overrides.paperWidth!);
    }
    if (overrides.fontScale == null) {
      await prefs.remove(_kLocalFontScale);
    } else {
      await prefs.setDouble(_kLocalFontScale, overrides.fontScale!);
    }
  }

  /// Load effective settings: Hesabi base + local overrides.
  Future<InvoiceSettings> loadEffective(String companyId) async {
    final base = await load(companyId);
    final local = await loadLocalOverrides();
    return base.copyWith(
      paperWidth: local.paperWidth,
      fontScale: local.fontScale,
    );
  }
}
