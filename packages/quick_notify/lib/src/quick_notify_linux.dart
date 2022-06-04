import 'package:desktop_notifications/desktop_notifications.dart';

import 'quick_notify_platform_interface.dart';

class QuickNotifyLinux extends QuickNotifyPlatform {
  // For example/.dart_tool/flutter_build/generated_main.dart
  static registerWith() {
    QuickNotifyPlatform.instance = QuickNotifyLinux();
  }

  @override
  Future<bool> hasPermission() async {
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    return true;
  }

  @override
  Future<void> notify({
    required String title,
    String? content,
  }) async {
    var client = NotificationsClient();
    await client.notify(title, body: content ?? '');
    await client.close();
  }
}