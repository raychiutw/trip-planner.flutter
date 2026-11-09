import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// grep 守門：舊 callback 主機已退役（trip-planner#1663），不得出現在任何程式、設定、CI 工作流與現行文件。
/// 有日期的歷史紀錄（docs/adr、research、qa、verification）與 CHANGELOG 不改寫，不在掃描範圍。
void main() {
  const legacyHost = 'mobile-callback.trip-planner-dby.pages.dev';

  test('舊 callback 主機不得出現在任何程式、設定、現行文件', () {
    final hits = <String>[];
    for (final root in ['lib', 'ios', 'android', 'patrol_test', '.github']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (RegExp(r'/(build|Pods|\.gradle|\.dart_tool)/').hasMatch(f.path)) {
          continue;
        }
        String text;
        try {
          text = f.readAsStringSync();
        } on FileSystemException {
          continue; // 二進位檔
        }
        if (text.contains(legacyHost)) {
          hits.add(f.path);
        }
      }
    }
    for (final doc in [
      'README.md',
      'CONTRIBUTING.md',
      'CLAUDE.md',
      'CODING_STANDARDS.md',
      'DESIGN.md',
      'GLOSSARY.md',
      'docs/mobile-e2e.md',
    ]) {
      if (File(doc).existsSync() &&
          File(doc).readAsStringSync().contains(legacyHost)) {
        hits.add(doc);
      }
    }
    expect(hits, isEmpty);
  });

  test('CI 工作流沒有把 callback 覆寫回舊主機或舊路徑', () {
    for (final f in Directory(
      '.github/workflows',
    ).listSync().whereType<File>()) {
      final text = f.readAsStringSync();
      expect(text, isNot(contains('TRIPLINE_OAUTH_CALLBACK_HOST=$legacyHost')));
      expect(text, isNot(contains('oauthCallbackHost=$legacyHost')));
    }
  });
}
