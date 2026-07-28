import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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
      expect(find.text('世界最大級水槽'), findsOneWidget);
    });

    testWidgets('完整顯示多行備註，不截斷或改成刪節號', (tester) async {
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

    testWidgets('地圖控制不會誤觸卡片展開，時間則跟著卡片一起展開', (tester) async {
      var cardTaps = 0;
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
              ),
              number: 1,
              onTap: () => cardTaps++,
              mapLinks: TextButton(
                key: const ValueKey('test-map-link'),
                onPressed: () => mapTaps++,
                child: const Text('Google 地圖'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('test-map-link')));
      expect(mapTaps, 1);
      expect(cardTaps, 0, reason: '地圖控制有自己的動作，不該再冒泡到卡片');

      // 時間沒有自己的動作，點它等同點卡片 —— 卡片中央不留死區。
      await tester.tap(find.byKey(const ValueKey('entry-time-13')));
      expect(cardTaps, 1);
      expect(mapTaps, 1);
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

      expect(find.bySemanticsLabel('首里城，09：30，景點'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('首里城，09：30，景點'));
      expect(node.getSemanticsData().hint, '點兩下展開備選景點');
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
            title: '第一個會因內容增高的停留點',
            description: '使用較多內容讓卡片高度不再等於固定的圓點位置。',
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
      expect(
        find.byIcon(CupertinoIcons.clock),
        findsNothing,
        reason: '大字級時移除裝飾性圖示，把寬度留給完整時間與 Dynamic Type',
      );

      final paragraph = tester.renderObject<RenderParagraph>(timeFinder);
      final naturalSize = paragraph.getDryLayout(const BoxConstraints());
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(naturalSize.width - 0.1),
        reason: '完整起訖時間不得被截斷或改成刪節號',
      );
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('entry-card-48')),
      );
      final paintedTime = tester.getRect(timeFinder);
      expect(
        paintedTime.left,
        greaterThanOrEqualTo(cardRect.left),
        reason: '定版要求不折行；實際繪製後的完整時間必須落在卡片內',
      );
      expect(
        paintedTime.right,
        lessThanOrEqualTo(cardRect.right),
        reason: '定版要求不折行；實際繪製後的完整時間必須落在卡片內',
      );
    });

    testWidgets('時間在語意上不是按鈕，也沒有點擊動作', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 60,
          sortOrder: 0,
          version: 1,
          startTime: '09:30',
          endTime: '11:00',
          title: '純顯示時間',
        ),
      );

      final node = tester.getSemantics(find.text('09：30 - 11：00'));
      final data = node.getSemanticsData();
      expect(
        data.flagsCollection.isButton,
        isFalse,
        reason: '時間是純顯示，讀螢幕不該把它念成按鈕',
      );
      expect(
        data.hasAction(SemanticsAction.tap),
        isFalse,
        reason: '時間不該提供「點兩下以啟動」的動作',
      );
      semantics.dispose();
    });

    testWidgets('時間貼合文字高度，不再撐出 chip 的最小點擊區', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 61,
          sortOrder: 0,
          version: 1,
          startTime: '09:30',
          endTime: '11:00',
          title: '純顯示時間',
        ),
      );

      expect(
        find.byType(ActionChip),
        findsNothing,
        reason: '時間不得再做成 ActionChip',
      );
      final timeBox = tester.getRect(
        find.byKey(const ValueKey('entry-time-61')),
      );
      final timeText = tester.getRect(find.text('09：30 - 11：00'));
      expect(
        timeBox.height,
        closeTo(timeText.height, 1),
        reason: '純顯示的時間只佔文字高度，不再帶按鈕的內距與最小點擊區',
      );
    });

    testWidgets('點時間與點卡片本體一樣會展開，整張卡行為一致', (tester) async {
      await tester.pumpWidget(
        const _ExpandableTileHost(
          entry: TimelineEntry(
            id: 62,
            sortOrder: 0,
            version: 1,
            startTime: '09:30',
            endTime: '11:00',
            title: '互動測試',
          ),
        ),
      );

      // 時間是純顯示（不是按鈕、沒有自己的動作），但它就長在卡片上，
      // 點它與點卡片其他地方一樣展開 —— 不留一塊點了沒反應的死區。
      await tester.tap(find.text('09：30 - 11：00'));
      await tester.pumpAndSettle();
      expect(find.text('展開後的細節'), findsOneWidget, reason: '點時間應展開');

      await tester.tap(find.text('互動測試'));
      await tester.pumpAndSettle();
      expect(
        find.text('展開後的細節'),
        findsNothing,
        reason: '對照組：再點一次收合，證明上面的斷言不是恆真',
      );
    });
  });
}

/// 讓 `expanded` 真的隨點擊變動的宿主，測「點下去畫面有沒有變」而非 callback。
class _ExpandableTileHost extends StatefulWidget {
  const _ExpandableTileHost({required this.entry});

  final TimelineEntry entry;

  @override
  State<_ExpandableTileHost> createState() => _ExpandableTileHostState();
}

class _ExpandableTileHostState extends State<_ExpandableTileHost> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TimelineEntryTile(
          entry: widget.entry,
          number: 1,
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
          expandedChild: _expanded ? const Text('展開後的細節') : null,
        ),
      ),
    );
  }
}
