/// showAppConfirm 平台自適應行為測試(iOS → Cupertino、Android → Material)。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/ui/tp_action_item.dart';

void main() {
  Widget host(TargetPlatform platform, void Function(BuildContext) onTap) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('iOS → CupertinoAlertDialog + 破壞性 action;確認回傳 true', (
    tester,
  ) async {
    late Future<bool> future;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        future = showAppConfirm(
          context,
          title: '刪除停留點',
          message: '確定要刪除嗎?',
          confirmLabel: '刪除',
          isDestructive: true,
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final actions = tester
        .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
        .toList();
    expect(actions.first.isDefaultAction, isTrue);
    expect(actions.last.isDestructiveAction, isTrue);
    expect(actions.last.isDefaultAction, isFalse);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();
    expect(await future, isTrue);
  });

  testWidgets('Android 破壞性確認由安全選項取得預設焦點', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        unawaited(
          showAppConfirm(
            context,
            title: '刪除收藏',
            confirmLabel: '刪除',
            isDestructive: true,
          ),
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .autofocus,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '刪除'))
          .autofocus,
      isFalse,
    );
  });

  testWidgets('Android → Material AlertDialog;取消回傳 false', (tester) async {
    late Future<bool> future;
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        future = showAppConfirm(context, title: '登出帳號', confirmLabel: '登出');
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(await future, isFalse);
  });

  testWidgets('iOS → CupertinoActionSheet;選破壞性動作回傳其值', (tester) async {
    late Future<String?> future;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        future = showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(label: '分享', value: 'share', icon: Icons.share),
            TpActionItem(
              label: '刪除',
              value: 'delete',
              icon: CupertinoIcons.delete,
              role: TpActionRole.destructive,
            ),
          ],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '刪除'));
    await tester.pumpAndSettle();
    expect(await future, 'delete');
  });

  testWidgets('Android → bottom sheet(ListTile);取消(點外部)回傳 null', (
    tester,
  ) async {
    late Future<String?> future;
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        future = showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(label: '分享', value: 'share', icon: Icons.share),
          ],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.widgetWithText(ListTile, '分享'), findsOneWidget);
    // 點 barrier 關閉 → null
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('Android action sheet preserves divider and disabled state', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(label: '分享', value: 'share', icon: Icons.share),
            TpActionItem(
              label: '刪除',
              value: 'delete',
              icon: CupertinoIcons.delete,
              dividerBefore: true,
              role: TpActionRole.destructive,
              enabled: false,
            ),
          ],
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsOneWidget);
    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, '刪除'));
    expect(tile.enabled, isFalse);
    expect(tester.getSize(find.widgetWithText(ListTile, '刪除')).height, 56);
  });

  testWidgets(
    'Android action sheet scrolls long command lists on short screens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late Future<String?> future;
      await tester.pumpWidget(
        host(TargetPlatform.android, (context) {
          future = showAppActionSheet<String>(
            context,
            actions: const [
              TpActionItem(label: '分享', value: 'share', icon: Icons.share),
              TpActionItem(label: '共編設定', value: 'collab', icon: Icons.group),
              TpActionItem(
                label: 'AI 健檢',
                value: 'health',
                icon: Icons.health_and_safety,
              ),
              TpActionItem(
                label: '匯出 JSON',
                value: 'export',
                icon: Icons.download,
              ),
              TpActionItem(
                label: '刪除行程',
                value: 'delete',
                icon: CupertinoIcons.delete,
                dividerBefore: true,
                role: TpActionRole.destructive,
              ),
            ],
          );
        }),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('刪除行程'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除行程'));
      await tester.pumpAndSettle();

      expect(await future, 'delete');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('action sheets render the shared selected checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(
              label: '最近加入',
              value: 'recent',
              icon: CupertinoIcons.clock,
              selected: true,
            ),
          ],
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, '最近加入'));
    expect((tile.leading! as Icon).icon, CupertinoIcons.check_mark);
  });

  testWidgets('iOS action sheet does not dispatch a disabled action', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(
              label: '暫不可用',
              value: 'disabled',
              icon: CupertinoIcons.lock,
              enabled: false,
            ),
          ],
        ).then((_) => completed = true);
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暫不可用'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(completed, isFalse);
  });

  testWidgets('iOS → 頂部橫幅顯示訊息(非 SnackBar);結束不留 pending timer', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        showAppNotice(context, '已登出該裝置');
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pump(); // 插入 overlay + 排程 post-frame
    await tester.pump(const Duration(milliseconds: 300)); // 滑入動畫

    expect(find.text('已登出該裝置'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any(
            (widget) =>
                widget.properties.liveRegion == true &&
                widget.properties.label == '已登出該裝置',
          ),
      isTrue,
    );
    // 不推進到 2.5s;測試結束時 tree 拆除須取消 timer,否則框架報 pending timer。
  });

  testWidgets('Android → Material SnackBar 顯示訊息', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        showAppNotice(context, '已刪除');
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pump(); // 顯示 SnackBar

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('已刪除'), findsOneWidget);
  });

  testWidgets('unsaved guard coalesces concurrent close requests', (
    tester,
  ) async {
    final controller = AppUnsavedChangesController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: AppUnsavedChangesGuard(
          controller: controller,
          hasChanges: true,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                unawaited(controller.requestPop());
                unawaited(controller.requestPop());
              },
              child: const Text('close twice'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('close twice'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
  });

  Widget searchHost(TargetPlatform platform, TextEditingController controller) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: AppSearchField(
          fieldKey: const ValueKey('search'),
          controller: controller,
          placeholder: '搜尋',
        ),
      ),
    );
  }

  testWidgets('AppSearchField iOS → CupertinoSearchTextField;enterText 生效', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(searchHost(TargetPlatform.iOS, controller));

    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('search')), '沖繩');
    expect(controller.text, '沖繩');
  });

  testWidgets('AppSearchField Android → TextField;有字才顯示清除鈕,點擊清空', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(searchHost(TargetPlatform.android, controller));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CupertinoSearchTextField), findsNothing);
    // 空 → 無清除鈕
    expect(find.byIcon(CupertinoIcons.clear), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('search')), '釜山');
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.clear), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.clear));
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('AppSearchField debounce 只送出停止輸入後的最新文字', (tester) async {
    final controller = TextEditingController();
    final changes = <String>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            fieldKey: const ValueKey('search'),
            controller: controller,
            placeholder: '搜尋',
            debounce: const Duration(milliseconds: 300),
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('search')), '東');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const ValueKey('search')), '東京');
    await tester.pump(const Duration(milliseconds: 299));
    expect(changes, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(changes, ['東京']);
  });

  testWidgets('AppSearchField 搜尋送出會取消尚未觸發的 debounce', (tester) async {
    final controller = TextEditingController();
    final changes = <String>[];
    final submissions = <String>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            fieldKey: const ValueKey('search'),
            controller: controller,
            placeholder: '搜尋',
            debounce: const Duration(milliseconds: 300),
            onChanged: changes.add,
            onSubmitted: submissions.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('search')), '東京');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(submissions, ['東京']);
    expect(changes, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    expect(changes, isEmpty);
  });
}
