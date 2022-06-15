import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'quick_blue_platform_interface.dart';

class MethodChannelQuickBlue extends QuickBluePlatform {
  static const _method = MethodChannel('quick_blue/method');
  static const _eventScanResult = EventChannel('quick_blue/event.scanResult');
  static const _messageConnector = BasicMessageChannel('quick_blue/message.connector', StandardMessageCodec());

  MethodChannelQuickBlue() {
    _messageConnector.setMessageHandler(_handleConnectorMessage);
  }

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
  Future<void> startScan() async {
    await _method.invokeMethod('startScan');
    _log('startScan invokeMethod success');
  }

  @override
  Future<void> stopScan() async {
    await _method.invokeMethod('startScan');
    _log('startScan invokeMethod success');
  }

  final Stream<dynamic> _scanResultStream = _eventScanResult.receiveBroadcastStream({'name': 'scanResult'});

  @override
  Stream<dynamic> get scanResultStream => _scanResultStream;

  @override
  void connect(String deviceId) {
    _method.invokeMethod('connect', {
      'deviceId': deviceId,
    }).then((_) => _log('connect invokeMethod success'));
  }

  @override
  void disconnect(String deviceId) {
    _method.invokeMethod('disconnect', {
      'deviceId': deviceId,
    }).then((_) => _log('disconnect invokeMethod success'));
  }

  @override
  void discoverServices(String deviceId) {
    _method.invokeMethod('discoverServices', {
      'deviceId': deviceId,
    }).then((_) => _log('discoverServices invokeMethod success'));
  }

  Future<void> _handleConnectorMessage(dynamic message) async {
    _log('_handleConnectorMessage $message', logLevel: Level.ALL);
    if (message['ConnectionState'] != null) {
      String deviceId = message['deviceId'];
      BlueConnectionState connectionState = BlueConnectionState.parse(message['ConnectionState']);
      onConnectionChanged?.call(deviceId, connectionState);
    } else if (message['ServiceState'] != null) {
      if (message['ServiceState'] == 'discovered') {
        String deviceId = message['deviceId'];
        String service = message['service'];
        List<String> characteristics = (message['characteristics'] as List).cast();
        onServiceDiscovered?.call(deviceId, service, characteristics);
      }
    } else if (message['characteristicValue'] != null) {
      String deviceId = message['deviceId'];
      var characteristicValue = message['characteristicValue'];
      String characteristic = characteristicValue['characteristic'];
      Uint8List value = Uint8List.fromList(characteristicValue['value']); // In case of _Uint8ArrayView
      onValueChanged?.call(deviceId, characteristic, value);
    } else if (message['mtuConfig'] != null) {
      _mtuConfigController.add(message['mtuConfig']);
    } else if (message['write'] != null) {
      var err = message['error'];
      String? error = (err == null || err == 'nil') ? null : message['error'];
      _writeResponseController.add({
        'deviceId': message['deviceId'],
        'characteristic': message['characteristic'],
        'error': error,
      });
    }
  }

  @override
  Future<void> setNotifiable(String deviceId, String service, String characteristic, BleInputProperty bleInputProperty) async {
    _method.invokeMethod('setNotifiable', {
      'deviceId': deviceId,
      'service': service,
      'characteristic': characteristic,
      'bleInputProperty': bleInputProperty.value,
    }).then((_) => _log('setNotifiable invokeMethod success'));
  }

  @override
  Future<void> readValue(String deviceId, String service, String characteristic) async {
    _method.invokeMethod('readValue', {
      'deviceId': deviceId,
      'service': service,
      'characteristic': characteristic,
    }).then((_) => _log('readValue invokeMethod success'));
  }

  // FIXME Close
  final _writeResponseController = StreamController.broadcast();

  @override
  Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      BleOutputProperty bleOutputProperty) async {
    _method.invokeMethod('writeValue', {
      'deviceId': deviceId,
      'service': service,
      'characteristic': characteristic,
      'value': value,
      'bleOutputProperty': bleOutputProperty.value,
    }).then((_) {
      _log('writeValue invokeMethod success', logLevel: Level.ALL);
    }).catchError((onError) {
      // Characteristic sometimes unavailable on Android
      throw onError;
    });
    // For MacOS and IOS , this will capture result and auto close after one second
    // Android Errors can be captured in .cathError
    // need to check for Windows
    if (!(Platform.isMacOS || Platform.isIOS)) return;
    String? error = await _writeResponseController.stream
        .where((event) =>
            event['deviceId'] == deviceId &&
            event['characteristic'] == characteristic)
        .map((event) => event['error'])
        .timeout(
          const Duration(seconds: 1),
          onTimeout: (sink) => sink.add(null),
        )
        .first;
    if (error != null) {
      throw error;
    }
  }

  // FIXME Close
  final _mtuConfigController = StreamController<int>.broadcast();

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    _method.invokeMethod('requestMtu', {
      'deviceId': deviceId,
      'expectedMtu': expectedMtu,
    }).then((_) => _log('requestMtu invokeMethod success'));
    return await _mtuConfigController.stream.first;
  }
}
