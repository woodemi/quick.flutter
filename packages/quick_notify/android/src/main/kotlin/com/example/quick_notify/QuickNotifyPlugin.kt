package com.example.quick_notify

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** QuickNotifyPlugin */
class QuickNotifyPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  private lateinit var applicationContext: Context

  private lateinit var notificationManager: NotificationManager

  private final var channelCreated: Boolean = false

  private val channelProps = object {
    var id = "quick_notify"
    var name = "quick_notify"
    var importance = NotificationManager.IMPORTANCE_DEFAULT
  }

  private fun createChannel(){
    if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O){
      notificationManager.createNotificationChannel(NotificationChannel(channelProps.id, channelProps.name, channelProps.importance))
      channelCreated = true
    }
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "quick_notify")
    channel.setMethodCallHandler(this)
    applicationContext = flutterPluginBinding.applicationContext
    notificationManager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (notificationManager.areNotificationsEnabled()) createChannel()
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "hasPermission") {
      if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.S) {
        result.success(true)
      } else {
        // TODO Android 13 notification permission
        result.notImplemented()
      }
    } else if (call.method == "requestPermission") {
      if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.S) {
        result.success(true)
      } else {
        // TODO Android 13 notification permission
        result.notImplemented()
      }
    } else if (call.method == "notify") {
      if(!channelCreated) createChannel()

      val args = call.arguments as Map<String, Any>
      val title = args["title"] as String
      val content = args["content"] as String

      val smallIconRes = applicationContext.resources.getIdentifier(
        "ic_quick_notify",
        "drawable",
        applicationContext.packageName
      )
      val notification = NotificationCompat.Builder(applicationContext, channelProps.id)
        .setSmallIcon(smallIconRes)
        .setContentTitle(title)
        .setContentText(content)
        .build()
      notificationManager.notify(0, notification)
      result.success(null)
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
