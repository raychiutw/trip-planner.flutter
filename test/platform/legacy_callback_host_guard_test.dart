import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// grep 守門：舊 callback 主機只允許出現在「過渡期保留」的檔案；
/// 其他原始碼、CI 工作流與現行文件都不得再把它當預設。
/// 有日期的歷史紀錄（docs/adr、research、qa、verification）與 CHANGELOG 不改寫，不在掃描範圍。
void main() {
  const legacyHost = 'mobile-callback.trip-planner-dby.pages.dev';
  const allowed = {
    'ios/Runner/Release.entitlements',
    'ios/Runner/DebugProfile.entitlements',
    'android/app/build.gradle.kts',
  };

  test('舊 callback 主機只出現在過渡期保留的檔案', () {
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
        if (text.contains(legacyHost) && !allowed.contains(f.path)) {
          hits.add(f.path);
        }
      }
    }
    for (final doc in ['README.md', 'CONTRIBUTING.md', 'docs/mobile-e2e.md']) {
      if (File(doc).readAsStringSync().contains(legacyHost)) hits.add(doc);
    }
    expect(hits, isEmpty);
  });

  test('CI 工作流沒有把 callback 覆寫回舊主機或舊路徑', () {
    for (final f in Directory('.github/workflows').listSync().whereType<File>()) {
      final text = f.readAsStringSync();
      expect(text, isNot(contains('TRIPLINE_OAUTH_CALLBACK_HOST=$legacyHost')));
      expect(text, isNot(contains('oauthCallbackHost=$legacyHost')));
    }
  });
}
