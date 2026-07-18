import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/features/trip_detail/widgets/timeline_entry_tile.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpTile(
  WidgetTester tester,
  TimelineEntry entry, {
  int number = 1,
  bool isFirst = false,
  bool isLast = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: TimelineEntryTile(
            entry: entry,
            number: number,
            isFirst: isFirst,
            isLast: isLast,
          ),
        ),
      ),
    ),
  );
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

    testWidgets('英文 master.category 顯示細類中文 label，不外露 primaryType', (
      tester,
    ) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 8,
          sortOrder: 0,
          version: 0,
          title: '暖暮拉麵',
          master: EntryPoiInfo(
            poiId: 101,
            type: 'restaurant',
            category: 'ramen_restaurant',
          ),
        ),
      );

      expect(find.text('拉麵店'), findsOneWidget);
      expect(find.text('ramen_restaurant'), findsNothing);
    });

    testWidgets('純中文 master.category 顯示原樣', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 9,
          sortOrder: 0,
          version: 0,
          title: '岸本食堂',
          master: EntryPoiInfo(poiId: 102, type: 'restaurant', category: '沖繩麵'),
        ),
      );

      expect(find.text('沖繩麵'), findsOneWidget);
      expect(find.text('景點'), findsNothing);
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

    testWidgets('master 為 null → accentDeep;startTime 缺則用 time', (
      tester,
    ) async {
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

    testWidgets('rail badge 顯示停留點編號', (tester) async {
      await pumpTile(
        tester,
        number: 3,
        const TimelineEntry(id: 7, sortOrder: 0, version: 0, title: '首里城'),
      );
      final badge = find.byKey(const ValueKey('entry-dot-7'));
      expect(badge, findsOneWidget);
      expect(
        find.descendant(of: badge, matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('start + end 皆有 → 顯示時長', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 4,
          sortOrder: 0,
          version: 0,
          startTime: '09:00',
          endTime: '11:00',
          title: '美麗海水族館',
        ),
      );
      expect(find.text('2 hr'), findsOneWidget);
    });

    testWidgets('缺 endTime → 不顯示時長', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 5,
          sortOrder: 0,
          version: 0,
          startTime: '09:00',
          title: '美麗海水族館',
        ),
      );
      expect(find.textContaining('hr'), findsNothing);
    });

    testWidgets('有 onTap：點內容卡觸發 callback', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TimelineEntryTile(
              entry: const TimelineEntry(
                id: 11,
                sortOrder: 0,
                version: 1,
                title: '首里城',
              ),
              number: 1,
              onTap: () => tapped++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('首里城'));
      expect(tapped, 1);
    });

    testWidgets('內容卡以單一語意朗讀名稱、時間、類型與動作', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TimelineEntryTile(
              entry: const TimelineEntry(
                id: 12,
                sortOrder: 0,
                version: 1,
                startTime: '09:30',
                title: '首里城',
                master: EntryPoiInfo(poiId: 2, type: 'attraction'),
              ),
              number: 1,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('首里城，09:30，景點'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('首里城，09:30，景點'));
      expect(node.getSemanticsData().hint, '點兩下編輯停留點');
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('shows start and end time and announces the complete range', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 40,
          sortOrder: 0,
          version: 1,
          startTime: '09:30',
          endTime: '11:00',
          title: '清水寺',
        ),
      );

      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('– 11:00'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('09:30 到 11:00')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Google primary type is the first secondary row', (
      tester,
    ) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 41,
          sortOrder: 0,
          version: 1,
          title: '一蘭拉麵',
          master: EntryPoiInfo(
            poiId: 501,
            type: 'restaurant',
            category: 'ramen_restaurant',
          ),
        ),
      );

      expect(find.byKey(const ValueKey('entry-category-41')), findsOneWidget);
      expect(find.text('拉麵店'), findsOneWidget);
      expect(find.text('ramen_restaurant'), findsNothing);
    });

    testWidgets('accessibility text uses stacked layout without overflow', (
      tester,
    ) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 42,
          sortOrder: 0,
          version: 1,
          startTime: '09:30',
          endTime: '11:00',
          title: '很長但仍需要完整閱讀的景點名稱',
          master: EntryPoiInfo(poiId: 502, category: 'tourist_attraction'),
        ),
        textScaler: const TextScaler.linear(2),
      );

      expect(
        find.byKey(const ValueKey('timeline-entry-accessibility-42')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('很長但仍需要完整閱讀的景點名稱'), findsOneWidget);
    });
  });
}
