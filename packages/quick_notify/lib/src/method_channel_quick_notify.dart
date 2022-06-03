import 'package:flutter/services.dart';

import 'quick_notify_platform_interface.dart';

const MethodChannel _channel = MethodChannel('quick_notify');

class MethodChannelQuickNotify extends QuickNotifyPlatform {
  @override
  Future<bool> hasPermission() async {
    bool result = await _channel.invokeMethod('hasPermission');
    return result;
  }

  @override
  Future<bool> requestPermission() async {
    bool result = await _channel.invokeMethod('requestPermission');
    return result;
  }

  @override
  void notify({
    required String title,
    String? content,
  }) {
    _channel.invokeMethod('notify', {
      'title': title,
      'content': content,
    });
  }
}