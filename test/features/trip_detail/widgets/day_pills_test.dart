import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/features/trip_detail/widgets/day_pills.dart';
import 'package:tripline/theme/app_theme.dart';

const _days = [
  TripDay(id: 1, dayNum: 1, date: '2026-06-10', version: 0),
  TripDay(id: 2, dayNum: 2, date: '2026-06-11', version: 0),
  TripDay(id: 3, dayNum: 3, date: '2026-06-12', version: 0),
];

void main() {
  group('DayPills.shortDate', () {
    test('YYYY-MM-DD → M/D', () {
      expect(DayPills.shortDate('2026-06-10'), '6/10');
      expect(DayPills.shortDate('2026-12-01'), '12/1');
    });
    test('null → 空字串', () => expect(DayPills.shortDate(null), ''));
    test('非日期字串原樣回傳', () {
      expect(DayPills.shortDate('not-a-date'), 'not-a-date');
      expect(DayPills.shortDate('2026-06'), '2026-06');
    });
  });

  group('DayPills 渲染與互動', () {
    testWidgets('渲染 N 個 pill,點擊回呼該 dayNum', (tester) async {
      int? selectedDayNum;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DayPills(
              days: _days,
              activeDayNum: 1,
              onDaySelected: (dayNum) => selectedDayNum = dayNum,
            ),
          ),
        ),
      );

      expect(find.text('DAY 01'), findsOneWidget);
      expect(find.text('DAY 02'), findsOneWidget);
      expect(find.text('DAY 03'), findsOneWidget);
      expect(find.text('6/10'), findsOneWidget);

      await tester.tap(find.text('DAY 02'));
      expect(selectedDayNum, 2);
    });

    testWidgets('切換到較後日期時自動把選中 pill 捲進可視範圍', (tester) async {
      final days = List.generate(
        12,
        (index) => TripDay(
          id: index + 1,
          dayNum: index + 1,
          date: '2026-06-${(index + 1).toString().padLeft(2, '0')}',
          version: 0,
        ),
      );
      var activeDay = 1;
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, update) {
                  setState = update;
                  return DayPills(
                    days: days,
                    activeDayNum: activeDay,
                    onDaySelected: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      setState(() => activeDay = 12);
      await tester.pumpAndSettle();

      final selected = find.byKey(const ValueKey('day-pill-12'));
      expect(selected, findsOneWidget);
      expect(tester.getRect(selected).center.dx, inInclusiveRange(0, 320));
    });
  });
}
