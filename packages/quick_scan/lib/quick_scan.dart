
import 'dart:async';

import 'package:flutter/services.dart';

class QuickScan {
  static const MethodChannel _channel = MethodChannel('quick_scan');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
