import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'src/quick_blue_platform_interface.dart';

export 'src/models.dart';
export 'src/quick_blue_linux.dart';
export 'src/quick_blue_platform_interface.dart';

class QuickBlue {
  static QuickBluePlatform _platform = QuickBluePlatform.instance;

  static set platform(QuickBluePlatform platform) {
    _platform = platform;
  }

  static void setInstance(QuickBluePlatform instance) => _platform = instance;

  static void setLogger(QuickLogger logger) =>
      _platform.setLogger(logger);

  static Future<bool> isBluetoothAvailable() =>
      _platform.isBluetoothAvailable();

  static void setAvailabilityHandler(OnAvailabilityChanged? onAvailabilityChanged) {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnimplementedError('setAvailabilityHandler is only implemented on iOS and macOS');
    }
    _platform.onAvailabilityChanged = onAvailabilityChanged;
  }

  static Future<void> startScan() => _platform.startScan();

  static void stopScan() => _platform.stopScan();

  static Stream<BlueScanResult> get scanResultStream {
    return _platform.scanResultStream
      .map((item) => BlueScanResult.fromMap(item));
  }

  static void connect(String deviceId) => _platform.connect(deviceId);

  static void disconnect(String deviceId) => _platform.disconnect(deviceId);

  static void setConnectionHandler(OnConnectionChanged? onConnectionChanged) {
    _platform.onConnectionChanged = onConnectionChanged;
  }

  static void discoverServices(String deviceId) => _platform.discoverServices(deviceId);

  static void setServiceHandler(OnServiceDiscovered? onServiceDiscovered) {
    _platform.onServiceDiscovered = onServiceDiscovered;
  }

  static Future<void> setNotifiable(String deviceId, String service, String characteristic, BleInputProperty bleInputProperty) {
    return _platform.setNotifiable(deviceId, service, characteristic, bleInputProperty);
  }

  static void setValueHandler(OnValueChanged? onValueChanged) {
    _platform.onValueChanged = onValueChanged;
  }

  static Future<void> readValue(String deviceId, String service, String characteristic) {
    return _platform.readValue(deviceId, service, characteristic);
  }

  static Future<void> writeValue(String deviceId, String service, String characteristic, Uint8List value, BleOutputProperty bleOutputProperty) {
    return _platform.writeValue(deviceId, service, characteristic, value, bleOutputProperty);
  }

  static Future<int> requestMtu(String deviceId, int expectedMtu) => _platform.requestMtu(deviceId, expectedMtu);
}
