/// 收集用（不是守門）：對每個 mock 場景跑 Flutter 內建的文字對比（C1）與可點擊元素標籤（VoiceOver）檢查，
/// 只印 `HIGA11Y` 行、不下斷言。沒帶 `--dart-define=HIG_COLLECT=1` 時整批 skip，避免變成永遠綠燈的假測試。
/// `--dart-define=HIG_ONLY=a,b` 只跑指定場景。結果解讀見 `docs/qa/2026-11-04-hig-fix-list.md`。
///
/// 限制：`textContrastGuideline` 以渲染後像素取樣；半透明玻璃、對話框 blur 底、停用狀態的取樣不可靠，
/// 結果要對照截圖再下結論。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/hig_screenshot_scenes.dart';

const _only = String.fromEnvironment('HIG_ONLY');
const _collect = bool.fromEnvironment('HIG_COLLECT');

void main() {
  final only = _only.isEmpty ? null : _only.split(',').toSet();
  for (final scene in higScenes()) {
    if (only != null && !only.contains(scene.name)) continue;
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${scene.name} ${mode.name}',
        (tester) async {
          tester.view.physicalSize = const Size(1179, 2556);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);
          final handle = tester.ensureSemantics();
          try {
            await runHigScene(tester, scene, mode, (_) async {
              final c = await textContrastGuideline.evaluate(tester);
              final l = await labeledTapTargetGuideline.evaluate(tester);
              debugPrint(
                'HIGA11Y\t${scene.name}\t${mode.name}\tcontrast=${c.passed ? "ok" : c.reason?.replaceAll("\n", " | ")}\tlabel=${l.passed ? "ok" : l.reason?.replaceAll("\n", " | ")}',
              );
            });
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            handle.dispose();
          }
        },
        skip: !_collect,
        timeout: const Timeout(Duration(seconds: 120)),
      );
    }
  }
}
