import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothPrinterService {
  static const _prefKeyAddress = 'printer_address';
  static const _prefKeyName = 'printer_name';

  /// بحث عن طابعات البلوتوث المقترنة
  static Future<List<PrinterDevice>> discoverPrinters() async {
    try {
      final printers = await PrinterManager.instance.discovery(
        type: PrinterType.bluetooth,
      );
      return printers;
    } catch (_) {
      return [];
    }
  }

  /// عنوان الطابعة المحفوظة
  static Future<String?> getSavedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyAddress);
  }

  /// اسم الطابعة المحفوظة
  static Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyName);
  }

  /// حفظ الطابعة
  static Future<void> savePrinter({
    required String address,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyAddress, address);
    await prefs.setString(_prefKeyName, name);
  }

  /// مسح الطابعة
  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAddress);
    await prefs.remove(_prefKeyName);
  }

  /// الاتصال بالطابعة
  static Future<bool> connect(PrinterDevice device) async {
    try {
      final connected = await PrinterManager.instance.connect(
        model: PrinterAdapter(
          model: device,
          port: '9100',
        ),
      );
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  /// إرسال بايتات للطباعة
  static Future<bool> writeBytes(List<int> bytes) async {
    try {
      await PrinterManager.instance.send(
        type: PrinterType.bytes,
        bytes: bytes,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// قطع الاتصال
  static Future<void> disconnect() async {
    try {
      await PrinterManager.instance.disconnect();
    } catch (_) {}
  }
}
