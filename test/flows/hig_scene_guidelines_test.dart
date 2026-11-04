/// 以 mock 場景（integration_test 的 `higScenes()`）逐畫面量測 HIG 可量化項目。
///
/// 與截圖腳本共用同一批場景與 fake repository，但跑在一般 `flutter test`（不需要模擬器、
/// 不碰 prod），所以能進 CI。截圖給人判讀，這裡只守可量化的底線。
/// 檢查表見 `docs/research/2026-11-04-hig-screen-checklist.md`（A1、A2）。
///
/// 為什麼不用 `meetsGuideline(iOSTapTargetGuideline)`：它在大型語意樹失敗時會卡死
/// （場景 trip-create 實測 10 分鐘不返回），而且一次只報第一個違規。這裡自己走語意樹，
/// 回報每一個違規元素的標籤與尺寸，違規清單同時是取證報告的素材。
///
/// 已知違規（[_knownTapTargetViolations]）是「棘輪」：新增違規會紅；已知的被修好但沒從清單
/// 移除也會紅，逼著清單只減不增。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../integration_test/support/hig_screenshot_scenes.dart';

/// HIG Accessibility 頁：iOS 控制項預設 44×44 pt（檢查表 A1）。
const _minTapTarget = 44.0;

/// `--dart-define=HIG_COLLECT=1`：只印出各場景的違規，不下斷言，用來更新已知違規清單。
const _collectOnly = bool.fromEnvironment('HIG_COLLECT');

/// 場景名稱 → 該場景已知的違規（`標籤 寬x高`，邏輯 pt、四捨五入到整數）。
/// 更新方式：`--dart-define=HIG_COLLECT=true` 跑一次，把印出的 `HIGTAP` 行貼進來。
const _knownTapTargetViolations = <String, Set<String>>{
  'auth-signup': {'(無標籤) 40x40'},
  'trips-list': {'搜尋行程 361x36'},
  'trips-list-load-failed': {'搜尋行程 361x36'},
  'trips-list-empty': {'搜尋行程 361x36'},
  'trip-create': {'搜尋地點（城市、景點） 305x36'},
  'trip-edit': {'搜尋地點（城市、景點） 305x36'},
  'favorites': {'搜尋收藏 361x36'},
  'favorites-load-failed': {'搜尋收藏 361x36'},
  'account-developer-app-new': {'(無標籤) 40x40'},
  'share-manage': {'(無標籤) 40x40'},
  'share-custom-expiry-missing': {'(無標籤) 40x40'},
  'share-created-card': {'(無標籤) 40x40'},
  'share-create-failed': {'(無標籤) 40x40'},
  'share-list-load-failed': {'(無標籤) 40x40'},
  'offline-banner-network': {'搜尋行程 361x36'},
  'offline-banner-pending': {'搜尋行程 361x36', '立即重試 100x40'},
  'app-lock-enable-prompt': {'搜尋行程 361x36'},
};

/// 走語意樹，回傳所有「可點擊但最短邊小於 [_minTapTarget] pt」的元素。
Set<String> tapTargetViolations(
  SemanticsNode root,
  double devicePixelRatio,
  double viewportHeight,
) {
  final found = <String>{};
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final tappable =
        data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress);
    final hidden = data.flagsCollection.isHidden;
    if (tappable && !hidden && !node.isInvisible) {
      var bounds = node.rect;
      for (SemanticsNode? n = node; n != null; n = n.parent) {
        final Matrix4? t = n.transform;
        if (t != null) bounds = MatrixUtils.transformRect(t, bounds);
      }
      final w = bounds.width / devicePixelRatio;
      final h = bounds.height / devicePixelRatio;
      // 語意樹的 rect 已被捲動區／螢幕邊緣裁切；貼著視窗上下緣的節點只露出一截，
      // 量到的是被裁掉的尺寸，不是控制項本身，略過以免誤報。
      final clippedByViewport =
          bounds.top <= 0.5 || bounds.bottom >= viewportHeight - 0.5;
      if (!clippedByViewport && (w < _minTapTarget || h < _minTapTarget)) {
        final label = data.label.isEmpty
            ? '(無標籤)'
            : data.label.split('\n').first;
        found.add('$label ${w.round()}x${h.round()}');
      }
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(root);
  return found;
}

void main() {
  final scenes = {for (final s in higScenes()) s.name: s};

  for (final name in scenes.keys) {
    testWidgets('$name：可點擊元素至少 44×44', (tester) async {
      // 與截圖腳本同尺寸（iPhone 393×852 pt @3x）；預設 800×600 會走平板雙欄版面，量到的不是手機。
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      // SemanticsHandle 必須在測試結束前釋放，不能放 addTearDown。
      final handle = tester.ensureSemantics();
      try {
        late Set<String> violations;
        await runHigScene(tester, scenes[name]!, ThemeMode.light, (_) async {
          final root =
              tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
          violations = tapTargetViolations(root, 3.0, 2556);
        });
        debugPrint('HIGTAP\t$name\t${violations.toList()..sort()}');
        // 收集模式：只印不斷言（失敗的測試收尾會多拖約 90 秒，整批掃描太慢）。
        if (_collectOnly) return;
        final known = _knownTapTargetViolations[name] ?? const <String>{};
        expect(
          violations.difference(known),
          isEmpty,
          reason: '新增的觸控目標違規（HIG 檢查表 A1）',
        );
        expect(
          known.difference(violations),
          isEmpty,
          reason: '已知違規已被修好，請從 _knownTapTargetViolations 移除',
        );
      } finally {
        handle.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 90)));
  }
}
