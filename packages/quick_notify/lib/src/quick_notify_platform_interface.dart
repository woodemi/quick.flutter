import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quick_notify/src/method_channel_quick_notify.dart';

abstract class QuickNotifyPlatform extends PlatformInterface {
  QuickNotifyPlatform() : super(token: _token);

  static final Object _token = Object();

  static QuickNotifyPlatform _instance = MethodChannelQuickNotify();

  static QuickNotifyPlatform get instance => _instance;

  static set instance(QuickNotifyPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  Future<void> notify({
    required String title,
    String? content,
  });
}
