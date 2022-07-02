import CoreBluetooth

#if os(iOS)
import Flutter
import UIKit
#elseif os(OSX)
import Cocoa
import FlutterMacOS
#endif

let GATT_HEADER_LENGTH = 3

let GSS_SUFFIX = "0000-1000-8000-00805f9b34fb"

extension CBUUID {
  public var uuidStr: String {
    get {
      uuidString.lowercased()
    }
  }
}

extension CBPeripheral {
  // FIXME https://forums.developer.apple.com/thread/84375
  public var uuid: UUID {
    get {
      value(forKey: "identifier") as! NSUUID as UUID
    }
  }

  public func getCharacteristic(_ characteristic: String, of service: String) -> CBCharacteristic? {
    let s = self.services?.first {
      $0.uuid.uuidStr == service || "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)" == service
    }
    let c = s?.characteristics?.first {
      $0.uuid.uuidStr == characteristic || "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)" == characteristic
    }
    return c
  }

  public func setNotifiable(_ bleInputProperty: String, for characteristic: String, of service: String) {
    guard let characteristic = getCharacteristic(characteristic, of: service) else{
        return
    }
    setNotifyValue(bleInputProperty != "disabled", for: characteristic)
  }
}

public class QuickBlueDarwin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #elseif os(OSX)
    let messenger = registrar.messenger
    #endif
    let method = FlutterMethodChannel(name: "quick_blue/method", binaryMessenger: messenger)
    let eventAvailabilityChange = FlutterEventChannel(name: "quick_blue/event.availabilityChange", binaryMessenger: messenger)
    let eventScanResult = FlutterEventChannel(name: "quick_blue/event.scanResult", binaryMessenger: messenger)
    let messageConnector = FlutterBasicMessageChannel(name: "quick_blue/message.connector", binaryMessenger: messenger)

    let instance = QuickBlueDarwin()
    registrar.addMethodCallDelegate(instance, channel: method)
    eventAvailabilityChange.setStreamHandler(instance)
    eventScanResult.setStreamHandler(instance)
    instance.messageConnector = messageConnector
  }

  private lazy var manager: CBCentralManager = { CBCentralManager(delegate: self, queue: nil) }()
  private var discoveredPeripherals = Dictionary<String, CBPeripheral>()

  private var availabilityChangeSink: FlutterEventSink?
  private var scanResultSink: FlutterEventSink?
  private var messageConnector: FlutterBasicMessageChannel!

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isBluetoothAvailable":
      result(manager.state == .poweredOn)
    case "startScan":
      manager.scanForPeripherals(withServices: nil)
      result(nil)
    case "stopScan":
      manager.stopScan()
      result(nil)
        case "connect":
      let arguments = call.arguments as! Dictionary<String, Any>
      let deviceId = arguments["deviceId"] as! String
      guard let peripheral = discoveredPeripherals[deviceId] else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown deviceId:\(deviceId)", details: nil))
        return
      }
      peripheral.delegate = self
      manager.connect(peripheral)
      result(nil)
    case "disconnect":
      let arguments = call.arguments as! Dictionary<String, Any>
      let deviceId = arguments["deviceId"] as! String
      guard let peripheral = discoveredPeripherals[deviceId] else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown deviceId:\(deviceId)", details: nil))
        return
      }
      if (peripheral.state != .disconnected) {
        manager.cancelPeripheralConnection(peripheral)
      }
      result(nil)
    case "discoverServices":
      let arguments = call.arguments as! Dictionary<String, Any>
      let deviceId = arguments["deviceId"] as! String
      guard let peripheral = discoveredPeripherals[deviceId] else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown deviceId:\(deviceId)", details: nil))
        return
      }
      peripheral.discoverServices(nil)
      result(nil)
    case "setNotifiable":
      let arguments = call.arguments as! Dictionary<String, Any>
      let deviceId = arguments["deviceId"] as! String
      let service = arguments["service"] as! String
      let characteristic = arguments["characteristic"] as! String
      let bleInputProperty = arguments["bleInputProperty"] as! String
      guard let peripheral = discoveredPeripherals[deviceId] else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown deviceId:\(deviceId)", details: nil))
        return
      }
      guard let c = peripheral.getCharacteristic(characteristic, of: service) else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown characteristic:\(characteristic)", details: nil))
        return
      }
      peripheral.setNotifyValue(bleInputProperty != "disabled", for: c)
      result(nil)
    case "readValue":
      let arguments = call.arguments as! Dictionary<String, Any>
      let deviceId = arguments["deviceId"] as! String
      let service = arguments["service"] as! String
      let characteristic = arguments["characteristic"] as! String
      guard let peripheral = discoveredPeripherals[deviceId] else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown deviceId:\(deviceId)", details: nil))
        return
      }
      guard let c = peripheral.getCharacteristic(characteristic, of: service) else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown characteristic:\(characteristic)", details: nil))
        return
      }
      peripheral.readValue(for: c)
      result(nil)
    case "writeValue":
      let arguments = call.arguments as! Dictionary<String, Any>
      let deviceId = arguments["deviceId"] as! String
      let service = arguments["service"] as! String
      let characteristic = arguments["characteristic"] as! String
      let value = arguments["value"] as! FlutterStandardTypedData
      let bleOutputProperty = arguments["bleOutputProperty"] as! String
      guard let peripheral = discoveredPeripherals[deviceId] else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown deviceId:\(deviceId)", details: nil))
        return
      }
      let type = bleOutputProperty == "withoutResponse" ? CBCharacteristicWriteType.withoutResponse : CBCharacteristicWriteType.withResponse
      guard let c = peripheral.getCharacteristic(characteristic, of: service) else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown characteristic:\(characteristic)", details: nil))
        return
      }
      peripheral.writeValue(value.data, for: c, type: type)
      result(nil)
    case "requestMtu":
      let arguments = call.arguments as! Dictionary<String, Any>
      let deviceId = arguments["deviceId"] as! String
      guard let peripheral = discoveredPeripherals[deviceId] else {
        result(FlutterError(code: "IllegalArgument", message: "Unknown deviceId:\(deviceId)", details: nil))
        return
      }
      result(nil)
      let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
      print("peripheral.maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse \(mtu)")
      messageConnector.sendMessage(["mtuConfig": mtu + GATT_HEADER_LENGTH])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension QuickBlueDarwin: CBCentralManagerDelegate {
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    availabilityChangeSink?(central.state.rawValue)
  }

  public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    print("centralManager:didDiscoverPeripheral \(peripheral.name ?? "nil") \(peripheral.uuid.uuidString)")
    discoveredPeripherals[peripheral.uuid.uuidString] = peripheral

    let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    scanResultSink?([
      "name": peripheral.name ?? "",
      "deviceId": peripheral.uuid.uuidString,
      "manufacturerData": FlutterStandardTypedData(bytes: manufacturerData ?? Data()),
      "rssi": RSSI,
    ])
  }

  public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("centralManager:didConnect \(peripheral.uuid.uuidString)")
    messageConnector.sendMessage([
      "deviceId": peripheral.uuid.uuidString,
      "ConnectionState": "connected",
    ])
  }
    
  public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    print("centralManager:didDisconnectPeripheral: \(peripheral.uuid.uuidString) error: \(String(describing: error))")
    messageConnector.sendMessage([
      "deviceId": peripheral.uuid.uuidString,
      "ConnectionState": "disconnected",
    ])
  }
}

