#import "QuickScanPlugin.h"
#if __has_include(<quick_scan/quick_scan-Swift.h>)
#import <quick_scan/quick_scan-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "quick_scan-Swift.h"
#endif

@implementation QuickScanPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftQuickScanPlugin registerWithRegistrar:registrar];
}
@end
