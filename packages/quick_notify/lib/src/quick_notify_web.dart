import 'dart:html';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:quick_notify/src/quick_notify_platform_interface.dart';

// const _permissionDefault = 'default';
// const _permissionDenied = 'denied';
const _permissionGranted = 'granted';

class QuickNotifyWeb extends QuickNotifyPlatform {
  static void registerWith(Registrar registrar) {
    QuickNotifyPlatform.instance = QuickNotifyWeb();
  }

  @override
  Future<bool> hasPermission() async {
    return Notification.permission == _permissionGranted;
  }

  @override
  Future<bool> requestPermission() async {
    var result = await Notification.requestPermission();
    return result == _permissionGranted;
  }

  @override
  Future<void> notify({
    required String title,
    String? content,
  }) async {
    Notification(title, body: content);
  }
}