import 'dart:typed_data';

import 'src/common.dart';
import 'src/quick_usb_platform_interface.dart';

export 'src/common.dart';

QuickUsbPlatform get _platform => QuickUsbPlatform.instance;

class QuickUsb {
  static Future<bool> init() => _platform.init();

  static Future<void> exit() => _platform.exit();

  static Future<List<UsbDevice>> getDeviceList() => _platform.getDeviceList();

  static Future<bool> hasPermission(UsbDevice usbDevice) =>
      _platform.hasPermission(usbDevice);

  static Future<void> requestPermission(UsbDevice usbDevice) =>
      _platform.requestPermission(usbDevice);

  static Future<bool> openDevice(UsbDevice usbDevice) =>
      _platform.openDevice(usbDevice);

  static Future<void> closeDevice() => _platform.closeDevice();

  static Future<UsbConfiguration> getConfiguration(int index) =>
      _platform.getConfiguration(index);

  static Future<bool> setConfiguration(UsbConfiguration config) =>
      _platform.setConfiguration(config);

  static Future<bool> detachKernelDriver(UsbInterface intf) =>
      _platform.detachKernelDriver(intf);

  static Future<bool> claimInterface(UsbInterface intf) =>
      _platform.claimInterface(intf);

  static Future<bool> releaseInterface(UsbInterface intf) =>
      _platform.releaseInterface(intf);

  static Future<Uint8List> bulkTransferIn(UsbEndpoint endpoint, int maxLength,
          {int timeout = 1000}) =>
      _platform.bulkTransferIn(endpoint, maxLength, timeout);

  static Future<int> bulkTransferOut(UsbEndpoint endpoint, Uint8List data,
          {int timeout = 1000}) =>
      _platform.bulkTransferOut(endpoint, data, timeout);

  static Future<UsbDeviceDescription> getDeviceDescription(
          UsbDevice usbDevice) =>
      _platform.getDeviceDescription(usbDevice);

  static Future<List<UsbDeviceDescription>> getDevicesWithDescription() =>
      _platform.getDevicesWithDescription();

  static Future<void> setAutoDetachKernelDriver(bool enable) =>
      _platform.setAutoDetachKernelDriver(enable);
}
