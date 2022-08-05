#import "QuickWlanPlugin.h"
#if __has_include(<quick_wlan/quick_wlan-Swift.h>)
#import <quick_wlan/quick_wlan-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "quick_wlan-Swift.h"
#endif

@implementation QuickWlanPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftQuickWlanPlugin registerWithRegistrar:registrar];
}
@end
