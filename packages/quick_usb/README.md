# quick_usb

A cross-platform (Android/Windows/macOS/Linux) USB plugin for Flutter

## Usage

- [List devices](#list-devices)
- [List devices with additional description](#list-devices-with-additional-description)
- [Get device description](#get-device-description)
- [Check permission](#check-permission)
- [Request permission](#request-permission)
- [Open/Close device](#openclose-device)
- [Get/Set configuration](#getset-configuration)
- [Claim/Release interface](#claimrelease-interface)
- [Bulk transfer in/out](#bulk-transfer-inout)
- [Set auto detach kernel driver](#set-auto-detach-kernel-driver)

### List devices

```dart
await QuickUsb.init();
// ...
var deviceList = await QuickUsb.getDeviceList();
// ...
await QuickUsb.exit();
```

### List devices with additional description

Returns devices list with manufacturer, product and serial number description.

Any of these attributes can be null.

```dart
var descriptions = await QuickUsb.getDevicesWithDescription();
var deviceList = descriptions.map((e) => e.device).toList();
print('descriptions $descriptions');
```

**(Android Only)** Android requires permission for each device in order to get the serial number. The user will be asked
for permission for each device if needed. If you do not require the serial number, you can avoid requesting permission using:
```dart
var descriptions = await QuickUsb.getDevicesWithDescription(requestPermission: false);
```

### Get device description

Returns manufacturer, product and serial number description for specified device.

Any of these attributes can be null.

```dart
 var description = await QuickUsb.getDeviceDescription(device);
 print('description ${description.toMap()}');
```

**(Android Only)** Android requires permission for each device in order to get the serial number. The user will be asked
for permission for each device if needed. If you do not require the serial number, you can avoid requesting permission using:
```dart
var description = await QuickUsb.getDeviceDescription(requestPermission: false);
```

### Check permission

_**Android Only**_

```dart
var hasPermission = await QuickUsb.hasPermission(device);
print('hasPermission $hasPermission');
```

### Request permission

_**Android Only**_

Request permission for a device. The permission dialog is not shown
if the app already has permission to access the device.

```dart
var hasPermission = await QuickUsb.requestPermission(device);
print('hasPermission $hasPermission');
```

### Open/Close device

```dart
var openDevice = await QuickUsb.openDevice(device);
print('openDevice $openDevice');
// ...
await QuickUsb.closeDevice();
```

### Get/Set configuration

```dart
var configuration = await QuickUsb.getConfiguration(index);
print('getConfiguration $configuration');
// ...
var setConfiguration = await QuickUsb.setConfiguration(configuration);
print('setConfiguration $getConfiguration');
```

### Claim/Release interface

```dart
var claimInterface = await QuickUsb.claimInterface(interface);
print('claimInterface $claimInterface');
// ...
var releaseInterface = await QuickUsb.releaseInterface(interface);
print('releaseInterface $releaseInterface');
```

### Bulk transfer in/out

```dart
var bulkTransferIn = await QuickUsb.bulkTransferIn(endpoint, 1024, timeout: 2000);
print('bulkTransferIn ${hex.encode(bulkTransferIn)}');
// ...
var bulkTransferOut = await QuickUsb.bulkTransferOut(endpoint, data, timeout: 2000);
print('bulkTransferOut $bulkTransferOut');
```

### Set auto detach kernel driver

Enable/disable libusb's automatic kernel driver detachment on linux. When this is enabled libusb will automatically detach the kernel driver on an interface when claiming the interface, and attach it when releasing the interface.

Automatic kernel driver detachment is disabled on newly opened device handles by default.

This is supported only on linux, on other platforms this function does nothing.

```dart
await QuickUsb.setAutoDetachKernelDriver(true);
```
