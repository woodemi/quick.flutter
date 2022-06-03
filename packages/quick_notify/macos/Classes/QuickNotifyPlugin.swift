import Cocoa
import FlutterMacOS
import UserNotifications

public class QuickNotifyPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "quick_notify", binaryMessenger: registrar.messenger)
    let instance = QuickNotifyPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasPermission":
      if #available(macOS 10.14, *) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          result(settings.authorizationStatus != .denied)
        }
      } else {
        result(true)
      }
    case "requestPermission":
      if #available(macOS 10.14, *) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
          result(granted)
        }
      } else {
        result(true)
      }
    case "notify":
      let args = call.arguments as! Dictionary<String, Any>
      let title = args["title"] as! String
      let content = args["content"] as! String

      if #available(macOS 10.14, *) {
        let notification = UNMutableNotificationContent()
        notification.title = title
        notification.body = content
        let request = UNNotificationRequest(identifier: "quick_notify", content: notification, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
          if (error != nil) {
            print("quick_notify error: \(error)")
          }
        }
      } else {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = content
        NSUserNotificationCenter.default.deliver(notification)
      }

      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
