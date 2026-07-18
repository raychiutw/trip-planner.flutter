import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/chat/ai_consent_sheet.dart';

void main() {
  testWidgets('Cancel closes AI consent without authorizing', (tester) async {
    var calls = 0;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAiConsentSheet(
                context,
                message: '幫我重排行程',
                onAuthorize: () async {
                  calls++;
                  return true;
                },
              );
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.text('授權 Tripline AI'), findsOneWidget);
    expect(find.text('允許'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(result, isFalse);
  });

  testWidgets('Allow returns true only after authorization succeeds', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAiConsentSheet(
                context,
                message: '幫我重排行程',
                onAuthorize: () async => true,
              );
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-consent-authorize')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
