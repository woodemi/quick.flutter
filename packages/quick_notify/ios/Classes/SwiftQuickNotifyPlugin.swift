import Flutter
import UIKit

public class SwiftQuickNotifyPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "quick_notify", binaryMessenger: registrar.messenger())
    let instance = SwiftQuickNotifyPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasPermission":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        result(settings.authorizationStatus != .denied)
      }
    case "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        result(granted)
      }
    case "notify":
      let args = call.arguments as! Dictionary<String, Any>
      let title = args["title"] as! String
      let content = args["content"] as! String

      let notification = UNMutableNotificationContent()
      notification.title = title
      notification.body = content
      let request = UNNotificationRequest(identifier: "quick_notify", content: notification, trigger: nil)
      UNUserNotificationCenter.current().add(request) { error in
        if (error != nil) {
          print("quick_notify error: \(error)")
        }
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
