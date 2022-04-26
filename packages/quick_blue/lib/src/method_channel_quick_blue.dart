import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'quick_blue_platform_interface.dart';

class MethodChannelQuickBlue extends QuickBluePlatform {
  static const _method = MethodChannel('quick_blue/method');
  static const _eventScanResult = EventChannel('quick_blue/event.scanResult');

  QuickLogger? _logger;

  @override
  void setLogger(QuickLogger logger) {
    _logger = logger;
  }

  void _log(String message, {Level logLevel = Level.INFO}) {
    _logger?.log(logLevel, message);
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    bool result = await _method.invokeMethod('isBluetoothAvailable');
    return result;
  }

  @override
  void startScan() {
    _method.invokeMethod('startScan')
        .then((_) => _log('startScan invokeMethod success'));
  }

  @override
  void stopScan() {
    _method.invokeMethod('stopScan')
        .then((_) => _log('stopScan invokeMethod success'));
  }

  final Stream<dynamic> _scanResultStream = _eventScanResult.receiveBroadcastStream({'name': 'scanResult'});

  @override
  Stream<dynamic> get scanResultStream => _scanResultStream;
}
