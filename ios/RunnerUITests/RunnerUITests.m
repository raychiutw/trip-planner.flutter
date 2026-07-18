@import ObjectiveC.runtime;
@import XCTest;
@import patrol;

// Patrol sets these macros during its build. Defaults keep the Xcode target
// compilable when a developer invokes build-for-testing directly.
#ifndef CLEAR_PERMISSIONS
#define CLEAR_PERMISSIONS 0
#endif
#ifndef FULL_ISOLATION
#define FULL_ISOLATION 0
#endif

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
