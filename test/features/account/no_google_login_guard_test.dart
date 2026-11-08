import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/auth_repository.dart';

/// 守住「Google 帳號登入／Google 重新驗證」已從 App 移除（owner 2026-11-08，web#1643）。
/// Google Maps／Places／Navigation 不是登入，不在守門範圍。
void main() {
  test('lib/ 不得再有 Google 重新驗證或 Google 登入的程式與字串', () {
    final banned = RegExp(
      r'DeleteReauth|delete-reauth|reauthProvider|以 Google|Google 驗證|'
      r'Google 登入|Google 重新驗證|login/google',
    );
    final hits = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) hits.add('${file.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  });

  test('舊 api 仍回 reauthProvider、新 api 不回：兩種 payload 都能解析', () {
    const base = {
      'hasPassword': true,
      'tripsOwned': 1,
      'collaboratorsAffected': 2,
    };
    for (final json in [
      base,
      {...base, 'reauthProvider': 'google'},
      {...base, 'reauthProvider': null},
    ]) {
      final preview = AccountDeletionPreview.fromJson(json);
      expect(preview.hasPassword, isTrue);
      expect(preview.tripsOwned, 1);
    }
  });
}
