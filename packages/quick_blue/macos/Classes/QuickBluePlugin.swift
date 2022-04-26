import Cocoa
import FlutterMacOS

public class QuickBluePlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    QuickBlueDarwin.register(with: registrar)
  }
}
