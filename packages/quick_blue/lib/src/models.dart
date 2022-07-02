import 'dart:typed_data';

class AvailabilityState {
  static const unknown = AvailabilityState._(0);
  static const resetting = AvailabilityState._(1);
  static const unsupported = AvailabilityState._(2);
  static const unauthorized = AvailabilityState._(3);
  static const poweredOff = AvailabilityState._(4);
  static const poweredOn = AvailabilityState._(5);

  final int value;

  const AvailabilityState._(this.value);

  static AvailabilityState parse(int value) {
    if (value == unknown.value) {
      return unknown;
    } else if (value == resetting.value) {
      return resetting;
    } else if (value == unsupported.value) {
      return unsupported;
    } else if (value == unauthorized.value) {
      return unauthorized;
    } else if (value == poweredOff.value) {
      return poweredOff;
    } else if (value == poweredOn.value) {
      return poweredOn;
    }
    throw ArgumentError.value(value);
  }

  @override
  String toString() {
    switch (this) {
      case AvailabilityState.unknown:
        return 'unknown';
      case AvailabilityState.resetting:
        return 'resetting';
      case AvailabilityState.unsupported:
        return 'unsupported';
      case AvailabilityState.unauthorized:
        return 'unauthorized';
      case AvailabilityState.poweredOff:
        return 'poweredOff';
      case AvailabilityState.poweredOn:
        return 'poweredOn';
      default:
        throw ArgumentError.value(value);
    }
  }
}

class BlueScanResult {
  final String name;
  String deviceId;
  final Uint8List? _manufacturerDataHead;
  final Uint8List? _manufacturerData;
  int rssi;

  Uint8List get manufacturerDataHead =>
      _manufacturerDataHead ?? Uint8List.fromList([]);

  Uint8List get manufacturerData => _manufacturerData ?? manufacturerDataHead;

  BlueScanResult.fromMap(map)
      : name = map['name'],
        deviceId = map['deviceId'],
        _manufacturerDataHead = map['manufacturerDataHead'],
        _manufacturerData = map['manufacturerData'],
        rssi = map['rssi'];

  Map toMap() => {
        'name': name,
        'deviceId': deviceId,
        'manufacturerDataHead': _manufacturerDataHead,
        'manufacturerData': _manufacturerData,
        'rssi': rssi,
      };
}

class BlueConnectionState {
  static const disconnected = BlueConnectionState._('disconnected');
  static const connected = BlueConnectionState._('connected');

  final String value;

  const BlueConnectionState._(this.value);

  static BlueConnectionState parse(String value) {
    if (value == disconnected.value) {
      return disconnected;
    } else if (value == connected.value) {
      return connected;
    }
    throw ArgumentError.value(value);
  }
}

class BleInputProperty {
  static const disabled = BleInputProperty._('disabled');
  static const notification = BleInputProperty._('notification');
  static const indication = BleInputProperty._('indication');

  final String value;

  const BleInputProperty._(this.value);
}

class BleOutputProperty {
  static const withResponse = BleOutputProperty._('withResponse');
  static const withoutResponse = BleOutputProperty._('withoutResponse');

  final String value;

  const BleOutputProperty._(this.value);
}
