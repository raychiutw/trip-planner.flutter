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
        future = showAppConfirm(
          context,
          title: '登出帳號',
          confirmLabel: '登出',
        );
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

  testWidgets('Android → bottom sheet(ListTile);取消(點外部)回傳 null', (tester) async {
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
}
