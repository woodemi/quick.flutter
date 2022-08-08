#include "include/quick_blue/quick_blue_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>

#include <flutter/method_channel.h>
#include <flutter/basic_message_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/standard_message_codec.h>

#include <map>
#include <memory>
#include <sstream>
#include <algorithm>
#include <iomanip>

#define GUID_FORMAT "%08x-%04hx-%04hx-%02hhx%02hhx-%02hhx%02hhx%02hhx%02hhx%02hhx%02hhx"
#define GUID_ARG(guid) guid.Data1, guid.Data2, guid.Data3, guid.Data4[0], guid.Data4[1], guid.Data4[2], guid.Data4[3], guid.Data4[4], guid.Data4[5], guid.Data4[6], guid.Data4[7]

namespace {

using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Foundation::Collections;
using namespace winrt::Windows::Storage::Streams;
using namespace winrt::Windows::Devices::Radios;
using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;

using flutter::EncodableValue;
using flutter::EncodableMap;
using flutter::EncodableList;

union uint16_t_union {
  uint16_t uint16;
  byte bytes[sizeof(uint16_t)];
};

std::vector<uint8_t> to_bytevc(IBuffer buffer) {
  auto reader = DataReader::FromBuffer(buffer);
  auto result = std::vector<uint8_t>(reader.UnconsumedBufferLength());
  reader.ReadBytes(result);
  return result;
}

IBuffer from_bytevc(std::vector<uint8_t> bytes) {
  auto writer = DataWriter();
  writer.WriteBytes(bytes);
  return writer.DetachBuffer();
}

std::string to_hexstring(std::vector<uint8_t> bytes) {
  auto ss = std::stringstream();
  for (auto b : bytes)
      ss << std::setw(2) << std::setfill('0') << std::hex << static_cast<int>(b);
  return ss.str();
}

std::string to_uuidstr(winrt::guid guid) {
  char chars[36 + 1];
  sprintf_s(chars, GUID_FORMAT, GUID_ARG(guid));
  return std::string{ chars };
}

struct BluetoothDeviceAgent {
  BluetoothLEDevice device;
  winrt::event_token connnectionStatusChangedToken;
  std::map<std::string, GattDeviceService> gattServices;
  std::map<std::string, GattCharacteristic> gattCharacteristics;
  std::map<std::string, winrt::event_token> valueChangedTokens;

  BluetoothDeviceAgent(BluetoothLEDevice device, winrt::event_token connnectionStatusChangedToken)
      : device(device),
        connnectionStatusChangedToken(connnectionStatusChangedToken) {}

  ~BluetoothDeviceAgent() {
    device = nullptr;
  }

  IAsyncOperation<GattDeviceService> GetServiceAsync(std::string service) {
    if (gattServices.count(service) == 0) {
      auto serviceResult = co_await device.GetGattServicesAsync();
      if (serviceResult.Status() != GattCommunicationStatus::Success)
        co_return nullptr;

      for (auto s : serviceResult.Services())
        if (to_uuidstr(s.Uuid()) == service)
          gattServices.insert(std::make_pair(service, s));
    }
    co_return gattServices.at(service);
  }

  IAsyncOperation<GattCharacteristic> GetCharacteristicAsync(std::string service, std::string characteristic) {
    if (gattCharacteristics.count(characteristic) == 0) {
      auto gattService = co_await GetServiceAsync(service);

      auto characteristicResult = co_await gattService.GetCharacteristicsAsync();
      if (characteristicResult.Status() != GattCommunicationStatus::Success)
        co_return nullptr;

      for (auto c : characteristicResult.Characteristics())
        if (to_uuidstr(c.Uuid()) == characteristic)
          gattCharacteristics.insert(std::make_pair(characteristic, c));
    }
    co_return gattCharacteristics.at(characteristic);
  }
};

class QuickBluePlugin : public flutter::Plugin, public flutter::StreamHandler<EncodableValue> {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  QuickBluePlugin();

  virtual ~QuickBluePlugin();

 private:
   winrt::fire_and_forget InitializeAsync();

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::StreamHandlerError<>> OnListenInternal(
      const EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<>>&& events) override;
  std::unique_ptr<flutter::StreamHandlerError<>> OnCancelInternal(
      const EncodableValue* arguments) override;

