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
}
