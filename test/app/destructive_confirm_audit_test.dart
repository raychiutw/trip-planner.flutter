import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-0008 / CODING_STANDARDS「破壞性確認一律經 showAppDestructiveConfirm」。
///
/// 掃 lib/features 內每一個 `showAppConfirm(` 呼叫:
/// 1. 不得自己帶 `isDestructive: true`(要破壞性樣式就走 wrapper,來源必填);
/// 2. 確認鈕是「刪除」「移除」「撤銷」「登出」(#273 稽核表判為破壞性的四個動詞)
///    的,一律不得直接用 `showAppConfirm`。其他動詞(設為正選、允許通知…)不在此限。
///
/// 已知邊界:只認單引號字面值 `confirmLabel: '刪除'`;`confirmLabel` 來自變數的
/// 呼叫抓不到,目前沒有這種寫法。
void main() {
  test('破壞性確認一律經 showAppDestructiveConfirm,features 不自己組', () {
    final offenders = <String>[];
    final label = RegExp(r'''confirmLabel:\s*['"](刪除|移除|撤銷|登出)['"]''');
    final call = RegExp(r'showAppConfirm\s*\(');
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in call.allMatches(source)) {
        final end = _matchingParen(source, match.end - 1);
        final body = source.substring(match.start, end);
        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        if (body.contains('isDestructive: true')) {
          offenders.add('${entity.path}:$line 自己帶 isDestructive');
        } else if (label.hasMatch(body)) {
          offenders.add('${entity.path}:$line 破壞性動詞沒走 wrapper');
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
