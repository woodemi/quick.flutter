import 'dart:async';
import 'dart:typed_data';

import 'package:bluez/bluez.dart';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:logging/logging.dart';

import 'quick_blue_platform_interface.dart';

class QuickBlueLinux extends QuickBluePlatform {
  // For example/.dart_tool/flutter_build/generated_main.dart
  static registerWith() {
    QuickBluePlatform.instance = QuickBlueLinux();
  }

  bool isInitialized = false;

  final BlueZClient _client = BlueZClient();

  BlueZAdapter? _activeAdapter;

  Future<void> _ensureInitialized() async {
    if (!isInitialized) {
      await _client.connect();

      _activeAdapter ??= _client.adapters.firstWhereOrNull((adapter) => adapter.powered);
      if (_activeAdapter == null) {
          if (_client.adapters.isEmpty) {
             throw Exception('Bluetooth adapter unavailable');
          }
          await _client.adapters.first.setPowered(true);
          _activeAdapter = _client.adapters.first;
      }
      _client.deviceAdded.listen(_onDeviceAdd);

      isInitialized = true;
    }
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
    await _ensureInitialized();
    _log('isBluetoothAvailable invoke success');

    return _activeAdapter != null;
  }

  @override
  Future<void> startScan() async {
    await _ensureInitialized();
    _log('startScan invoke success');

    if (!_activeAdapter!.discovering) {
      _activeAdapter!.startDiscovery();
      _client.devices.forEach(_onDeviceAdd);
    }
  }

  @override
  Future<void> stopScan() async {
    await _ensureInitialized();
    _log('stopScan invoke success');

    if (!_activeAdapter!.discovering) {
      _activeAdapter!.stopDiscovery();
    }
  }

  // FIXME Close
  final StreamController<dynamic> _scanResultController = StreamController.broadcast();

  @override
  Stream get scanResultStream => _scanResultController.stream;

  void _onDeviceAdd(BlueZDevice device) {
    _scanResultController.add({
      'deviceId': device.address,
      'name': device.alias,
      'manufacturerDataHead': device.manufacturerDataHead,
      'rssi': device.rssi,
    });
  }

  BlueZDevice _findDeviceById(String deviceId) {
    var device = _client.devices.firstWhereOrNull((device) => device.address == deviceId);
    if (device == null) {
      throw Exception('Unknown deviceId:$deviceId');
    }
    return device;
  }

  @override
  void connect(String deviceId) {
    _findDeviceById(deviceId).connect().then((_) {
      onConnectionChanged?.call(deviceId, BlueConnectionState.connected);
    });
  }

  @override
  void disconnect(String deviceId) {
    _findDeviceById(deviceId).disconnect().then((_) {
      onConnectionChanged?.call(deviceId, BlueConnectionState.disconnected);
    });
  }

  @override
  void discoverServices(String deviceId) {
    var device = _findDeviceById(deviceId);

    for (var service in device.gattServices) {
      _log("Service ${service.uuid}");
      for (var characteristic in service.characteristics) {
        _log("    Characteristic ${characteristic.uuid}");
      }

      var characteristics = service.characteristics.map((e) => e.uuid.toString()).toList();
      onServiceDiscovered?.call(deviceId, service.uuid.toString(), characteristics);
    }
  }

  BlueZGattCharacteristic _getCharacteristic(String deviceId, String service, String characteristic) {
    var device = _findDeviceById(deviceId);
    var s = device.gattServices.firstWhereOrNull((s) => s.uuid.toString() == service);
    var c = s?.characteristics.firstWhereOrNull((c) => c.uuid.toString() == characteristic);

    if (c == null) {
      throw Exception('Unknown characteristic:$characteristic');
    }
    return c;
  }

  final Map<String, StreamSubscription<List<String>>> _characteristicPropertiesSubcriptions = {};

  @override
  Future<void> setNotifiable(String deviceId, String service, String characteristic, BleInputProperty bleInputProperty) async {
    var c = _getCharacteristic(deviceId, service, characteristic);
    
    if (bleInputProperty != BleInputProperty.disabled) {
      c.startNotify();
      void onPropertiesChanged(properties) {
        if (properties.contains('Value')) {
          _log('onCharacteristicPropertiesChanged $characteristic, ${hex.encode(c.value)}');
          onValueChanged?.call(deviceId, characteristic, Uint8List.fromList(c.value));
        }
      }
      _characteristicPropertiesSubcriptions[characteristic] ??= c.propertiesChanged.listen(onPropertiesChanged);
    } else {
      c.stopNotify();
      _characteristicPropertiesSubcriptions.remove(characteristic)?.cancel();
    }
  }

  @override
  Future<void> readValue(String deviceId, String service, String characteristic) async {
    var c = _getCharacteristic(deviceId, service, characteristic);

    var data = await c.readValue();
    _log('readValue $characteristic, ${hex.encode(data)}');
    onValueChanged?.call(deviceId, characteristic, Uint8List.fromList(data));
  }

  @override
  Future<void> writeValue(String deviceId, String service, String characteristic, Uint8List value, BleOutputProperty bleOutputProperty) async {
    var c = _getCharacteristic(deviceId, service, characteristic);

    if (bleOutputProperty == BleOutputProperty.withResponse) {
      await c.writeValue(value, type: BlueZGattCharacteristicWriteType.request);
    } else {
      await c.writeValue(value, type: BlueZGattCharacteristicWriteType.command);
    }
    _log('writeValue $characteristic, ${hex.encode(value)}');
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) {
    // TODO: implement requestMtu
    throw UnimplementedError();
  }
}

extension BlueZDeviceExtension on BlueZDevice {
  Uint8List get manufacturerDataHead {
    if (manufacturerData.isEmpty) return Uint8List(0);

    final sorted = manufacturerData.entries.toList()
      ..sort((a, b) => a.key.id - b.key.id);
    return Uint8List.fromList(sorted.first.value);
  }
}
