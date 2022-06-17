import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:quick_usb/src/common.dart';
import 'package:quick_usb/src/quick_usb_platform_interface.dart';

const MethodChannel _channel = MethodChannel('quick_usb');

class QuickUsbAndroid extends QuickUsbPlatform {
  // For example/.dart_tool/flutter_build/generated_main.dart
  static registerWith() {
    QuickUsbPlatform.instance = QuickUsbAndroid();
  }

  @override
  Future<bool> init() async {
    return true;
  }

  @override
  Future<void> exit() async {
    return;
  }

  @override
  Future<List<UsbDevice>> getDeviceList() async {
    List<Map<dynamic, dynamic>> devices = (await _channel.invokeListMethod('getDeviceList'))!;
    return devices.map((device) => UsbDevice.fromMap(device)).toList();
  }

  @override
  Future<List<UsbDeviceDescription>> getDevicesWithDescription({
    bool requestPermission = true,
  }) async {
    var devices = await getDeviceList();
    var result = <UsbDeviceDescription>[];
    for (var device in devices) {
      result.add(await getDeviceDescription(
        device,
        requestPermission: requestPermission,
      ));
    }
    return result;
  }

  @override
  Future<UsbDeviceDescription> getDeviceDescription(
    UsbDevice usbDevice, {
    bool requestPermission = true,
  }) async {
    var result = await _channel.invokeMethod('getDeviceDescription', {
      'device': usbDevice.toMap(),
      'requestPermission': requestPermission,
    });
    return UsbDeviceDescription(
      device: usbDevice,
      manufacturer: result['manufacturer'],
      product: result['product'],
      serialNumber: result['serialNumber'],
    );
  }

  @override
  Future<bool> hasPermission(UsbDevice usbDevice) async {
    return await _channel.invokeMethod('hasPermission', usbDevice.toMap());
  }

  @override
  Future<bool> requestPermission(UsbDevice usbDevice) async {
    return await _channel.invokeMethod('requestPermission', usbDevice.toMap());
  }

  @override
  Future<bool> openDevice(UsbDevice usbDevice) async {
    return await _channel.invokeMethod('openDevice', usbDevice.toMap());
  }

  @override
  Future<void> closeDevice() {
    return _channel.invokeMethod('closeDevice');
  }

  @override
  Future<UsbConfiguration> getConfiguration(int index) async {
    var map = await _channel.invokeMethod('getConfiguration', {
      'index': index,
    });
    return UsbConfiguration.fromMap(map);
  }

  @override
  Future<bool> setConfiguration(UsbConfiguration config) async {
    return await _channel.invokeMethod('setConfiguration', config.toMap());
  }

  @override
  Future<bool> detachKernelDriver(UsbInterface intf) async {
    return true;
  }

  @override
  Future<bool> claimInterface(UsbInterface intf) async {
    return await _channel.invokeMethod('claimInterface', intf.toMap());
  }

  @override
  Future<bool> releaseInterface(UsbInterface intf) async {
    return await _channel.invokeMethod('releaseInterface', intf.toMap());
  }

  @override
  Future<Uint8List> bulkTransferIn(
      UsbEndpoint endpoint, int maxLength, int timeout) async {
    assert(endpoint.direction == UsbEndpoint.DIRECTION_IN,
        'Endpoint\'s direction should be in');

    List<dynamic> data = await _channel.invokeMethod('bulkTransferIn', {
      'endpoint': endpoint.toMap(),
      'maxLength': maxLength,
      'timeout': timeout,
    });
    return Uint8List.fromList(data.cast<int>());
  }

  @override
  Future<int> bulkTransferOut(
      UsbEndpoint endpoint, Uint8List data, int timeout) async {
    assert(endpoint.direction == UsbEndpoint.DIRECTION_OUT,
        'Endpoint\'s direction should be out');

    return await _channel.invokeMethod('bulkTransferOut', {
      'endpoint': endpoint.toMap(),
      'data': data,
      'timeout': timeout,
    });
  }

  @override
  Future<void> setAutoDetachKernelDriver(bool enable) async {}
}
