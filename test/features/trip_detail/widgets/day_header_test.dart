import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/features/trip_detail/widgets/day_header.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpHeader(
  WidgetTester tester,
  TripDay day, {
  List<TripSegment> segments = const [],
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: DayHeader(day: day, segments: segments),
      ),
    ),
  );
}

void main() {
  group('DayHeader', () {
    testWidgets('DAY NN 補零 + 日期作唯一主標，不再顯示 custom title', (tester) async {
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
      expect(find.text('首里城與國際通'), findsNothing);
    });

    testWidgets('date / dayOfWeek 皆 null → 不顯示日期列,title 退回 Day N', (
      tester,
    ) async {
      await pumpHeader(tester, const TripDay(id: 2, dayNum: 2, version: 0));
      expect(find.text('DAY 02'), findsOneWidget);
      // 日期缺漏時固定退回 Day N。
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.textContaining('（'), findsNothing);
    });

    testWidgets('當日總覽：使用 source entry travel 並將距離四捨五入', (tester) async {
      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 1,
          version: 0,
          timeline: [
            TimelineEntry(
              id: 11,
              sortOrder: 0,
              version: 0,
              title: 'A',
              travel: Travel(type: 'car', distanceM: 1200),
            ),
            TimelineEntry(
              id: 12,
              sortOrder: 1,
              version: 0,
              title: 'B',
              travel: Travel(type: 'car', distanceM: 2600),
            ),
            TimelineEntry(
              id: 13,
              sortOrder: 2,
              version: 0,
              title: 'C',
              travel: Travel(type: 'car', distanceM: 999999),
            ),
          ],
        ),
      );
      // A→B 與 B→C 共 3.8 km；最後一站的 travel 不屬於當日相鄰路段。
      expect(find.text('3 個停留點 · 4 km'), findsOneWidget);
    });

    testWidgets('當日總覽：優先使用相鄰 entry 的 segment 距離', (tester) async {
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
              travel: Travel(type: 'car', distanceM: 999999),
            ),
            TimelineEntry(
              id: 13,
              sortOrder: 2,
              version: 0,
              title: 'C',
              travel: Travel(type: 'car', distanceM: 999999),
            ),
          ],
        ),
        segments: const [
          TripSegment(
            id: 1,
            fromEntryId: 11,
            toEntryId: 12,
            mode: 'driving',
            distanceM: 5000,
            version: 1,
          ),
          TripSegment(
            id: 2,
            fromEntryId: 12,
            toEntryId: 13,
            mode: 'driving',
            distanceM: 7000,
            version: 1,
          ),
        ],
      );

      expect(find.text('3 個停留點 · 12 km'), findsOneWidget);
      expect(find.textContaining('2000'), findsNothing);
    });

    testWidgets('當日時間範圍：取 timeline min–max（en dash）', (tester) async {
      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 1,
          version: 0,
          timeline: [
            TimelineEntry(
              id: 11,
              sortOrder: 0,
              version: 0,
              startTime: '09:00',
              endTime: '10:30',
              title: 'A',
            ),
            TimelineEntry(
              id: 12,
              sortOrder: 1,
              version: 0,
              startTime: '13:00',
              endTime: '17:00',
              title: 'B',
            ),
          ],
        ),
      );
      // U+2013 en dash
      expect(find.text('09:00–17:00'), findsOneWidget);
    });

    testWidgets('200% Dynamic Type 會換行且不溢出', (tester) async {
      tester.view.physicalSize = const Size(358, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 1,
          version: 0,
          timeline: [
            TimelineEntry(
              id: 11,
              sortOrder: 0,
              version: 0,
              startTime: '09:00',
              endTime: '17:00',
              title: 'A',
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('DAY 01'), findsOneWidget);
      expect(find.text('09:00–17:00'), findsOneWidget);
    });

    testWidgets('timeline 無任何時間 → 不顯示時間範圍', (tester) async {
      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 1,
          version: 0,
          timeline: [
            TimelineEntry(id: 11, sortOrder: 0, version: 0, title: 'A'),
          ],
        ),
      );
      expect(find.textContaining('–'), findsNothing);
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