  std::unique_ptr<flutter::BasicMessageChannel<EncodableValue>> message_connector_;

  std::unique_ptr<flutter::EventSink<EncodableValue>> availability_change_sink_;
  std::unique_ptr<flutter::EventSink<EncodableValue>> scan_result_sink_;

  Radio bluetoothRadio{ nullptr };
  void Radio_StateChanged(Radio sender, IInspectable args);
  RadioState oldRadioState = RadioState::Unknown;

  BluetoothLEAdvertisementWatcher bluetoothLEWatcher{ nullptr };
  winrt::event_token bluetoothLEWatcherReceivedToken;
  winrt::fire_and_forget BluetoothLEWatcher_Received(BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args);

  std::map<uint64_t, std::unique_ptr<BluetoothDeviceAgent>> connectedDevices{};
  winrt::event_revoker<IRadio> radioStateChangedRevoker;

  winrt::fire_and_forget ConnectAsync(uint64_t bluetoothAddress);
  void BluetoothLEDevice_ConnectionStatusChanged(BluetoothLEDevice sender, IInspectable args);
  void CleanConnection(uint64_t bluetoothAddress);
  winrt::fire_and_forget DiscoverServicesAsync(BluetoothDeviceAgent &bluetoothDeviceAgent);

  winrt::fire_and_forget SetNotifiableAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, GattCharacteristic& gattCharacteristic, std::string bleInputProperty);
  winrt::fire_and_forget RequestMtuAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, uint64_t expectedMtu);
  winrt::fire_and_forget ReadValueAsync(GattCharacteristic& gattCharacteristic);
  winrt::fire_and_forget WriteValueAsync(GattCharacteristic& gattCharacteristic, std::vector<uint8_t> value, std::string bleOutputProperty);
  void QuickBluePlugin::GattCharacteristic_ValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args);
};

// static
void QuickBluePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto method =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), "quick_blue/method",
          &flutter::StandardMethodCodec::GetInstance());
  auto event_availability_change =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          registrar->messenger(), "quick_blue/event.availabilityChange",
          &flutter::StandardMethodCodec::GetInstance());        
  auto event_scan_result =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          registrar->messenger(), "quick_blue/event.scanResult",
          &flutter::StandardMethodCodec::GetInstance());
  auto message_connector_ =
      std::make_unique<flutter::BasicMessageChannel<EncodableValue>>(
          registrar->messenger(), "quick_blue/message.connector",
          &flutter::StandardMessageCodec::GetInstance());

  auto plugin = std::make_unique<QuickBluePlugin>();

  method->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto availability_handler = std::make_unique<
      flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnListen(arguments, std::move(events));
      },
      [plugin_pointer = plugin.get()](const EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnCancel(arguments);
      });    
  auto scan_result_handler = std::make_unique<
      flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnListen(arguments, std::move(events));
      },
      [plugin_pointer = plugin.get()](const EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnCancel(arguments);
      });    
  event_availability_change->SetStreamHandler(std::move(availability_handler));    
  event_scan_result->SetStreamHandler(std::move(scan_result_handler));
  plugin->message_connector_ = std::move(message_connector_);

  registrar->AddPlugin(std::move(plugin));
}

QuickBluePlugin::QuickBluePlugin() {
  InitializeAsync();
}

QuickBluePlugin::~QuickBluePlugin() {}

winrt::fire_and_forget QuickBluePlugin::InitializeAsync() {
  auto bluetoothAdapter = co_await BluetoothAdapter::GetDefaultAsync();
  bluetoothRadio = co_await bluetoothAdapter.GetRadioAsync();
  if (bluetoothRadio) {
    radioStateChangedRevoker = bluetoothRadio.StateChanged(winrt::auto_revoke, { this, &QuickBluePlugin::Radio_StateChanged });
  }
}

void QuickBluePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto method_name = method_call.method_name();
  OutputDebugString((L"HandleMethodCall " + winrt::to_hstring(method_name) + L"\n").c_str());
  if (method_name.compare("isBluetoothAvailable") == 0) {
    result->Success(EncodableValue(bluetoothRadio && bluetoothRadio.State() == RadioState::On));
  } else if (method_name.compare("startScan") == 0) {
    if (bluetoothRadio && bluetoothRadio.State() == RadioState::On) {
      if (!bluetoothLEWatcher) {
        bluetoothLEWatcher = BluetoothLEAdvertisementWatcher();
        bluetoothLEWatcherReceivedToken = bluetoothLEWatcher.Received({ this, &QuickBluePlugin::BluetoothLEWatcher_Received });
      }
      bluetoothLEWatcher.Start();
      result->Success(nullptr);
    } else {
      result->Error("IllegalState", "Bluetooth unavailable");
    }
  } else if (method_name.compare("stopScan") == 0) {
    if (bluetoothRadio && bluetoothRadio.State() == RadioState::On) {
      if (bluetoothLEWatcher) {
        bluetoothLEWatcher.Stop();
        bluetoothLEWatcher.Received(bluetoothLEWatcherReceivedToken);
      }
      bluetoothLEWatcher = nullptr;
      result->Success(nullptr);
    } else {
      result->Error("IllegalState", "Bluetooth unavailable");
    }
  } else if (method_name.compare("connect") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    ConnectAsync(std::stoull(deviceId));
    result->Success(nullptr);
  } else if (method_name.compare("disconnect") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    CleanConnection(std::stoull(deviceId));
    // TODO send `disconnected` message
    result->Success(nullptr);
  } else if (method_name.compare("discoverServices") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }
    DiscoverServicesAsync(*it->second);
    result->Success(nullptr);
  } else if (method_name.compare("setNotifiable") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto service = std::get<std::string>(args[EncodableValue("service")]);
    auto characteristic = std::get<std::string>(args[EncodableValue("characteristic")]);
    auto bleInputProperty = std::get<std::string>(args[EncodableValue("bleInputProperty")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    auto bluetoothAgent = *it->second;
    auto async_c = bluetoothAgent.GetCharacteristicAsync(service, characteristic);
    async_c.Completed([&, result_pointer = result.get()]
        (IAsyncOperation<GattCharacteristic> const& sender, AsyncStatus const args) {
          // FIXME https://github.com/woodemi/quick.flutter/pull/31#issuecomment-1159213902
          auto c = sender.GetResults();
          if (c == nullptr) {
            result_pointer->Error("IllegalArgument", "Unknown characteristic:" + characteristic);
            return;
          }
          SetNotifiableAsync(bluetoothAgent, c, bleInputProperty);
          result_pointer->Success(nullptr);
        });
  } else if (method_name.compare("readValue") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto service = std::get<std::string>(args[EncodableValue("service")]);
    auto characteristic = std::get<std::string>(args[EncodableValue("characteristic")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    auto bluetoothAgent = *it->second;
    auto async_c = bluetoothAgent.GetCharacteristicAsync(service, characteristic);
    async_c.Completed([&, result_pointer = result.get()]
        (IAsyncOperation<GattCharacteristic> const& sender, AsyncStatus const args) {
          // FIXME https://github.com/woodemi/quick.flutter/pull/31#issuecomment-1159213902
          auto c = sender.GetResults();
          if (c == nullptr) {
            result_pointer->Error("IllegalArgument", "Unknown characteristic:" + characteristic);
            return;
          }
          ReadValueAsync(c);
          result_pointer->Success(nullptr);
        });
  } else if (method_name.compare("writeValue") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto service = std::get<std::string>(args[EncodableValue("service")]);
    auto characteristic = std::get<std::string>(args[EncodableValue("characteristic")]);
    auto value = std::get<std::vector<uint8_t>>(args[EncodableValue("value")]);
    auto bleOutputProperty = std::get<std::string>(args[EncodableValue("bleOutputProperty")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    auto bluetoothAgent = *it->second;
    auto async_c = bluetoothAgent.GetCharacteristicAsync(service, characteristic);
    async_c.Completed([&, result_pointer = result.get()]
        (IAsyncOperation<GattCharacteristic> const& sender, AsyncStatus const args) {
          // FIXME https://github.com/woodemi/quick.flutter/pull/31#issuecomment-1159213902
          auto c = sender.GetResults();
          if (c == nullptr) {
            result_pointer->Error("IllegalArgument", "Unknown characteristic:" + characteristic);
            return;
          }
          WriteValueAsync(c, value, bleOutputProperty);
          result_pointer->Success(nullptr);
        });
  } else if (method_name.compare("requestMtu") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto expectedMtu = std::get<int32_t>(args[EncodableValue("expectedMtu")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    RequestMtuAsync(*it->second, expectedMtu);
    result->Success(nullptr);
  } else {
    result->NotImplemented();
  }
}

std::vector<uint8_t> parseManufacturerDataHead(BluetoothLEAdvertisement advertisement)
{
  if (advertisement.ManufacturerData().Size() == 0)
    return std::vector<uint8_t>();

  auto manufacturerData = advertisement.ManufacturerData().GetAt(0);
  // FIXME Compat with REG_DWORD_BIG_ENDIAN
  uint8_t* prefix = uint16_t_union{ manufacturerData.CompanyId() }.bytes;
  auto result = std::vector<uint8_t>{ prefix, prefix + sizeof(uint16_t_union) };

  auto data = to_bytevc(manufacturerData.Data());
  result.insert(result.end(), data.begin(), data.end());
  return result;
}

enum class AvailabilityState : int {
  unknown = 0,
  resetting = 1,
  unsupported = 2,
  unauthorized = 3,
  poweredOff = 4,
  poweredOn = 5,
};

void QuickBluePlugin::Radio_StateChanged(Radio radio, IInspectable args) {
  auto radioState = !radio ? RadioState::Disabled : radio.State();
  // FIXME https://stackoverflow.com/questions/66099947/bluetooth-radio-statechanged-event-fires-twice/67723902#67723902
  if (oldRadioState == radioState) {
    return;
  }
  oldRadioState = radioState;

  auto state = [=]() -> AvailabilityState {
    if (radioState == RadioState::Unknown) {
      return AvailabilityState::unknown;
    } else if (radioState == RadioState::Off) {
      return AvailabilityState::poweredOff;
    } else if (radioState == RadioState::On) {
      return AvailabilityState::poweredOn;
    } else if (radioState == RadioState::Disabled) {
      return AvailabilityState::unsupported;
    } else {
      return AvailabilityState::unknown;
    }
  }();

  if (availability_change_sink_) {
    availability_change_sink_->Success(static_cast<int>(state));
  }
}

winrt::fire_and_forget QuickBluePlugin::BluetoothLEWatcher_Received(
    BluetoothLEAdvertisementWatcher sender,
    BluetoothLEAdvertisementReceivedEventArgs args) {
  auto device = co_await BluetoothLEDevice::FromBluetoothAddressAsync(args.BluetoothAddress());
  auto name = device ? device.Name() : args.Advertisement().LocalName();
  OutputDebugString((L"Received BluetoothAddress:" + winrt::to_hstring(args.BluetoothAddress())
    + L", Name:" + name + L", LocalName:" + args.Advertisement().LocalName() + L"\n").c_str());
  if (scan_result_sink_) {
    scan_result_sink_->Success(EncodableMap{
      {"name", winrt::to_string(name)},
      {"deviceId", std::to_string(args.BluetoothAddress())},
      {"manufacturerDataHead", parseManufacturerDataHead(args.Advertisement())},
      {"rssi", args.RawSignalStrengthInDBm()},
    });
  }
}

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> QuickBluePlugin::OnListenInternal(
    const EncodableValue* arguments, std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
{
  if (arguments == nullptr) {
    return nullptr;
  }
  auto args = std::get<EncodableMap>(*arguments);
  auto name = std::get<std::string>(args[EncodableValue("name")]);
  if (name.compare("availabilityChange") == 0) {
    availability_change_sink_ = std::move(events);
    Radio_StateChanged(bluetoothRadio, nullptr);
  } else if (name.compare("scanResult") == 0) {
    scan_result_sink_ = std::move(events);
  }
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> QuickBluePlugin::OnCancelInternal(
    const EncodableValue* arguments)
{
  if (arguments == nullptr) {
    return nullptr;
  }
  auto args = std::get<EncodableMap>(*arguments);
  auto name = std::get<std::string>(args[EncodableValue("name")]);
  if (name.compare("availabilityChange") == 0) {
    availability_change_sink_ = nullptr;
  } else if (name.compare("scanResult") == 0) {
      scan_result_sink_ = nullptr;
  }
  return nullptr;
}

winrt::fire_and_forget QuickBluePlugin::ConnectAsync(uint64_t bluetoothAddress) {
  auto device = co_await BluetoothLEDevice::FromBluetoothAddressAsync(bluetoothAddress);
  auto servicesResult = co_await device.GetGattServicesAsync();
  if (servicesResult.Status() != GattCommunicationStatus::Success) {
    OutputDebugString((L"GetGattServicesAsync error: " + winrt::to_hstring((int32_t)servicesResult.Status()) + L"\n").c_str());
    message_connector_->Send(EncodableMap{
      {"deviceId", std::to_string(bluetoothAddress)},
      {"ConnectionState", "disconnected"},
    });
    co_return;
  }
  auto connnectionStatusChangedToken = device.ConnectionStatusChanged({ this, &QuickBluePlugin::BluetoothLEDevice_ConnectionStatusChanged });
  auto deviceAgent = std::make_unique<BluetoothDeviceAgent>(device, connnectionStatusChangedToken);
  auto pair = std::make_pair(bluetoothAddress, std::move(deviceAgent));
  connectedDevices.insert(std::move(pair));

  message_connector_->Send(EncodableMap{
    {"deviceId", std::to_string(bluetoothAddress)},
    {"ConnectionState", "connected"},
  });
}

void QuickBluePlugin::BluetoothLEDevice_ConnectionStatusChanged(BluetoothLEDevice sender, IInspectable args) {
  OutputDebugString((L"ConnectionStatusChanged " + winrt::to_hstring((int32_t)sender.ConnectionStatus()) + L"\n").c_str());
  if (sender.ConnectionStatus() == BluetoothConnectionStatus::Disconnected) {
    CleanConnection(sender.BluetoothAddress());
    message_connector_->Send(EncodableMap{
      {"deviceId", std::to_string(sender.BluetoothAddress())},
      {"ConnectionState", "disconnected"},
    });
  }
}

void QuickBluePlugin::CleanConnection(uint64_t bluetoothAddress) {
  auto node = connectedDevices.extract(bluetoothAddress);
  if (!node.empty()) {
    auto deviceAgent = std::move(node.mapped());
    deviceAgent->device.ConnectionStatusChanged(deviceAgent->connnectionStatusChangedToken);
    for (auto& tokenPair : deviceAgent->valueChangedTokens) {
      deviceAgent->gattCharacteristics.at(tokenPair.first).ValueChanged(tokenPair.second);
    }
  }
}

winrt::fire_and_forget QuickBluePlugin::DiscoverServicesAsync(BluetoothDeviceAgent &bluetoothDeviceAgent) {
  auto serviceResult = co_await bluetoothDeviceAgent.device.GetGattServicesAsync();
  if (serviceResult.Status() != GattCommunicationStatus::Success) {
    message_connector_->Send(
      EncodableMap{
        {"deviceId", std::to_string(bluetoothDeviceAgent.device.BluetoothAddress())},
        {"ServiceState", "discovered"}
      }
    );
    co_return;
  }

  for (auto s : serviceResult.Services()) {
    auto characteristicResult = co_await s.GetCharacteristicsAsync();
    auto msg = EncodableMap{
      {"deviceId", std::to_string(bluetoothDeviceAgent.device.BluetoothAddress())},
      {"ServiceState", "discovered"},
      {"service", to_uuidstr(s.Uuid())}
    };
    if (characteristicResult.Status() == GattCommunicationStatus::Success) {
      EncodableList characteristics;
      for (auto c : characteristicResult.Characteristics()) {
        characteristics.push_back(to_uuidstr(c.Uuid()));
      }
      msg.insert({"characteristics", characteristics});
    }
    message_connector_->Send(msg);
  }
}

winrt::fire_and_forget QuickBluePlugin::RequestMtuAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, uint64_t expectedMtu) {
  OutputDebugString(L"RequestMtuAsync expectedMtu");
  auto gattSession = co_await GattSession::FromDeviceIdAsync(bluetoothDeviceAgent.device.BluetoothDeviceId());
  message_connector_->Send(EncodableMap{
    {"mtuConfig", (int64_t)gattSession.MaxPduSize()},
  });
}

winrt::fire_and_forget QuickBluePlugin::SetNotifiableAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, GattCharacteristic& gattCharacteristic, std::string bleInputProperty) {
  auto descriptorValue = bleInputProperty == "notification" ? GattClientCharacteristicConfigurationDescriptorValue::Notify
    : bleInputProperty == "indication" ? GattClientCharacteristicConfigurationDescriptorValue::Indicate
    : GattClientCharacteristicConfigurationDescriptorValue::None;
  auto writeDescriptorStatus = co_await gattCharacteristic.WriteClientCharacteristicConfigurationDescriptorAsync(descriptorValue);
  if (writeDescriptorStatus != GattCommunicationStatus::Success)
    OutputDebugString((L"WriteClientCharacteristicConfigurationDescriptorAsync " + winrt::to_hstring((int32_t)writeDescriptorStatus) + L"\n").c_str());

  auto uuid = to_uuidstr(gattCharacteristic.Uuid());
  if (bleInputProperty != "disabled") {
    bluetoothDeviceAgent.valueChangedTokens[uuid] = gattCharacteristic.ValueChanged({ this, &QuickBluePlugin::GattCharacteristic_ValueChanged });
  } else {
    gattCharacteristic.ValueChanged(std::exchange(bluetoothDeviceAgent.valueChangedTokens[uuid], {}));
  }
}

winrt::fire_and_forget QuickBluePlugin::ReadValueAsync(GattCharacteristic& gattCharacteristic) {
  auto readValueResult = co_await gattCharacteristic.ReadValueAsync();
  auto uuid = to_uuidstr(gattCharacteristic.Uuid());
  auto bytes = to_bytevc(readValueResult.Value());
  OutputDebugString((L"ReadValueAsync " + winrt::to_hstring(uuid) + L", " + winrt::to_hstring(to_hexstring(bytes)) + L"\n").c_str());
  message_connector_->Send(EncodableMap{
    {"deviceId", std::to_string(gattCharacteristic.Service().Device().BluetoothAddress())},
    {"characteristicValue", EncodableMap{
      {"characteristic", uuid},
      {"value", bytes},
    }},
  });
}

winrt::fire_and_forget QuickBluePlugin::WriteValueAsync(GattCharacteristic& gattCharacteristic, std::vector<uint8_t> value, std::string bleOutputProperty) {
  auto writeOption = bleOutputProperty.compare("withoutResponse") == 0 ? GattWriteOption::WriteWithoutResponse : GattWriteOption::WriteWithResponse;
  auto writeValueStatus = co_await gattCharacteristic.WriteValueAsync(from_bytevc(value), writeOption);
  auto uuid = to_uuidstr(gattCharacteristic.Uuid());
  OutputDebugString((L"WriteValueAsync " + winrt::to_hstring(uuid) + L", " + winrt::to_hstring(to_hexstring(value)) + L", " + winrt::to_hstring((int32_t)writeValueStatus) + L"\n").c_str());
}

void QuickBluePlugin::GattCharacteristic_ValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args) {
  auto uuid = to_uuidstr(sender.Uuid());
  auto bytes = to_bytevc(args.CharacteristicValue());
  OutputDebugString((L"GattCharacteristic_ValueChanged " + winrt::to_hstring(uuid) + L", " + winrt::to_hstring(to_hexstring(bytes)) + L"\n").c_str());
  message_connector_->Send(EncodableMap{
    {"deviceId", std::to_string(sender.Service().Device().BluetoothAddress())},
    {"characteristicValue", EncodableMap{
      {"characteristic", uuid},
      {"value", bytes},
    }},
  });
}

}  // namespace

void QuickBluePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  QuickBluePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
