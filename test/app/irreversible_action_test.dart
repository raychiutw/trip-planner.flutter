import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/app/irreversible_action.dart';

void main() {
  testWidgets('選單來源的不可復原動作以 action sheet 確認，確認後才動手', (tester) async {
    var ran = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                confirmAndRunIrreversibleAction(
                  context,
                  source: TpDestructiveConfirmSource.menu,
                  title: '移除「v@x.com」？',
                  message: '這位成員將失去此行程的存取權，且無法復原。',
                  actionLabel: '移除',
                  progressLabel: '正在移除…',
                  successMessage: '已移除共編成員',
                  failureMessage: '移除失敗，原權限已保留',
                  action: () async {
                    ran = true;
                    return true;
                  },
                ),
              ),
              child: const Text('開始'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(ran, isFalse);

    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '移除'));
    await tester.pumpAndSettle();
    expect(ran, isTrue);
    expect(find.text('已移除共編成員'), findsOneWidget);
  });

  testWidgets('不可復原動作等伺服器成功後才關閉進度並通知', (tester) async {
    final completed = Completer<bool>();
    var succeeded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                confirmAndRunIrreversibleAction(
                  context,
                  source: TpDestructiveConfirmSource.direct,
                  title: '撤銷分享連結',
                  message: '「家人連結」將立即失效，且無法復原。',
                  actionLabel: '撤銷',
                  progressLabel: '正在撤銷…',
                  successMessage: '已撤銷分享連結',
                  failureMessage: '撤銷失敗，原連結已保留',
                  action: () => completed.future,
                  onSuccess: () => succeeded = true,
                ),
              ),
              child: const Text('開始'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    expect(find.text('撤銷分享連結'), findsOneWidget);
    expect(find.text('「家人連結」將立即失效，且無法復原。'), findsOneWidget);

    await tester.tap(find.text('撤銷'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('irreversible-action-progress')),
      findsOneWidget,
    );
    expect(find.text('正在撤銷…'), findsOneWidget);
    expect(succeeded, isFalse);

    completed.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('irreversible-action-progress')),
      findsNothing,
    );
    expect(find.text('已撤銷分享連結'), findsOneWidget);
    expect(succeeded, isTrue);
  });

  testWidgets('不可復原動作失敗保留資料並可直接重試', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                confirmAndRunIrreversibleAction(
                  context,
                  source: TpDestructiveConfirmSource.direct,
                  title: '刪除分享連結',
                  message: '連結與統計會永久刪除，且無法復原。',
                  actionLabel: '刪除',
                  progressLabel: '正在刪除…',
                  successMessage: '已刪除分享連結',
                  failureMessage: '刪除失敗，原連結已保留',
                  action: () async {
                    attempts += 1;
                    return attempts > 1;
                  },
                ),
              ),
              child: const Text('開始'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    expect(find.text('刪除失敗，原連結已保留'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    await tester.ensureVisible(find.text('重試'));
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('刪除失敗，原連結已保留'), findsNothing);
  });
}
