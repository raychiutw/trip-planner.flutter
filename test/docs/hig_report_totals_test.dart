/// 守住 HIG 逐張檢查報告的數字對帳（#562）：
/// 摘要表合計 = 逐場景表列數 = 場景數 = 淺／深色各自的截圖數（`-hc` 提高對比變體不算場景）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/hig_screenshot_scenes.dart';

const _report = 'docs/qa/2026-11-04-hig-screenshot-review-app.md';
const _shots = 'docs/qa/2026-11-04-hig-screenshots';

void main() {
  final lines = File(_report).readAsLinesSync();
  final rowNames = <String>[
    for (final l in lines)
      if (RegExp(r'^\| `([a-z0-9-]+)` \| [^|]+\| [^|]+\|').firstMatch(l)
          case final m?)
        m.group(1)!,
  ];
  // 元件示範頁兩個場景由整合測試自己拍（integration_test/hig_screenshots_test.dart），
  // 不在 higScenes() 內；實際場景總數 = higScenes() + 這兩個。
  final scenes = {
    for (final s in higScenes()) s.name,
    'components',
    'ax-components-2x',
  };

  test('摘要表合計 = 逐場景表列數 = 場景數', () {
    final total = RegExp(
      r'^\| \*\*合計\*\* \| \*\*(\d+)\*\* \|$',
    ).firstMatch(lines.firstWhere((l) => l.contains('**合計**')))!.group(1)!;
    // 各判定列加總（合計列之前、「結論」表頭之後的數字列）。
    final start = lines.indexWhere((l) => l.startsWith('| 結論 | 場景數'));
    var sum = 0;
    for (var i = start + 2; !lines[i].contains('**合計**'); i++) {
      final cell = lines[i].split('|')[2].trim();
      sum += int.parse(RegExp(r'^\d+').firstMatch(cell)!.group(0)!);
    }
    expect(rowNames.toSet().length, rowNames.length, reason: '場景列重複');
    expect(int.parse(total), rowNames.length);
    expect(sum, rowNames.length);
    expect(rowNames.length, scenes.length);
  });

  test('逐場景表的名稱與 higScenes() 完全一致', () {
    expect(rowNames.toSet().difference(scenes), isEmpty);
    expect(scenes.difference(rowNames.toSet()), isEmpty);
  });

  for (final mode in ['light', 'dark']) {
    test('$mode 截圖（不含 -hc）與場景一一對應', () {
      final pngs = {
        for (final f in Directory('$_shots/$mode').listSync())
          if (f.path.endsWith('.png') && !f.path.endsWith('-hc.png'))
            f.uri.pathSegments.last.replaceFirst('.png', ''),
      };
      expect(pngs.difference(scenes), isEmpty);
      expect(scenes.difference(pngs), isEmpty);
    });
  }
}
