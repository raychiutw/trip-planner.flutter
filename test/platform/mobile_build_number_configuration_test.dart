import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS 與 Android CI 使用相同 build number 公式', () {
    final workflow = File('.github/workflows/mobile.yml').readAsStringSync();
    const formula = 'GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT';

    expect(formula.allMatches(workflow), hasLength(2));
    expect(workflow, isNot(contains('--build-number="\$GITHUB_RUN_ID"')));
  });

  test('共用較小 build number 前已離開舊 TestFlight train且版本一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)\+',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    final releaseVersion = File('VERSION').readAsStringSync().trim();
    final changelog = File('CHANGELOG.md').readAsStringSync();

    expect(version, isNot('0.9.0'));
    expect(version, releaseVersion);
    expect(changelog, contains('## [$releaseVersion] - '));
  });
}
