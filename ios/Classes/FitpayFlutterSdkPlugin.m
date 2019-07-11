#import "FitpayFlutterSdkPlugin.h"
#import <fitpay_flutter_sdk/fitpay_flutter_sdk-Swift.h>

@implementation FitpayFlutterSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFitpayFlutterSdkPlugin registerWithRegistrar:registrar];
}
@end
