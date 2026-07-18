import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS 與 Android CI 使用相同 build number 公式', () {
    final workflow = File('.github/workflows/mobile.yml').readAsStringSync();
    const formula = 'GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT';

    expect(formula.allMatches(workflow), hasLength(2));
    expect(workflow, isNot(contains('--build-number="\$GITHUB_RUN_ID"')));
  });
}
