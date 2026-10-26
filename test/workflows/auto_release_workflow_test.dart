import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final autoRelease = File('.github/workflows/auto-release.yml');

  test('VERSION 推上 master 時自動 dispatch 雙商店發佈', () {
    expect(autoRelease.existsSync(), isTrue);
    final yml = autoRelease.readAsStringSync();
    expect(yml, contains('branches: [master]'));
    expect(yml, contains('paths: [VERSION]'));
    expect(yml, contains('actions: write'));
    expect(
      yml,
      contains('gh workflow run mobile.yml --ref master -f release_target=both'),
    );
  });

  test('只靠既有 mobile-release 環境把關，不另加 needs', () {
    final yml = autoRelease.readAsStringSync();
    expect(yml, isNot(contains('needs:')));
    expect(yml, isNot(contains('--admin')));
  });
}
