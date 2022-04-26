import Flutter

public class SwiftQuickBluePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    QuickBlueDarwin.register(with: registrar)
  }
}
