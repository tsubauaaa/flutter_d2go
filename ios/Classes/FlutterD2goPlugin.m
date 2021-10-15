#import "FlutterD2goPlugin.h"
#if __has_include(<flutter_d2go/flutter_d2go-Swift.h>)
#import <flutter_d2go/flutter_d2go-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_d2go-Swift.h"
#endif

@implementation FlutterD2goPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterD2goPlugin registerWithRegistrar:registrar];
}
@end
