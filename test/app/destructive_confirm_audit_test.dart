import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('只有共用確認入口能設定破壞性樣式', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('/adaptive.dart')) continue;
      if (file.readAsStringSync().contains('isDestructive: true')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty, reason: '改用 showAppDestructiveConfirm 指定觸發來源');
    final adaptive = File('lib/app/adaptive.dart').readAsStringSync();
    expect(
      'isDestructive: true'.allMatches(adaptive),
      hasLength(1),
      reason: '只有 showAppDestructiveConfirm 可設定破壞性樣式',
    );
  });
}
