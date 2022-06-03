import 'src/quick_notify_platform_interface.dart';

QuickNotifyPlatform get _platform => QuickNotifyPlatform.instance;

class QuickNotify {
  static Future<bool> hasPermission() => _platform.hasPermission();

  static Future<bool> requestPermission() => _platform.requestPermission();

  static void notify({
    String title = 'quick_notify',
    String? content,
  }) => _platform.notify(
    title: title,
    content: content,
  );
}
