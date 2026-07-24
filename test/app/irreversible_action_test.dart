import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/irreversible_action.dart';

void main() {
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
