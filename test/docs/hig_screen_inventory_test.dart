/// 守住 `docs/research/2026-11-04-hig-app-screen-inventory.md`（#533）：
/// 路由表、彈出層 helper、mock 場景新增或改名時，清單必須跟著更新，不能悄悄漏掉畫面。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/hig_screenshot_scenes.dart';

const _docPath = 'docs/research/2026-11-04-hig-app-screen-inventory.md';

/// 文件中所有反引號包住的 token。
Set<String> _docTokens() => RegExp(
  r'`([^`\n]+)`',
).allMatches(File(_docPath).readAsStringSync()).map((m) => m.group(1)!).toSet();

void main() {
  final tokens = _docTokens();

  test('router.dart 的每個 path 都登記在清單', () {
    final src = File('lib/app/router.dart').readAsStringSync();
    final paths = RegExp(
      r"path:\s*'([^']+)'",
    ).allMatches(src).map((m) => m.group(1)!).toSet();
    expect(
      paths.length,
      greaterThanOrEqualTo(25),
      reason: '解析不到足夠路由，regex 可能失效',
    );
    expect(paths.where((p) => !tokens.contains(p)), isEmpty);
  });

  test('adaptive.dart／irreversible_action.dart 的每個彈出層 helper 都登記在清單', () {
    final helper = RegExp(
      r'^Future<[^\n]*?>\s+((?:showApp|confirmAnd)[A-Za-z]+)\b',
      multiLine: true,
    );
    final names = <String>{
      for (final f in [
        'lib/app/adaptive.dart',
        'lib/app/irreversible_action.dart',
      ])
        ...helper
            .allMatches(File(f).readAsStringSync())
            .map((m) => m.group(1)!),
    };
    expect(
      names.length,
      greaterThanOrEqualTo(10),
      reason: '解析不到足夠 helper，regex 可能失效',
    );
    expect(names.where((n) => !tokens.contains(n)), isEmpty);
  });

  test('每個 mock 場景都登記在清單', () {
    final missing = [
      for (final s in higScenes())
        if (!tokens.contains(s.name)) s.name,
    ];
    expect(missing, isEmpty);
  });

  test('清單裡的場景名稱都真的存在（防改名後文件過期）', () {
    final real = {for (final s in higScenes()) s.name};
    final kebab = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)+$');
    // 沒有斜線的子路由（如 add-to-trip）長得像場景名，先排除。
    final routePaths = RegExp(r"path:\s*'([^']+)'")
        .allMatches(File('lib/app/router.dart').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    final stale = tokens.where(
      (t) => kebab.hasMatch(t) && !real.contains(t) && !routePaths.contains(t),
    );
    expect(stale, isEmpty);
  });
}
