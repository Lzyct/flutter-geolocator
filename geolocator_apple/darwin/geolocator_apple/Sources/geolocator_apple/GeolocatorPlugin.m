#import <CoreLocation/CoreLocation.h>
#import "./include/geolocator_apple/GeolocatorPlugin.h"
#import "./include/geolocator_apple/GeolocatorPlugin_Test.h"
#import "./include/geolocator_apple/Constants/ErrorCodes.h"
#import "./include/geolocator_apple/Handlers/GeolocationHandler.h"
#import "./include/geolocator_apple/Handlers/PermissionHandler.h"
#import "./include/geolocator_apple/Handlers/PositionStreamHandler.h"
#import "./include/geolocator_apple/Utils/ActivityTypeMapper.h"
#import "./include/geolocator_apple/Utils/AuthorizationStatusMapper.h"
#import "./include/geolocator_apple/Utils/LocationAccuracyMapper.h"
#import "./include/geolocator_apple/Utils/LocationDistanceMapper.h"
#import "./include/geolocator_apple/Utils/LocationMapper.h"
#import "./include/geolocator_apple/Utils/PermissionUtils.h"
#import "./include/geolocator_apple/Handlers/LocationAccuracyHandler.h"
#import "./include/geolocator_apple/Handlers/LocationServiceStreamHandler.h"

@interface GeolocatorPlugin ()

@property(strong, nonatomic, nonnull) GeolocationHandler *geolocationHandler;

@property(strong, nonatomic, nonnull) LocationAccuracyHandler *locationAccuracyHandler;

@property(strong, nonatomic, nonnull) PermissionHandler *permissionHandler;

@end

@implementation GeolocatorPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel *methodChannel = [FlutterMethodChannel
                                         methodChannelWithName:@"flutter.baseflow.com/geolocator_apple"
                                         binaryMessenger:registrar.messenger];
  FlutterEventChannel *positionUpdatesEventChannel = [FlutterEventChannel
                                                      eventChannelWithName:@"flutter.baseflow.com/geolocator_updates_apple"
                                                      binaryMessenger:registrar.messenger];

  FlutterEventChannel *locationServiceUpdatesEventChannel = [FlutterEventChannel eventChannelWithName:@"flutter.baseflow.com/geolocator_service_updates_apple" binaryMessenger:registrar.messenger];

  GeolocatorPlugin *instance = [[GeolocatorPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:methodChannel];

  PositionStreamHandler *positionStreamHandler = [[PositionStreamHandler alloc] initWithGeolocationHandler:instance.createGeolocationHandler];
  [positionUpdatesEventChannel setStreamHandler:positionStreamHandler];

  LocationServiceStreamHandler *locationServiceStreamHandler = [[LocationServiceStreamHandler alloc] init];
  [locationServiceUpdatesEventChannel setStreamHandler:locationServiceStreamHandler];

}

- (GeolocationHandler *) createGeolocationHandler {
  if (!self.geolocationHandler) {
    self.geolocationHandler = [[GeolocationHandler alloc] init];
  }
  return self.geolocationHandler;
}

- (void) setGeolocationHandlerOverride:(GeolocationHandler *)geolocationHandler {
  self.geolocationHandler = geolocationHandler;
}

- (LocationAccuracyHandler *) createLocationAccuracyHandler {
  if (!self.locationAccuracyHandler) {
    self.locationAccuracyHandler = [[LocationAccuracyHandler alloc] init];
  }
  return self.locationAccuracyHandler;
}

- (void) setLocationAccuracyHandlerOverride:(LocationAccuracyHandler *)locationAccuracyHandler {
  self.locationAccuracyHandler = locationAccuracyHandler;
}

- (PermissionHandler *) createPermissionHandler {
  if (!self.permissionHandler) {
    self.permissionHandler = [[PermissionHandler alloc] init];
  }
  return self.permissionHandler;
}

