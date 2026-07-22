import 'package:patrol/patrol.dart';

import '../integration_test/support/app_flow_fixture.dart';
import 'support/ios_system_alerts.dart';

void main() {
  patrolTest('app-owned release flow stays off production services', ($) async {
    await dismissStaleSpringBoardTutorial($);
    await runAppOwnedReleaseFlow(
      $.tester,
      enterText: (finder, text) =>
          $.enterText(finder, text, hideKeyboard: false),
    );
  });
}
