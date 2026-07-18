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
}
