import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox, RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/features/trip_detail/widgets/timeline_entry_tile.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

Future<void> pumpTile(
  WidgetTester tester,
  TimelineEntry entry, {
  int number = 1,
  bool isFirst = false,
  bool expanded = false,
  VoidCallback? onTap,
  Widget? expandedChild,
  Widget? mapLinks,
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
            expanded: expanded,
            onTap: onTap,
            expandedChild: expandedChild,
            mapLinks: mapLinks,
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

/// 七個欄位(行程描述、地點描述、行程備註、地點備註、價格、營業時間、訂位)全滿的停留點。
const _sevenFieldEntry = TimelineEntry(
  id: 60,
  sortOrder: 0,
  version: 1,
  startTime: '09:30',
  endTime: '11:00',
  title: '美麗海水族館',
  description: '黑潮之海旁集合',
  note: '行程備註：帶泳具',
  master: EntryPoiInfo(
    poiId: 601,
    name: '沖縄美ら海水族館',
    type: 'attraction',
    category: '景點',
    description: '世界最大級水槽',
    note: '3-37 Toyosaki, Tomigusuku, Okinawa 901-0225日本',
    price: '成人 2180 日圓',
    hours: '08:30–18:30',
    reservation: '線上預約可享折扣',
  ),
);

const _sevenFieldTexts = [
  '黑潮之海旁集合',
  '備註：行程備註：帶泳具',
  '世界最大級水槽',
  '備註：3-37 Toyosaki, Tomigusuku, Okinawa 901-0225日本',
  '成人 2180 日圓',
  '08:30–18:30',
  '線上預約可享折扣',
];

void main() {
  group('TimelineEntryTile 收合與展開', () {
    testWidgets('收合時七個欄位一個都畫不出來，標題/時間/分類/地圖按鈕仍在', (tester) async {
      await pumpTile(
        tester,
        _sevenFieldEntry,
        onTap: () {},
        mapLinks: TextButton(
          key: const ValueKey('test-map-link'),
          onPressed: () {},
          child: const Text('Google 地圖'),
        ),
      );

      expect(find.byKey(const ValueKey('entry-details-60')), findsNothing);
      for (final text in _sevenFieldTexts) {
        expect(
          find.textContaining(text, findRichText: true),
          findsNothing,
          reason: '收合狀態不得畫出「$text」',
        );
      }

      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('09：30 - 11：00'), findsOneWidget);
      expect(find.text('景點'), findsOneWidget);
      expect(find.byKey(const ValueKey('test-map-link')), findsOneWidget);
    });

    testWidgets('長備註不再撐高收合的卡片 —— 與沒有備註時同高', (tester) async {
      await pumpTile(tester, _sevenFieldEntry, onTap: () {});
      final withDetails = tester.getSize(
        find.byKey(const ValueKey('entry-card-60')),
      );

      await pumpTile(
        tester,
        const TimelineEntry(
          id: 60,
          sortOrder: 0,
          version: 1,
          startTime: '09:30',
          endTime: '11:00',
          title: '美麗海水族館',
          master: EntryPoiInfo(
            poiId: 601,
            name: '沖縄美ら海水族館',
            type: 'attraction',
            category: '景點',
          ),
        ),
        onTap: () {},
      );
      final withoutDetails = tester.getSize(
        find.byKey(const ValueKey('entry-card-60')),
      );

      expect(withDetails.height, withoutDetails.height);
    });

    testWidgets('展開後七個欄位可見，且與備選景點同在卡片下方的展開區', (tester) async {
      await pumpTile(
        tester,
        _sevenFieldEntry,
        expanded: true,
        onTap: () {},
        expandedChild: Container(
          key: const ValueKey('test-alternates'),
          height: 40,
          color: const Color(0xFF00FF00),
        ),
      );

      for (final text in _sevenFieldTexts) {
        expect(
          find.textContaining(text, findRichText: true),
          findsOneWidget,
          reason: '展開後必須看得到「$text」',
        );
      }

      final card = tester.getRect(find.byKey(const ValueKey('entry-card-60')));
      final details = tester.getRect(
        find.byKey(const ValueKey('entry-details-60')),
      );
      final alternates = tester.getRect(
        find.byKey(const ValueKey('test-alternates')),
      );
      expect(
        details.top,
        greaterThanOrEqualTo(card.bottom),
        reason: '欄位要落在收合卡片之外的展開區',
      );
      expect(
        alternates.top,
        greaterThanOrEqualTo(details.bottom),
        reason: '欄位與備選景點同一個展開區，欄位在上',
      );
      expect(alternates.left, closeTo(card.left, 0.1), reason: '展開區與收合卡片左緣切齊');
      expect(details.left, greaterThanOrEqualTo(alternates.left));
    });

    testWidgets('七個欄位與備選景點皆空 → 沒有可點但展不開的空殼', (tester) async {
      var taps = 0;
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 61,
          sortOrder: 0,
          version: 1,
          startTime: '09:30',
          title: '沒有任何細節的停留點',
        ),
        onTap: () => taps++,
      );

      final semantics = tester.ensureSemantics();
      await tester.tap(find.text('沒有任何細節的停留點'));
      await tester.pumpAndSettle();
      expect(taps, 0, reason: '沒東西可展開就不該吃點擊');

      final node = tester.getSemantics(
        find.byKey(const ValueKey('timeline-entry-content-61')),
      );
      expect(node.getSemanticsData().flagsCollection.isButton, isFalse);
      expect(node.getSemanticsData().hint, isEmpty);
      expect(
        node.getSemanticsData().flagsCollection.isExpanded,
        Tristate.none,
        reason: '不該對讀螢幕宣告可展開',
      );
      semantics.dispose();
    });

    testWidgets('只有備選景點、七個欄位全空時仍可展開', (tester) async {
      var taps = 0;
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 62,
          sortOrder: 0,
          version: 1,
          title: '只有備選的停留點',
          alternates: [EntryPoiInfo(poiId: 620, name: '備選景點')],
        ),
        onTap: () => taps++,
      );

      await tester.tap(find.text('只有備選的停留點'));
      expect(taps, 1);
    });

    testWidgets('無障礙提示描述整個展開區，不再只提備選景點', (tester) async {
      final semantics = tester.ensureSemantics();

      await pumpTile(tester, _sevenFieldEntry, onTap: () {});
      var node = tester.getSemantics(
        find.byKey(const ValueKey('timeline-entry-content-60')),
      );
      expect(node.getSemanticsData().hint, '點兩下展開停留點細節');

      await pumpTile(tester, _sevenFieldEntry, expanded: true, onTap: () {});
      node = tester.getSemantics(
        find.byKey(const ValueKey('timeline-entry-content-60')),
      );
      expect(node.getSemanticsData().hint, '點兩下收合停留點細節');
      semantics.dispose();
    });

    testWidgets('放大字級時收合的卡片仍排得下標題與時間', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpTile(
        tester,
        _sevenFieldEntry,
        onTap: () {},
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('09：30 - 11：00'), findsOneWidget);
      expect(find.byKey(const ValueKey('entry-details-60')), findsNothing);
    });
  });

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
      expect(find.text('09：30'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('景點'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('世界最大級水槽'), findsNothing, reason: '描述已收進展開區');
    });

    testWidgets('展開後完整顯示多行備註，不截斷或改成刪節號', (tester) async {
      const note = '第一行：集合地點\n第二行：取票方式\n第三行：預約代碼\n第四行：飲食需求\n第五行：其他提醒';
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 48,
          sortOrder: 0,
          version: 1,
          title: '首里城',
          description: note,
        ),
        expanded: true,
        onTap: () {},
      );

      final details = tester.widget<Text>(
        find.byKey(const ValueKey('entry-details-48')),
      );
      expect(details.data, contains(note));
      expect(details.maxLines, isNull);
      expect(details.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('地點 POI note 以備註標示呈現，不與行程 description 混淆', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 49,
          sortOrder: 0,
          version: 1,
          title: '首里城',
          description: '使用者行程備註',
          note: '地點資料備註',
        ),
        expanded: true,
        onTap: () {},
      );

      final details = tester.widget<Text>(
        find.byKey(const ValueKey('entry-details-49')),
      );
      expect(details.data, startsWith('使用者行程備註\n'));
      expect(details.data, contains('備註：地點資料備註'));
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

    testWidgets('所有 POI 類型共用 Tripline accent 圓點', (tester) async {
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
      expect(dotColor(tester, 2), TpSystemColorsLight.tintDeep);
    });

    testWidgets('POI 類型不改變中性卡片 surface 與邊框', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 20,
          sortOrder: 0,
          version: 0,
          title: '暖暮拉麵',
          master: EntryPoiInfo(poiId: 1, type: 'restaurant'),
        ),
      );

      final decoration =
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey('entry-card-20')),
                  )
                  .decoration!
              as BoxDecoration;
      final colors = AppTheme.light().colorScheme;
      expect(decoration.color, colors.surfaceContainerLow);
      expect(decoration.border!.top.color, colors.outlineVariant);
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
      expect(dotColor(tester, 3), TpSystemColorsLight.tintDeep);
      expect(find.text('14：00'), findsOneWidget);
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
                description: '正殿復原工程中',
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

    testWidgets('時間與地圖控制不會誤觸卡片展開', (tester) async {
      var cardTaps = 0;
      var timeTaps = 0;
      var mapTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TimelineEntryTile(
              entry: const TimelineEntry(
                id: 13,
                sortOrder: 0,
                version: 1,
                startTime: '09:30',
                title: '互動測試',
                description: '有細節，所以卡片可展開',
              ),
              number: 1,
              onTap: () => cardTaps++,
              onEditTime: () => timeTaps++,
              mapLinks: TextButton(
                key: const ValueKey('test-map-link'),
                onPressed: () => mapTaps++,
                child: const Text('Google 地圖'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('entry-time-13')));
      await tester.tap(find.byKey(const ValueKey('test-map-link')));
      expect(timeTaps, 1);
      expect(mapTaps, 1);
      expect(cardTaps, 0);
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
                description: '正殿復原工程中',
                master: EntryPoiInfo(poiId: 2, type: 'attraction'),
              ),
              number: 1,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('首里城，09：30，景點'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('首里城，09：30，景點'));
      expect(node.getSemanticsData().hint, '點兩下展開停留點細節');
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        node.getSemanticsData().flagsCollection.isExpanded,
        Tristate.isFalse,
      );
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

      expect(find.text('09：30 - 11：00'), findsOneWidget);
      expect(find.text('09:30'), findsNothing);
      final semanticsNode = tester.getSemantics(
        find.byKey(const ValueKey('timeline-entry-content-40')),
      );
      expect(semanticsNode.getSemanticsData().label, contains('09：30 - 11：00'));
      semantics.dispose();
    });

    testWidgets('iOS Large keeps the complete range on one visible line', (
      tester,
    ) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 43,
          sortOrder: 0,
          version: 1,
          startTime: '20:50',
          endTime: '21:50',
          title: '那覇空港',
        ),
        textScaler: const TextScaler.linear(1.25),
      );

      expect(find.text('20：50 - 21：50'), findsOneWidget);
      expect(tester.widget<Text>(find.text('那覇空港')).style?.fontSize, 15);
      expect(kTimelineRailWidth, 32);
      expect(
        find.byKey(const ValueKey('timeline-entry-d1-43')),
        findsOneWidget,
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('entry-dot-43'))).dy,
        closeTo(
          tester.getCenter(find.byKey(const ValueKey('entry-card-43'))).dy,
          1,
        ),
        reason: '停留點編號需與主卡片垂直置中',
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('entry-dot-43'))),
        const Size(22, 22),
      );
    });

    testWidgets(
      'metadata stacks time with duration above category with rating',
      (tester) async {
        await pumpTile(
          tester,
          const TimelineEntry(
            id: 44,
            sortOrder: 0,
            version: 1,
            startTime: '12:00',
            endTime: '12:45',
            title: '首里城',
            master: EntryPoiInfo(
              poiId: 502,
              type: 'attraction',
              category: 'tourist_attraction',
              rating: 4.7,
            ),
          ),
        );

        final time = tester.getRect(
          find.byKey(const ValueKey('entry-time-44')),
        );
        final duration = tester.getRect(
          find.byKey(const ValueKey('entry-duration-44')),
        );
        final category = tester.getRect(
          find.byKey(const ValueKey('entry-category-44')),
        );
        final rating = tester.getRect(
          find.byKey(const ValueKey('entry-rating-44')),
        );
        expect((time.center.dy - duration.center.dy).abs(), lessThan(5));
        expect((category.center.dy - rating.center.dy).abs(), lessThan(5));
        expect(category.top, greaterThan(time.bottom));
        expect(find.text('45 min'), findsOneWidget);
      },
    );

    testWidgets('legacy time fallback also drives the displayed duration', (
      tester,
    ) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 47,
          sortOrder: 0,
          version: 1,
          time: '12:00',
          endTime: '12:45',
          title: '舊資料停留點',
        ),
      );

      expect(find.text('12：00 - 12：45'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets(
      'first stop rail starts at the centered marker for a dynamic-height card',
      (tester) async {
        await pumpTile(
          tester,
          const TimelineEntry(
            id: 46,
            sortOrder: 0,
            version: 1,
            title: '第一個會因為標題折成兩行而長高的停留點，標題本身就夠長了',
          ),
          isFirst: true,
        );

        final dot = tester.getRect(find.byKey(const ValueKey('entry-dot-46')));
        final rail = tester.getRect(
          find.byKey(const ValueKey('entry-rail-line-46')),
        );
        expect(rail.top, closeTo(dot.center.dy, 0.1));
        expect(rail.bottom, greaterThan(dot.bottom));
      },
    );

    testWidgets(
      'last stop rail continues below its marker and across spacing',
      (tester) async {
        await pumpTile(
          tester,
          const TimelineEntry(id: 45, sortOrder: 0, version: 1, title: '那覇空港'),
          number: 3,
        );

        final dot = tester.getRect(find.byKey(const ValueKey('entry-dot-45')));
        final rail = tester.getRect(
          find.byKey(const ValueKey('entry-rail-line-45')),
        );
        final gap = tester.getRect(
          find.byKey(const ValueKey('entry-rail-gap-45')),
        );
        expect(rail.bottom, greaterThan(dot.bottom));
        expect(gap.height, TpSpacing.s3);
        expect(gap.top, closeTo(rail.bottom, 0.1));
      },
    );

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
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        find.byKey(const ValueKey('timeline-entry-d1-42')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('很長但仍需要完整閱讀的景點名稱'), findsOneWidget);
      expect(find.text('09：30 - 11：00'), findsOneWidget);
    });

    testWidgets('maximum accessibility text keeps the time range on one line', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpTile(
        tester,
        const TimelineEntry(
          id: 48,
          sortOrder: 0,
          version: 1,
          startTime: '12:00',
          endTime: '12:45',
          title: '大字體停留點',
        ),
        textScaler: const TextScaler.linear(3),
      );

      expect(tester.takeException(), isNull);
      final timeFinder = find.text('12：00 - 12：45');
      final timeText = tester.widget<Text>(timeFinder);
      expect(timeText.maxLines, 1);
      expect(timeText.softWrap, isFalse);
      final timeChip = tester.widget<ActionChip>(
        find.byKey(const ValueKey('entry-time-48')),
      );
      expect(
        timeChip.avatar,
        isNull,
        reason: '大字級時移除裝飾性圖示，把寬度留給完整時間與 Dynamic Type',
      );

      final paragraph = tester.renderObject<RenderParagraph>(timeFinder);
      final naturalSize = paragraph.getDryLayout(const BoxConstraints());
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(naturalSize.width - 0.1),
        reason: '完整起訖時間不得被 ActionChip 的 fade overflow 裁掉',
      );
      final timeBox = tester.renderObject<RenderBox>(timeFinder);
      final paintedStart = timeBox.localToGlobal(Offset.zero);
      final paintedEnd = timeBox.localToGlobal(Offset(timeBox.size.width, 0));
      final chipWidth = tester
          .getSize(find.byKey(const ValueKey('entry-time-48')))
          .width;
      expect(
        paintedEnd.dx - paintedStart.dx,
        lessThan(chipWidth),
        reason: '定版要求不折行；實際繪製後的完整時間必須落在 chip 內',
      );
    });
  });
}
