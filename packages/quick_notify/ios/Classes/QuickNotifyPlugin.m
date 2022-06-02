#import "QuickNotifyPlugin.h"
#if __has_include(<quick_notify/quick_notify-Swift.h>)
#import <quick_notify/quick_notify-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "quick_notify-Swift.h"
#endif

@implementation QuickNotifyPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftQuickNotifyPlugin registerWithRegistrar:registrar];
}
@end