- (void) setPermissionHandlerOverride:(PermissionHandler *)permissionHandler {
  self.permissionHandler = permissionHandler;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"checkPermission" isEqualToString:call.method]) {
    [self onCheckPermission:result];
  } else if ([@"requestPermission" isEqualToString:call.method]) {
    [self onRequestPermission:result];
  } else if ([@"isLocationServiceEnabled" isEqualToString:call.method]) {
    [self onIsLocationServiceEnabled:result];
  } else if ([@"getLastKnownPosition" isEqualToString:call.method]) {
    [self onGetLastKnownPosition:result];
  } else if ([@"getCurrentPosition" isEqualToString:call.method]) {
    [self onGetCurrentPositionWithArguments:call.arguments
                                     result:result];
  } else if([@"getLocationAccuracy" isEqualToString:call.method]) {
    [[self createLocationAccuracyHandler] getLocationAccuracyWithResult:result];
  } else if([@"requestTemporaryFullAccuracy" isEqualToString:call.method]) {
    NSString* purposeKey = (NSString *)call.arguments[@"purposeKey"];
    [[self createLocationAccuracyHandler] requestTemporaryFullAccuracyWithResult:result
                                                                   purposeKey:purposeKey];
  } else if ([@"openAppSettings" isEqualToString:call.method]) {
    [self openSettings:result];
  } else if ([@"openLocationSettings" isEqualToString:call.method]) {
    [self openLocationSettings:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)onCheckPermission:(FlutterResult) result {
  CLAuthorizationStatus status = [[self createPermissionHandler] checkPermission];
  result([AuthorizationStatusMapper toDartIndex:status]);
}

- (void)onRequestPermission:(FlutterResult)result {
  [[self createPermissionHandler]
   requestPermission:^(CLAuthorizationStatus status) {
    result([AuthorizationStatusMapper toDartIndex:status]);
  }
   errorHandler:^(NSString *errorCode, NSString *errorDescription) {
    result([FlutterError errorWithCode: errorCode
                               message: errorDescription
                               details: nil]);
  }];
}

- (void)onIsLocationServiceEnabled:(FlutterResult)result {
  dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    BOOL isEnabled = [CLLocationManager locationServicesEnabled];
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        result([NSNumber numberWithBool:isEnabled]);
    });
  });
}

- (void)onGetLastKnownPosition:(FlutterResult)result {
  if (![[self createPermissionHandler] hasPermission]) {
    result([FlutterError errorWithCode: GeolocatorErrorPermissionDenied
                               message:@"User denied permissions to access the device's location."
                               details:nil]);
    return;
  }

  CLLocation *location = [self.createGeolocationHandler getLastKnownPosition];
  result([LocationMapper toDictionary:location]);
}

- (void)onGetCurrentPositionWithArguments:(id _Nullable)arguments
                                   result:(FlutterResult)result {
  if (![[self createPermissionHandler] hasPermission]) {
    result([FlutterError errorWithCode: GeolocatorErrorPermissionDenied
                               message:@"User denied permissions to access the device's location."
                               details:nil]);
    return;
  }

  CLLocationAccuracy accuracy = [LocationAccuracyMapper toCLLocationAccuracy:(NSNumber *)arguments[@"accuracy"]];
  GeolocationHandler *geolocationHandler = [self createGeolocationHandler];

  [geolocationHandler requestPositionWithDesiredAccuracy:accuracy
                                           resultHandler:^(CLLocation *location) {
    result([LocationMapper toDictionary:location]);
  }
                                            errorHandler:^(NSString *errorCode, NSString *errorDescription){
    result([FlutterError errorWithCode: errorCode
                               message: errorDescription
                               details: nil]);
  }];
}


- (void)openSettings:(FlutterResult)result {
#if TARGET_OS_OSX
  NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices";
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
  result([[NSNumber alloc] initWithBool:success]);
#else
  [[UIApplication sharedApplication]
   openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
   options:[[NSDictionary alloc] init]
   completionHandler:^(BOOL success) {
    result([[NSNumber alloc] initWithBool:success]);
  }];
#endif
}

- (void)openLocationSettings:(FlutterResult)result {
#if TARGET_OS_OSX
  NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices";
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
  result([[NSNumber alloc] initWithBool:success]);
#else
  // Try known Location Services URL schemes from newest to oldest.
  // Apple changed / restricted App-Prefs: across iOS versions so we cascade
  // through candidates and fall back to the app's own settings page as a last
  // resort (which still surfaces the per-app Location row).
  NSArray<NSString *> *candidates = @[
    @"App-Prefs:LOCATION_SERVICES",          // iOS 18+
    @"App-Prefs:root=Privacy&path=LOCATION_SERVICES", // iOS 16+ (Privacy & Security -> Location Services)
    @"App-Prefs:root=Privacy&path=LOCATION", // iOS 13–15 (Privacy -> Location Services)
    @"App-Prefs:Privacy&path=LOCATION",      // iOS 13–15 (short form)
    @"App-Prefs:root=Privacy",               // Fallback: Privacy & Security
    UIApplicationOpenSettingsURLString,      // final fallback: app settings
  ];
  [self tryOpenURLs:candidates atIndex:0 result:result];
#endif
}

#if !TARGET_OS_OSX
- (void)tryOpenURLs:(NSArray<NSString *> *)urls
            atIndex:(NSUInteger)index
             result:(FlutterResult)result {
  if (index >= urls.count) {
    result([[NSNumber alloc] initWithBool:NO]);
    return;
  }
  NSURL *url = [NSURL URLWithString:urls[index]];
  [[UIApplication sharedApplication]
   openURL:url
   options:[[NSDictionary alloc] init]
   completionHandler:^(BOOL success) {
    if (success) {
      result([[NSNumber alloc] initWithBool:YES]);
    } else {
      [self tryOpenURLs:urls atIndex:index + 1 result:result];
    }
  }];
}
#endif

@end
