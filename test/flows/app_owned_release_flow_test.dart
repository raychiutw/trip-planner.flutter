import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/app_flow_fixture.dart';

void main() {
  testWidgets('app-owned release flow completes on the host runner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await runAppOwnedReleaseFlow(tester);
  });
}