extension QuickBlueDarwin: FlutterStreamHandler {
  open func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard let args = arguments as? Dictionary<String, Any>, let name = args["name"] as? String else {
      return nil
    }
    print("QuickBlueDarwin onListenWithArguments: \(name)")
    if name == "availabilityChange" {
      availabilityChangeSink = events
      availabilityChangeSink?(manager.state.rawValue) // Initializes CBCentralManager and returns the current state when hot restarting
    } else if name == "scanResult" {
      scanResultSink = events
    }
    return nil
  }

  open func onCancel(withArguments arguments: Any?) -> FlutterError? {
    guard let args = arguments as? Dictionary<String, Any>, let name = args["name"] as? String else {
      return nil
    }
    print("QuickBlueDarwin onCancelWithArguments: \(name)")
    if name == "availabilityChange" {
      availabilityChangeSink = nil
    } else if name == "scanResult" {
      scanResultSink = nil
    }
    return nil
  }
}

extension QuickBlueDarwin: CBPeripheralDelegate {
  public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    print("peripheral: \(peripheral.uuid.uuidString) didDiscoverServices error: \(String(describing: error))")
    for service in peripheral.services! {
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }
    
  public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    for characteristic in service.characteristics! {
      print("peripheral:didDiscoverCharacteristicsForService (\(service.uuid.uuidStr), \(characteristic.uuid.uuidStr)")
    }
    self.messageConnector.sendMessage([
      "deviceId": peripheral.uuid.uuidString,
      "ServiceState": "discovered",
      "service": service.uuid.uuidStr,
      "characteristics": service.characteristics!.map { $0.uuid.uuidStr }
    ])
  }

  public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    let data = characteristic.value as NSData?
    print("peripheral:didWriteValueForCharacteristic \(characteristic.uuid.uuidStr) \(String(describing: data)) error: \(String(describing: error))")
  }

  public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    let data = characteristic.value as NSData?
    print("peripheral:didUpdateValueForCharacteristic \(characteristic.uuid) \(String(describing: data)) error: \(String(describing: error))")
    self.messageConnector.sendMessage([
      "deviceId": peripheral.uuid.uuidString,
      "characteristicValue": [
        "characteristic": characteristic.uuid.uuidStr,
        "value": FlutterStandardTypedData(bytes: characteristic.value!)
      ]
    ])
  }
}
