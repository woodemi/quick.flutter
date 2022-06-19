package com.example.quick_usb

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

private const val ACTION_USB_PERMISSION = "com.example.quick_usb.USB_PERMISSION"

private val pendingIntentFlag =
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
  } else {
    PendingIntent.FLAG_UPDATE_CURRENT
  }

private fun pendingPermissionIntent(context: Context) = PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION), pendingIntentFlag)

/** QuickUsbPlugin */
class QuickUsbPlugin : FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel

  private var applicationContext: Context? = null
  private var usbManager: UsbManager? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "quick_usb")
    channel.setMethodCallHandler(this)
    applicationContext = flutterPluginBinding.applicationContext
    usbManager = applicationContext?.getSystemService(Context.USB_SERVICE) as UsbManager
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    usbManager = null
    applicationContext = null
  }

  private var usbDevice: UsbDevice? = null
  private var usbDeviceConnection: UsbDeviceConnection? = null

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getDeviceList" -> {
        val manager = usbManager ?: return result.error("IllegalState", "usbManager null", null)
        val usbDeviceList = manager.deviceList.entries.map {
          mapOf(
            "identifier" to it.key,
            "vendorId" to it.value.vendorId,
            "productId" to it.value.productId,
            "configurationCount" to it.value.configurationCount,
          )
        }
        result.success(usbDeviceList)
      }
      "getDeviceDescription" -> {
        val context = applicationContext ?: return result.error("IllegalState", "applicationContext null", null)
        val manager = usbManager ?: return result.error("IllegalState", "usbManager null", null)
        val identifier = call.argument<Map<String, Any>>("device")!!["identifier"]!!;
        val device = manager.deviceList[identifier] ?: return result.error("IllegalState", "usbDevice null", null)
        val requestPermission = call.argument<Boolean>("requestPermission")!!;

        val hasPermission = manager.hasPermission(device)
        if (requestPermission && !hasPermission) {
          val permissionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
              context.unregisterReceiver(this)
              val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false);
              result.success(mapOf(
                "manufacturer" to device.manufacturerName,
                "product" to device.productName,
                "serialNumber" to if (granted) device.serialNumber else null,
              ))
            }
          }
          context.registerReceiver(permissionReceiver, IntentFilter(ACTION_USB_PERMISSION))
          manager.requestPermission(device, pendingPermissionIntent(context))
        } else {
          result.success(mapOf(
            "manufacturer" to device.manufacturerName,
            "product" to device.productName,
            "serialNumber" to if (hasPermission) device.serialNumber else null,
          ))
        }
      }
      "hasPermission" -> {
        val manager = usbManager ?: return result.error("IllegalState", "usbManager null", null)
        val identifier = call.argument<String>("identifier")
        val device = manager.deviceList[identifier]
        result.success(manager.hasPermission(device))
      }
      "requestPermission" -> {
        val context = applicationContext ?: return result.error("IllegalState", "applicationContext null", null)
        val manager = usbManager ?: return result.error("IllegalState", "usbManager null", null)
        val identifier = call.argument<String>("identifier")
        val device = manager.deviceList[identifier]
        if (manager.hasPermission(device)) {
          result.success(true)
        } else {
          val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
              context.unregisterReceiver(this)
              val usbDevice = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
              val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
              result.success(granted);
            }
          }
          context.registerReceiver(receiver, IntentFilter(ACTION_USB_PERMISSION))
          manager.requestPermission(device, pendingPermissionIntent(context))
        }
      }
      "openDevice" -> {
        val manager = usbManager ?: return result.error("IllegalState", "usbManager null", null)
        val identifier = call.argument<String>("identifier")
        usbDevice = manager.deviceList[identifier]
        usbDeviceConnection = manager.openDevice(usbDevice)
        result.success(true)
      }
      "closeDevice" -> {
        usbDeviceConnection?.close()
        usbDeviceConnection = null
        usbDevice = null
        result.success(null)
      }
      "getConfiguration" -> {
        val device = usbDevice ?: return result.error("IllegalState", "usbDevice null", null)
        val index = call.argument<Int>("index")!!
        val configuration = device.getConfiguration(index)
        val map = configuration.toMap() + ("index" to index)
        result.success(map)
      }
      "setConfiguration" -> {
        val device = usbDevice ?: return result.error("IllegalState", "usbDevice null", null)
        val connection = usbDeviceConnection ?: return result.error("IllegalState", "usbDeviceConnection null", null)
        val index = call.argument<Int>("index")!!
        val configuration = device.getConfiguration(index)
        result.success(connection.setConfiguration(configuration))
      }
      "claimInterface" -> {
        val device = usbDevice ?: return result.error("IllegalState", "usbDevice null", null)
        val connection = usbDeviceConnection ?: return result.error("IllegalState", "usbDeviceConnection null", null)
        val id = call.argument<Int>("id")!!
        val alternateSetting = call.argument<Int>("alternateSetting")!!
        val usbInterface = device.findInterface(id, alternateSetting)
        result.success(connection.claimInterface(usbInterface, true))
      }
      "releaseInterface" -> {
        val device = usbDevice ?: return result.error("IllegalState", "usbDevice null", null)
        val connection = usbDeviceConnection ?: return result.error("IllegalState", "usbDeviceConnection null", null)
        val id = call.argument<Int>("id")!!
        val alternateSetting = call.argument<Int>("alternateSetting")!!
        val usbInterface = device.findInterface(id, alternateSetting)
        result.success(connection.releaseInterface(usbInterface))
      }
      "bulkTransferIn" -> {
        val device = usbDevice ?: return result.error("IllegalState", "usbDevice null", null)
        val connection = usbDeviceConnection ?: return result.error(
          "IllegalState",
          "usbDeviceConnection null",
          null
        )
        val endpointMap = call.argument<Map<String, Any>>("endpoint")!!
        val maxLength = call.argument<Int>("maxLength")!!
        val endpoint =
          device.findEndpoint(endpointMap["endpointNumber"] as Int, endpointMap["direction"] as Int)
        val timeout = call.argument<Int>("timeout")!!

        // TODO Check [UsbDeviceConnection.bulkTransfer] API >= 28
        require(maxLength <= UsbRequest__MAX_USBFS_BUFFER_SIZE) { "Before 28, a value larger than 16384 bytes would be truncated down to 16384" }
        val buffer = ByteArray(maxLength)
        val actualLength = connection.bulkTransfer(endpoint, buffer, buffer.count(), timeout)
        if (actualLength < 0) {
          result.error("unknown", "bulkTransferIn error", null)
        } else {
          result.success(buffer.take(actualLength))
        }
      }
      "bulkTransferOut" -> {
        val device = usbDevice ?: return result.error("IllegalState", "usbDevice null", null)
        val connection = usbDeviceConnection ?: return result.error(
          "IllegalState",
          "usbDeviceConnection null",
          null
        )
        val endpointMap = call.argument<Map<String, Any>>("endpoint")!!
        val data = call.argument<ByteArray>("data")!!
        val timeout = call.argument<Int>("timeout")!!
        val endpoint =
          device.findEndpoint(endpointMap["endpointNumber"] as Int, endpointMap["direction"] as Int)

        // TODO Check [UsbDeviceConnection.bulkTransfer] API >= 28
        val dataSplit = data.asList()
          .windowed(UsbRequest__MAX_USBFS_BUFFER_SIZE, UsbRequest__MAX_USBFS_BUFFER_SIZE, true)
          .map { it.toByteArray() }
        var sum: Int? = null
        for (bytes in dataSplit) {
          val actualLength = connection.bulkTransfer(endpoint, bytes, bytes.count(), timeout)
          if (actualLength < 0) break
          sum = (sum ?: 0) + actualLength
        }
        if (sum == null) {
          result.error("unknown", "bulkTransferOut error", null)
        } else {
          result.success(sum)
        }
      }
      else -> result.notImplemented()
    }
  }
}

