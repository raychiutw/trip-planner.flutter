import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/features/trip_detail/widgets/day_header.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpHeader(WidgetTester tester, TripDay day) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: DayHeader(day: day)),
  ));
}

void main() {
  group('DayHeader', () {
    testWidgets('DAY NN 補零 + 日期(全形括號) + displayTitle', (tester) async {
      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 3,
          date: '2026-06-12',
          dayOfWeek: '週五',
          title: '首里城與國際通',
          version: 0,
        ),
      );
      expect(find.text('DAY 03'), findsOneWidget);
      expect(find.text('2026-06-12（週五）'), findsOneWidget);
      expect(find.text('首里城與國際通'), findsOneWidget);
    });

    testWidgets('date / dayOfWeek 皆 null → 不顯示日期列,title 退回 Day N',
        (tester) async {
      await pumpHeader(tester, const TripDay(id: 2, dayNum: 2, version: 0));
      expect(find.text('DAY 02'), findsOneWidget);
      // displayTitle fallback chain: title → label → 'Day N'
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.textContaining('（'), findsNothing);
    });
  });
}
