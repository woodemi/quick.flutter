import 'dart:typed_data';

class BlueScanResult {
  final String name;
  String deviceId;
  final Uint8List? _manufacturerDataHead;
  final Uint8List? _manufacturerData;
  int rssi;

  Uint8List get manufacturerDataHead => _manufacturerDataHead ?? Uint8List.fromList([]);

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