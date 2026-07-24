import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/app_feedback.dart';

void main() {
  testWidgets('錯誤使用持續 banner，並可重試或關閉', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showAppError(context, '載入失敗', onRetry: () => retryCount++),
              child: const Text('觸發'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('觸發'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);
    expect(find.text('載入失敗'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(retryCount, 1);
    expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
  });

  testWidgets('沒有重試動作時仍可明確關閉錯誤', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppError(context, '無法載入'),
              child: const Text('觸發'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('觸發'));
    await tester.pumpAndSettle();

    expect(find.text('重試'), findsNothing);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
  });

  testWidgets('不可關閉的錯誤必須提供重試 recovery', (tester) async {
    late BuildContext scaffoldContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              scaffoldContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      () => showAppError(scaffoldContext, '無法恢復', allowDismiss: false),
      throwsAssertionError,
    );
  });
}
