import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/features/trip_detail/widgets/day_header.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpHeader(WidgetTester tester, TripDay day) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: DayHeader(day: day)),
    ),
  );
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

    testWidgets('date / dayOfWeek 皆 null → 不顯示日期列,title 退回 Day N', (
      tester,
    ) async {
      await pumpHeader(tester, const TripDay(id: 2, dayNum: 2, version: 0));
      expect(find.text('DAY 02'), findsOneWidget);
      // displayTitle fallback chain: title → label → 'Day N'
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.textContaining('（'), findsNothing);
    });

    testWidgets('當日總覽：N 個停留點 · K km（距離四捨五入）', (tester) async {
      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 1,
          version: 0,
          timeline: [
            TimelineEntry(id: 11, sortOrder: 0, version: 0, title: 'A'),
            TimelineEntry(
              id: 12,
              sortOrder: 1,
              version: 0,
              title: 'B',
              travel: Travel(type: 'car', distanceM: 1200),
            ),
            TimelineEntry(
              id: 13,
              sortOrder: 2,
              version: 0,
              title: 'C',
              travel: Travel(type: 'car', distanceM: 2600),
            ),
          ],
        ),
      );
      // 3 個停留點;距離 (1200+2600)/1000 = 3.8 → 四捨五入 4
      expect(find.text('3 個停留點 · 4 km'), findsOneWidget);
    });

    testWidgets('總距離為 0 → 只顯示停留點數,隱藏「· K km」', (tester) async {
      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 1,
          version: 0,
          timeline: [
            TimelineEntry(id: 11, sortOrder: 0, version: 0, title: 'A'),
            TimelineEntry(id: 12, sortOrder: 1, version: 0, title: 'B'),
          ],
        ),
      );
      expect(find.text('2 個停留點'), findsOneWidget);
      expect(find.textContaining('km'), findsNothing);
    });
  });
}
