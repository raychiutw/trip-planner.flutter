import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-0008:刪除不可復原,確認一律用破壞性樣式。
///
/// 掃 lib/features 內每一個 `showAppConfirm(` 呼叫:確認鈕是「刪除」的,必須帶
/// `isDestructive: true`。非「刪除」的(登出、撤銷、設為正選…)不在此限。
void main() {
  test('所有「刪除」確認都走破壞性樣式', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      var searchFrom = 0;
      while (true) {
        final start = source.indexOf('showAppConfirm(', searchFrom);
        if (start == -1) break;
        final end = _matchingParen(source, start + 'showAppConfirm'.length);
        final call = source.substring(start, end);
        searchFrom = end;
        if (!call.contains("confirmLabel: '刪除'")) continue;
        if (!call.contains('isDestructive: true')) {
          final line = '\n'.allMatches(source.substring(0, start)).length + 1;
          offenders.add('${entity.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty, reason: '「刪除」是永久銷毀,確認鈕必須是破壞性樣式(ADR-0008)。');
  });
}

int _matchingParen(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return source.length;
}
