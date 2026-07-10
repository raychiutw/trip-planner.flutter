/// showAppConfirm 平台自適應行為測試(iOS → Cupertino、Android → Material)。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive.dart';

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

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();
    expect(await future, isTrue);
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
            AppSheetAction(label: '分享', value: 'share'),
            AppSheetAction(label: '刪除', value: 'delete', isDestructive: true),
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
            AppSheetAction(label: '分享', value: 'share', icon: Icons.share),
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
}
