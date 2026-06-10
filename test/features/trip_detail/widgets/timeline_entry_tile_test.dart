import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/features/trip_detail/widgets/timeline_entry_tile.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpTile(
  WidgetTester tester,
  TimelineEntry entry, {
  bool isFirst = false,
  bool isLast = false,
}) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: TimelineEntryTile(entry: entry, isFirst: isFirst, isLast: isLast),
    ),
  ));
}

Color dotColor(WidgetTester tester, int entryId) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey('entry-dot-$entryId')),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  const tones = TpTones.light;

  group('TimelineEntryTile', () {
    testWidgets('顯示時間、標題、master meta（名稱/分類/評分)', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 1,
          sortOrder: 0,
          version: 0,
          startTime: '09:30',
          title: '美麗海水族館',
          description: '世界最大級水槽',
          master: EntryPoiInfo(
            poiId: 100,
            name: '沖縄美ら海水族館',
            type: 'attraction',
            category: '景點',
            rating: 4.6,
          ),
        ),
      );
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('沖縄美ら海水族館'), findsOneWidget); // master.name ≠ title 才顯示
      expect(find.text('景點'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('世界最大級水槽'), findsOneWidget);
    });

    testWidgets('圓點色依 tone:restaurant → pinkDeep', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 2,
          sortOrder: 0,
          version: 0,
          title: '暖暮拉麵',
          master: EntryPoiInfo(poiId: 1, type: 'restaurant'),
        ),
      );
      expect(dotColor(tester, 2), tones.pinkDeep);
    });

    testWidgets('master 為 null → accentDeep;startTime 缺則用 time', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 3,
          sortOrder: 0,
          version: 0,
          time: '14:00',
          title: '自由活動',
        ),
      );
      expect(dotColor(tester, 3), tones.accentDeep);
      expect(find.text('14:00'), findsOneWidget);
    });
  });
}
