@import ObjectiveC.runtime;
@import XCTest;
@import patrol;

#import <math.h>

// Patrol sets these macros during its build. Defaults keep the Xcode target
// compilable when a developer invokes build-for-testing directly.
#ifndef CLEAR_PERMISSIONS
#define CLEAR_PERMISSIONS 0
#endif
#ifndef FULL_ISOLATION
#define FULL_ISOLATION 0
#endif

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)

// Patrol 4.6.1 尚未提供 iOS pinch／rotate。Flutter 按鈕進入等待狀態後，
// 以 accessibility label 請求一次 XCUI 手勢，再由 Dart 驗證地圖鏡頭 callback。
static NSString *const TriplineMapLabel =
    @"Tripline native map evidence canvas";
static NSString *const TriplinePinchRequestLabel =
    @"Tripline native map pinch request";
static NSString *const TriplineRotateRequestLabel =
    @"Tripline native map rotate request";

@interface TriplineNativeMapGestureBridge : NSObject
@property(nonatomic, strong) XCUIApplication *app;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy, nullable) NSString *activeRequestLabel;
@end

@implementation TriplineNativeMapGestureBridge

- (instancetype)init {
  self = [super init];
  if (self) {
    _app = [[XCUIApplication alloc] init];
  }
  return self;
}

- (void)start {
  self.timer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                               target:self
                                             selector:@selector(poll:)
                                             userInfo:nil
                                              repeats:YES];
}

- (void)stop {
  [self.timer invalidate];
  self.timer = nil;
}

- (XCUIElement *)elementWithLabel:(NSString *)label {
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == %@", label];
  return [[self.app descendantsMatchingType:XCUIElementTypeAny]
      matchingPredicate:predicate]
      .firstMatch;
}

- (void)poll:(NSTimer *)timer {
  if (self.activeRequestLabel != nil) {
    if (![self elementWithLabel:self.activeRequestLabel].exists) {
      self.activeRequestLabel = nil;
    }
    return;
  }

  XCUIElement *pinchRequest = [self elementWithLabel:TriplinePinchRequestLabel];
  XCUIElement *rotateRequest = [self elementWithLabel:TriplineRotateRequestLabel];
  NSString *requestLabel = pinchRequest.exists
                               ? TriplinePinchRequestLabel
                               : (rotateRequest.exists ? TriplineRotateRequestLabel : nil);
  if (requestLabel == nil) return;

  XCUIElement *map = [self elementWithLabel:TriplineMapLabel];
  if (!map.exists) return;

  self.activeRequestLabel = requestLabel;
  if ([requestLabel isEqualToString:TriplinePinchRequestLabel]) {
    NSLog(@"Tripline native map bridge: pinch");
    [map pinchWithScale:2.0 velocity:1.0];
  } else {
    NSLog(@"Tripline native map bridge: rotate");
    [map rotate:M_PI_2 withVelocity:1.0];
  }
}

@end

static TriplineNativeMapGestureBridge *TriplineGestureBridge;

@implementation RunnerUITests (TriplineNativeMapGestures)

- (void)setUp {
  [super setUp];
  NSString *testName = NSStringFromSelector(self.invocation.selector);
  if (![testName containsString:@"native Google Map renders"]) return;
  TriplineGestureBridge = [[TriplineNativeMapGestureBridge alloc] init];
  [TriplineGestureBridge start];
}

- (void)tearDown {
  [TriplineGestureBridge stop];
  TriplineGestureBridge = nil;
  [super tearDown];
}

@end
