import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/app_flow_fixture.dart';

void main() {
  testWidgets('app-owned release flow completes on the host runner', (
    tester,
  ) async {
    final textEntries = <({Key? key, String text})>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await runAppOwnedReleaseFlow(
      tester,
      enterText: (finder, text) async {
        textEntries.add((key: finder.evaluate().single.widget.key, text: text));
        await tester.enterText(finder, text);
      },
    );
    expect(textEntries, [
      (key: const ValueKey('login-email-field'), text: 'ray@example.com'),
      (key: const ValueKey('login-password-field'), text: 'secret'),
      (key: const ValueKey('chat-input'), text: 'device smoke draft'),
      (key: const ValueKey('favorites-search-input'), text: '牧志'),
      (key: const ValueKey('favorites-search-input'), text: ''),
    ]);
  });
}
