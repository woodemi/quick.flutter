import 'dart:async';

import 'src/quick_blue_platform_interface.dart';

export 'src/models.dart';
export 'src/quick_blue_linux.dart';

QuickBluePlatform get _platform => QuickBluePlatform.instance;

class QuickBlue {
  static void setLogger(QuickLogger logger) =>
      _platform.setLogger(logger);

  static Future<bool> isBluetoothAvailable() =>
      _platform.isBluetoothAvailable();

  static void startScan() => _platform.startScan();

  static void stopScan() => _platform.stopScan();

  static Stream<BlueScanResult> get scanResultStream {
    return _platform.scanResultStream
      .map((item) => BlueScanResult.fromMap(item));
  }
}
