import 'dart:async';

import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothPrinterService {
  static const _prefKeyAddress = 'printer_address';
  static const _prefKeyName = 'printer_name';

  /// بحث عن طابعات البلوتوث المقترنة
  /// discovery() بيرجع Stream — بنجمعه في List مع timeout
  static Future<List<PrinterDevice>> discoverPrinters() async {
    final printers = <PrinterDevice>[];
    try {
      final stream = PrinterManager.instance.discovery(
        type: PrinterType.bluetooth,
      );
      await for (final device in stream.timeout(
        const Duration(seconds: 6),
        onTimeout: (sink) => sink.close(),
      )) {
        printers.add(device);
      }
    } catch (_) {}
    return printers;
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

  /// مسح الطابعة المحفوظة
  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAddress);
    await prefs.remove(_prefKeyName);
  }

  /// الاتصال بالطابعة
  static Future<bool> connect(PrinterDevice device) async {
    try {
      final connected = await PrinterManager.instance.connect(
        type: PrinterType.bluetooth,
        model: device,
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
        type: PrinterType.bluetooth,
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
      await PrinterManager.instance.disconnect(type: PrinterType.bluetooth);
    } catch (_) {}
  }
}
