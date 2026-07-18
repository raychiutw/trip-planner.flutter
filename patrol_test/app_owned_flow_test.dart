import 'package:patrol/patrol.dart';

import '../integration_test/support/app_flow_fixture.dart';

void main() {
  patrolTest('app-owned release flow stays off production services', ($) async {
    await runAppOwnedReleaseFlow($.tester);
  });
}
