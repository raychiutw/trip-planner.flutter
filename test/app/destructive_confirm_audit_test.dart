import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-0008 / CODING_STANDARDS「破壞性確認一律經 showAppDestructiveConfirm」。
///
/// 掃 lib/features 內每一個 `showAppConfirm(` 呼叫:
/// 1. 不得自己帶 `isDestructive: true`(要破壞性樣式就走 wrapper,來源必填);
/// 2. 確認鈕是「刪除」「移除」的,一律不得直接用 `showAppConfirm`。
/// 非這兩個動詞的(登出、撤銷、設為正選…)不在此限。
///
/// 已知邊界:只認單引號字面值 `confirmLabel: '刪除'`;`confirmLabel` 來自變數的
/// 呼叫抓不到,目前沒有這種寫法。
void main() {
  test('破壞性確認一律經 showAppDestructiveConfirm,features 不自己組', () {
    final offenders = <String>[];
    final label = RegExp(r'''confirmLabel:\s*['"](刪除|移除)['"]''');
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
        final line = '\n'.allMatches(source.substring(0, start)).length + 1;
        if (call.contains('isDestructive: true')) {
          offenders.add('${entity.path}:$line 自己帶 isDestructive');
        } else if (label.hasMatch(call)) {
          offenders.add('${entity.path}:$line 刪除 / 移除沒走 wrapper');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '破壞性確認一律經 showAppDestructiveConfirm(source: …)(ADR-0008)。',
    );
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
