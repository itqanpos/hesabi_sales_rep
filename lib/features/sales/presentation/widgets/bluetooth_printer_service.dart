import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothPrinterService {
  static final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  static const _prefKeyAddress = 'printer_address';
  static const _prefKeyName = 'printer_name';

  static Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final devices = await _printer.getBondedDevices();
      return devices;
    } catch (_) {
      return [];
    }
  }

  static Future<String?> getSavedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyAddress);
  }

  static Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyName);
  }

  static Future<void> savePrinter({
    required String address,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyAddress, address);
    await prefs.setString(_prefKeyName, name);
  }

  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAddress);
    await prefs.remove(_prefKeyName);
  }

  static Future<bool> isConnected() async {
    try {
      final connected = await _printer.isConnected;
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> connect(String address) async {
    try {
      final devices = await _printer.getBondedDevices();
      BluetoothDevice? device;
      for (final d in devices) {
        if (d.address == address) {
          device = d;
          break;
        }
      }
      if (device == null) return false;
      await _printer.connect(device);
      final connected = await _printer.isConnected ?? false;
      return connected;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await _printer.disconnect();
    } catch (_) {}
  }

  static Future<bool> writeBytes(List<int> bytes) async {
    try {
      await _printer.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }
}
