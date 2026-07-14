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
}
