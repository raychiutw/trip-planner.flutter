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

// iOS 的 XCUI accessibility tree 裡完全沒有 Flutter 的 Semantics 節點
// （issue #104，run 30175947137 的 dump 證實），所以原本「Flutter 掛旗標、
// 這裡輪詢 a11y label」的橋接不可行 —— 它從未觸發過任何一次手勢。
//
// 改用 Patrol 4.8.0 的 server extension（TriplineGestureExtension.swift）：
// automation server 跑在本行程內，Dart 端直接以 HTTP 請求手勢。
//
// server 在 +testInvocations 啟動，所以要在 +load 就把 extension 註冊進去。
@implementation RunnerUITests (TriplineNativeMapGestures)

+ (void)load {
  Class extensionClass = NSClassFromString(@"TriplineGestureExtension");
  if (extensionClass == Nil) {
    NSLog(@"Tripline: TriplineGestureExtension not found");
    return;
  }
  [PatrolServerExtensions registerExtensionClass:extensionClass];
  NSLog(@"Tripline: registered TriplineGestureExtension");
}

@end
