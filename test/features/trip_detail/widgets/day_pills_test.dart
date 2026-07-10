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

    testWidgets('AXXXL 下維持 44pt 以上且不 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: DayPills(
                days: _days,
                activeDayNum: 1,
                onDaySelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('DAY 01')).height, greaterThan(22));
    });

    testWidgets('VoiceOver 讀出按鈕與選取狀態', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DayPills(days: _days, activeDayNum: 1, onDaySelected: (_) {}),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const ValueKey('day-pill-1'))),
        matchesSemantics(
          label: 'DAY 01，6/10',
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });
}
