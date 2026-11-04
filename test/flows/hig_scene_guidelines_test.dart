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

import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/hig_screenshot_scenes.dart';

/// HIG Accessibility 頁：iOS 控制項預設 44×44 pt（檢查表 A1）。
const _minTapTarget = 44.0;

/// `--dart-define=HIG_COLLECT=true`：只印出各場景的違規，不下斷言，用來更新已知違規清單。
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
  'trip-edit-save-failed': {'搜尋地點（城市、景點） 305x36'},
  'favorites': {'搜尋收藏 361x36'},
  'favorites-load-failed': {'搜尋收藏 361x36'},
  'account-developer-app-new': {'(無標籤) 40x40'},
  'account-delete-dialog': {'目前密碼（重新驗證） 230x31'},
  'share-manage': {'(無標籤) 40x40'},
  'share-custom-expiry-missing': {'(無標籤) 40x40'},
  'share-created-card': {'(無標籤) 40x40'},
  'share-create-failed': {'(無標籤) 40x40'},
  'share-list-load-failed': {'(無標籤) 40x40'},
  // 2 倍字級下建議鈕區（SingleChildScrollView，下緣 611.4）放不下第四個鈕：鈕實際高 96pt、
  // 上緣 568，只有 43.4pt 在可見範圍內，語意樹的矩形被捲動區裁成 43。這是量測限制（裁切後的
  // 尺寸，已用渲染尺寸驗證），鈕本身捲得進來；字階對照 HIG 後才出現。
  'ax-chat-2x': {'加入適合親子的水族館行程 345x43'},
  'offline-banner-network': {'搜尋行程 361x36'},
  'offline-banner-pending': {'搜尋行程 361x36', '立即重試 100x40'},
  'app-lock-enable-prompt': {'搜尋行程 361x36'},
  // 彈出層場景：sheet 頂端的拖曳把手（36x4）來自 liquid_glass_widgets 套件，語意帶 onTap（點了關閉 sheet），
  // 尺寸確實小於 44pt；lib/ 內沒有這個語意，要修得在套件層（A18 追蹤）。
  // 通知橫幅場景的底下是收藏頁，搜尋欄同 'favorites'。
  'favorites-filter-sheet': {'Drag handle 36x4'},
  'note-edit-sheet': {'Drag handle 36x4'},
  'poi-info-edit-sheet': {'Drag handle 36x4'},
  'entry-edit-sheet': {'Drag handle 36x4'},
  'travel-edit-sheet': {'Drag handle 36x4'},
  'explore-custom-region-sheet': {'Drag handle 36x4'},
  'chat-ai-consent-sheet': {'Drag handle 36x4'},
  // 「匿名分享」勾選框 40x40，與分享頁建立表單同一個元件（'share-manage'）。
  'share-edit-sheet': {'(無標籤) 40x40', 'Drag handle 36x4'},
  'favorites-removed-notice': {'搜尋收藏 361x36'},
  'sync-conflict-sheet': {'Drag handle 36x4'},
  'sync-conflict-sheet-many': {'Drag handle 36x4'},
  'entry-edit-sheet-remote-conflict': {'Drag handle 36x4'},
};

/// 刻意在畫面上顯示對話框的場景。其餘場景若出現對話框，代表畫面被不相干的詢問蓋住
/// （例如已登入場景預設會跳「要用 Face ID 登入嗎？」），截圖與量測都不是畫面本體。
const _scenesWithDialog = {
  'account-logout-confirm',
  'account-connected-app-revoke-confirm',
  'account-delete-dialog',
  'chat-voice-consent',
  'invite-wrong-account-pending',
  'app-lock-enable-prompt',
  'favorites-remove-confirm',
  'account-delete-preview-failed',
  'collab-revoke-invite-confirm',
  'account-biometric-disable-confirm',
  'account-session-revoke-confirm',
  'developer-app-delete-confirm',
  'note-delete-confirm',
  'entry-alternate-remove-confirm',
  'add-to-trip-time-conflict-alert',
  'trip-edit-delete-day-confirm',
  'entry-edit-overwrite-confirm',
  'note-edit-overwrite-confirm',
  'travel-edit-overwrite-confirm',
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
        late int dialogCount;
        await runHigScene(tester, scenes[name]!, ThemeMode.light, (_) async {
          // rootPipelineOwner.semanticsOwner 在此為 null（語意樹掛在子 owner），
          // 官方建議的替代寫法拿不到根節點，所以沿用 pipelineOwner。
          // ignore: deprecated_member_use
          final owner = tester.binding.pipelineOwner.semanticsOwner!;
          final root = owner.rootSemanticsNode!;
          violations = tapTargetViolations(root, 3.0, 2556);
          dialogCount = find.byType(CupertinoAlertDialog).evaluate().length;
        });
        debugPrint('HIGTAP\t$name\t${violations.toList()..sort()}');
        // 收集模式：只印不斷言（失敗的測試收尾會多拖約 90 秒，整批掃描太慢）。
        if (_collectOnly) return;
        // 先卸載畫面再斷言：失敗時若畫面還掛著，收尾會拖約 90 秒並連帶拖垮後面的場景。
        await tester.pumpWidget(const SizedBox.shrink());
        expect(
          dialogCount > 0,
          _scenesWithDialog.contains(name),
          reason: '對話框數量 $dialogCount：場景被不相干的詢問蓋住，或漏登記 _scenesWithDialog',
        );
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
