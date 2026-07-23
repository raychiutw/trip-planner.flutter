import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trips/trip_title_button.dart';
import 'package:tripline/models/trip.dart';

void main() {
  testWidgets('trip picker is a selection sheet', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripTitleButton(
            currentTripId: 'trip-1',
            currentTitle: '東京五日行',
            trips: const [
              TripSummary(tripId: 'trip-1', name: '東京五日行'),
              TripSummary(tripId: 'trip-2', name: '沖繩五日行'),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('東京五日行'));
    await tester.pumpAndSettle();
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);

    await tester.tap(find.text('沖繩五日行'));
    await tester.pumpAndSettle();
    expect(selected, 'trip-2');
  });

  testWidgets('只有一個行程時停用 selector 並提供完整語意', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripTitleButton(
            currentTripId: 'trip-1',
            currentTitle: '東京五日行',
            trips: const [TripSummary(tripId: 'trip-1', name: '東京五日行')],
            onSelected: (_) => fail('單一行程不應開啟 selector'),
          ),
        ),
      ),
    );

    final title = find.byKey(const ValueKey('trip-title-button'));
    expect(find.byIcon(CupertinoIcons.chevron_down), findsNothing);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(tester.getSize(title).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(title).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(title),
      matchesSemantics(
        label: '目前行程',
        value: '東京五日行',
        hint: '只有一個行程',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });
}