fun UsbDevice.findInterface(id: Int, alternateSetting: Int): UsbInterface? {
  for (i in 0..interfaceCount) {
    val usbInterface = getInterface(i)
    if (usbInterface.id == id && usbInterface.alternateSetting == alternateSetting) {
      return usbInterface
    }
  }
  return null
}

fun UsbDevice.findEndpoint(endpointNumber: Int, direction: Int): UsbEndpoint? {
  for (i in 0..interfaceCount) {
    val usbInterface = getInterface(i)
    for (j in 0..usbInterface.endpointCount) {
      val endpoint = usbInterface.getEndpoint(j)
      if (endpoint.endpointNumber == endpointNumber && endpoint.direction == direction) {
        return endpoint
      }
    }
  }
  return null
}

/** [UsbRequest.MAX_USBFS_BUFFER_SIZE] */
val UsbRequest__MAX_USBFS_BUFFER_SIZE = 16384

fun UsbConfiguration.toMap() = mapOf(
  "id" to id,
  "interfaces" to List(interfaceCount) { getInterface(it).toMap() }
)

fun UsbInterface.toMap() = mapOf(
  "id" to id,
  "alternateSetting" to alternateSetting,
  "endpoints" to List(endpointCount) { getEndpoint(it).toMap() }
)

fun UsbEndpoint.toMap() = mapOf(
        "endpointNumber" to endpointNumber,
        "direction" to direction
)
