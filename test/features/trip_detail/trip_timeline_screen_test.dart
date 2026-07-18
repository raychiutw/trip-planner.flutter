import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/day_weather.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/trip_timeline_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';

const _tripId = 'okinawa-2026';

class _MockTripRepository extends Mock implements TripRepository {}

const _fakeTrip = Trip(id: _tripId, name: '沖繩自駕 2026', title: '沖繩自駕五日');

/// 假 2 天行程：day 1 含 hotel + 三色 entries + travel；day 2 含 sage（transport）entry。
const _fakeDays = [
  TripDay(
    id: 1,
    dayNum: 1,
    date: '2026-04-23',
    dayOfWeek: '四',
    title: '北部海岸線',
    version: 1,
    hotel: DayHotel(id: 9, name: '美國村海濱飯店', checkout: '10:00'),
    timeline: [
      TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '09:00',
        title: '美麗海水族館',
        version: 1,
        travel: Travel(type: 'car', min: 15),
        master: EntryPoiInfo(
          poiId: 101,
          name: '沖繩美麗海水族館',
          type: 'attraction',
          category: '景點',
          rating: 4.6,
        ),
      ),
      TimelineEntry(
        id: 12,
        sortOrder: 1,
        startTime: '12:30',
        title: '海人食堂',
        version: 1,
        travel: Travel(type: 'walk', min: 10),
        master: EntryPoiInfo(
          poiId: 102,
          name: '海人食堂',
          type: 'restaurant',
          category: '美食',
          rating: 4.2,
        ),
      ),
      TimelineEntry(
        id: 13,
        sortOrder: 2,
        startTime: '14:30',
        title: '美國村購物',
        version: 1,
        travel: Travel(type: 'car', min: 8),
        master: EntryPoiInfo(
          poiId: 103,
          name: '美國村',
          type: 'shopping',
          category: '購物',
        ),
      ),
      TimelineEntry(
        id: 14,
        sortOrder: 3,
        startTime: '16:00',
        title: '日落海灘',
        version: 1,
        master: EntryPoiInfo(poiId: 104, name: '日落海灘', type: 'activity'),
      ),
    ],
  ),
  TripDay(
    id: 2,
    dayNum: 2,
    date: '2026-04-24',
    dayOfWeek: '五',
    title: '南部文化',
    version: 1,
    timeline: [
      TimelineEntry(
        id: 21,
        sortOrder: 0,
        startTime: '10:00',
        title: '單軌電車移動',
        version: 1,
        travel: Travel(type: 'monorail', min: 20),
        master: EntryPoiInfo(poiId: 201, name: '沖繩都市單軌電車', type: 'transport'),
      ),
      TimelineEntry(
        id: 22,
        sortOrder: 1,
        startTime: '11:00',
        title: '首里城公園',
        version: 1,
        master: EntryPoiInfo(
          poiId: 202,
          name: '首里城',
          type: 'attraction',
          rating: 4.4,
        ),
      ),
    ],
  ),
];

const _computableTravelGapDays = [
  TripDay(
    id: 1,
    dayNum: 1,
    title: '北部海岸線',
    version: 1,
    timeline: [
      TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '09:00',
        title: '美麗海水族館',
        version: 1,
        travel: Travel(type: 'car', min: 15),
        master: EntryPoiInfo(
          poiId: 101,
          name: '沖繩美麗海水族館',
          lat: 26.6942,
          lng: 127.8778,
          type: 'attraction',
        ),
      ),
      TimelineEntry(
        id: 12,
        sortOrder: 1,
        startTime: '12:30',
        title: '海人食堂',
        version: 1,
        master: EntryPoiInfo(
          poiId: 102,
          name: '海人食堂',
          lat: 26.6501,
          lng: 127.9294,
          type: 'restaurant',
        ),
      ),
    ],
  ),
];

/// 以 create callback 注入假資料（flutter_riverpod 3.x 未匯出 Override 型別，
/// 故在此 helper 內 inline 組 overrides，型別交由推斷）。
Future<void> _pumpTimeline(
  WidgetTester tester, {
  FutureOr<Trip> Function()? fetchTrip,
  FutureOr<List<TripDay>> Function()? fetchDays,
  Stream<List<TripDay>>? daysStream,
  _MockTripRepository? repo,
  String tripId = _tripId,
  List<TripSegment> segments = const [],
  int? initialEntryId,
  int? initialDayNum,
  DayWeatherFetcher? dayWeatherFetcher,
  bool disableAnimations = false,
  TextScaler? textScaler,
}) async {
  final router = GoRouter(
    initialLocation: '/trips/$tripId',
    routes: [
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => TripTimelineScreen(
          tripId: state.pathParameters['tripId']!,
          initialEntryId: initialEntryId,
          initialDayNum: initialDayNum,
        ),
        routes: [
          GoRoute(
            path: 'notes',
            builder: (context, state) =>
                const Scaffold(body: Text('notes-page')),
          ),
          GoRoute(
            path: 'print',
            builder: (context, state) =>
                const Scaffold(body: Text('print-page')),
          ),
          GoRoute(
            path: 'audit',
            builder: (context, state) =>
                const Scaffold(body: Text('audit-page')),
          ),
          GoRoute(
            path: 'health',
            builder: (context, state) =>
                const Scaffold(body: Text('health-page')),
          ),
          GoRoute(
            path: 'entries/new',
            builder: (context, state) => Scaffold(
              body: Text(
                'entry-add-${state.uri.queryParameters['mode']}-${state.uri.queryParameters['day']}',
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => Scaffold(
          body: Text(
            'map-page-${state.uri.queryParameters['tripId']}-${state.uri.queryParameters['day']}',
          ),
        ),
      ),
      GoRoute(
        path: '/collab/:tripId',
        builder: (context, state) => const Scaffold(body: Text('collab-page')),
      ),
      GoRoute(
        path: '/share-trip/:tripId',
        builder: (context, state) => const Scaffold(body: Text('share-page')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      // 關閉 riverpod 3 預設自動 retry：error 測試需要 provider 停在 AsyncError
      retry: (retryCount, error) => null,
      overrides: [
        // StreamProvider override 需回 Stream；以 Stream.fromFuture(Future.sync(...))
        // 包裝 helper 的 FutureOr callback，同時保留同步 throw / 永不完成的語意。
        tripDetailProvider(tripId).overrideWith(
          (ref) => Stream.fromFuture(
            Future.sync(() => (fetchTrip ?? () => _fakeTrip)()),
          ),
        ),
        tripDaysProvider(tripId).overrideWith(
          (ref) =>
              daysStream ??
              Stream.fromFuture(
                Future.sync(() => (fetchDays ?? () => _fakeDays)()),
              ),
        ),
        tripSegmentsProvider(
          tripId,
        ).overrideWith((ref) => Stream.value(segments)),
        if (repo != null) tripRepositoryProvider.overrideWithValue(repo),
        if (dayWeatherFetcher != null)
          dayWeatherFetcherProvider.overrideWithValue(dayWeatherFetcher),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: textScaler,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
}

List<TripDay> _longDays(String label) {
  return [
    TripDay(
      id: 1,
      dayNum: 1,
      title: '長列表 $label',
      version: 1,
      timeline: [
        for (var i = 0; i < 30; i++)
          TimelineEntry(
            id: 100 + i,
            sortOrder: i,
            startTime: '${(8 + (i ~/ 2)).toString().padLeft(2, '0')}:00',
            title: '景點 $label-$i',
            version: 1,
            master: EntryPoiInfo(
              poiId: 1000 + i,
              name: '景點 $label-$i',
              type: i.isEven ? 'attraction' : 'restaurant',
            ),
          ),
      ],
    ),
  ];
}

List<TripDay> _scrollSpyDays() => [
  for (var day = 1; day <= 2; day++)
    TripDay(
      id: day,
      dayNum: day,
      date: '2026-07-${(17 + day).toString().padLeft(2, '0')}',
      version: 1,
      timeline: [
        for (var index = 0; index < 12; index++)
          TimelineEntry(
            id: day * 100 + index,
            sortOrder: index,
            startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
            endTime: '${(9 + index).toString().padLeft(2, '0')}:00',
            title: 'DAY $day 景點 $index',
            version: 1,
          ),
      ],
    ),
];

Color _entryDotColor(WidgetTester tester, int entryId) {
  final dotContainer = tester.widget<Container>(
    find.byKey(ValueKey('entry-dot-$entryId')),
  );
  return (dotContainer.decoration! as BoxDecoration).color!;
}

Future<void> _pumpMenuClose(WidgetTester tester) => tester.pumpAndSettle();

Future<void> _enableTimelineEditing(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-edit-mode')));
  await _pumpMenuClose(tester);
}

Future<void> _expectTripActionOpensClosableSheet(
  WidgetTester tester,
  Key actionKey,
) async {
  await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(actionKey));
  await tester.pump();
  await _pumpMenuClose(tester);

  expect(find.byKey(const ValueKey('app-large-screen-sheet')), findsOneWidget);
  expect(find.byKey(const ValueKey('app-large-sheet-close')), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(const ValueKey('app-large-sheet-close')),
      matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
    ),
    findsOneWidget,
  );

  await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('app-large-screen-sheet')), findsNothing);
  expect(find.byKey(const ValueKey('app-large-sheet-close')), findsNothing);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<({int id, int sortOrder, int? dayId})>[]);
  });

  testWidgets('Root Glass Header 顯示行程選擇、功能選單與帳號入口', (tester) async {
    await _pumpTimeline(tester);

    expect(find.byKey(const ValueKey('tp-root-glass-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-title-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
    expect(find.text('沖繩自駕五日'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-timeline-trip-picker')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trip-actions-menu')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-actions-menu')),
        matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(find.widgetWithText(TextButton, '編輯'), findsNothing);
    expect(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trip-section-scope')), findsNothing);
    expect(find.byKey(const ValueKey('trip-timeline-map')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-timeline-day-overview')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('trip-secondary-map')), findsNothing);
    expect(find.byKey(const ValueKey('trip-secondary-notes')), findsNothing);
    expect(find.byIcon(CupertinoIcons.printer), findsNothing);
    expect(find.byIcon(Icons.history_outlined), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-edit-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-action-notes')), findsOneWidget);
  });

  testWidgets('單層 selector 選地圖並保留目前 DAY', (tester) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byKey(const ValueKey('trip-timeline-map')));
    await tester.pumpAndSettle();

    expect(find.text('map-page-$_tripId-1'), findsOneWidget);
  });

  testWidgets('更多選單的列印由下往上開啟共用可關閉 sheet', (tester) async {
    await _pumpTimeline(tester);
    await _expectTripActionOpensClosableSheet(
      tester,
      const ValueKey('trip-action-print'),
    );
  });

  testWidgets('更多選單的異動紀錄由下往上開啟共用可關閉 sheet', (tester) async {
    await _pumpTimeline(tester);
    await _expectTripActionOpensClosableSheet(
      tester,
      const ValueKey('trip-action-audit'),
    );
  });

  testWidgets('更多選單的筆記用內容 sheet，行程資料用表單 sheet', (tester) async {
    await _pumpTimeline(tester);
    await _expectTripActionOpensClosableSheet(
      tester,
      const ValueKey('trip-action-notes'),
    );

    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-action-edit-info')));
    await tester.pump();
    await _pumpMenuClose(tester);

    expect(
      find.byKey(const ValueKey('app-large-screen-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tp-app-bar-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tp-app-bar-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-large-screen-sheet')), findsNothing);
  });

  testWidgets('更多選單收納行程資料、列印、異動紀錄、分享、共編與 AI 健檢', (tester) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-action-edit-info')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-action-print')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-action-audit')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-action-share')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-action-collab')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-action-health')), findsOneWidget);
  });

  testWidgets('閱讀模式隱藏移動與排序控制，點編輯後才顯示', (tester) async {
    await _pumpTimeline(tester);

    expect(find.byKey(const ValueKey('entry-move-to-day-11')), findsNothing);
    expect(find.byKey(const ValueKey('entry-drag-11')), findsNothing);

    await _enableTimelineEditing(tester);

    expect(find.byKey(const ValueKey('entry-move-to-day-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-drag-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-actions-menu')), findsNothing);
    expect(
      find.byKey(const ValueKey('tp-root-header-primary-action')),
      findsOneWidget,
    );
  });

  testWidgets('trip menu enters reorder mode and Done exits directly', (
    tester,
  ) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();

    final reorderAction = find.byKey(const ValueKey('trip-edit-mode'));
    expect(reorderAction, findsOneWidget);
    expect(
      find.descendant(
        of: reorderAction,
        matching: find.byIcon(CupertinoIcons.line_horizontal_3),
      ),
      findsOneWidget,
    );
    expect(find.text('調整順序'), findsOneWidget);
    expect(find.text('編輯行程'), findsNothing);
    expect(find.text('移動行程'), findsNothing);

    await tester.tap(reorderAction);
    await _pumpMenuClose(tester);

    expect(find.byKey(const ValueKey('trip-actions-menu')), findsNothing);
    expect(
      find.byKey(const ValueKey('tp-root-header-primary-action')),
      findsOneWidget,
    );
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('調整順序'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-drag-11')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('tp-root-header-primary-action')),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('entry-drag-11')), findsNothing);
    expect(find.byKey(const ValueKey('trip-actions-menu')), findsOneWidget);
  });

  testWidgets('Move To Day and reorder use matching direct inline controls', (
    tester,
  ) async {
    await _pumpTimeline(tester);
    await _enableTimelineEditing(tester);

    final moveButton = find.byKey(const ValueKey('entry-move-to-day-11'));
    final dragHandle = find.byKey(const ValueKey('entry-drag-11'));
    expect(tester.getSize(moveButton), const Size(44, 44));
    expect(tester.getSize(dragHandle), const Size(44, 44));
    expect(tester.getSemantics(moveButton).label, '移到其他 Day');
    expect(tester.getSemantics(dragHandle).label, '拖曳調整順序');
    expect(
      find.descendant(
        of: moveButton,
        matching: find.byIcon(CupertinoIcons.folder),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('entry-menu-11')), findsNothing);

    await tester.tap(moveButton);
    await tester.pumpAndSettle();
    expect(find.text('移到其他 Day'), findsOneWidget);
  });

  testWidgets('Done keeps its full label at 200 percent text', (tester) async {
    await _pumpTimeline(tester, textScaler: const TextScaler.linear(2));
    await _enableTimelineEditing(tester);

    final done = find.byKey(const ValueKey('tp-root-header-primary-action'));
    expect(
      find.descendant(of: done, matching: find.text('完成')),
      findsOneWidget,
    );
    expect(tester.getSize(done).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(done).width, greaterThan(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('更多選單的分享連結使用共用可關閉 sheet', (tester) async {
    await _pumpTimeline(tester);
    await _expectTripActionOpensClosableSheet(
      tester,
      const ValueKey('trip-action-share'),
    );
  });

  testWidgets('更多選單的共編設定使用共用可關閉 sheet', (tester) async {
    await _pumpTimeline(tester);
    await _expectTripActionOpensClosableSheet(
      tester,
      const ValueKey('trip-action-collab'),
    );
  });

  testWidgets('更多選單的 AI 健檢使用共用可關閉 sheet', (tester) async {
    await _pumpTimeline(tester);
    await _expectTripActionOpensClosableSheet(
      tester,
      const ValueKey('trip-action-health'),
    );
  });

  testWidgets('渲染 2 天 day headers（eyebrow + displayTitle）與 day pills', (
    tester,
  ) async {
    await _pumpTimeline(tester);

    // selector 使用精簡 DAY N；內容 eyebrow 保留兩位數 DAY NN。
    expect(find.text('DAY 1'), findsOneWidget);
    expect(find.text('DAY 2'), findsOneWidget);
    expect(find.text('DAY 01'), findsOneWidget);
    expect(find.text('2026-04-23（四）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    expect(find.text('DAY 02'), findsOneWidget);
    expect(find.text('2026-04-24（五）'), findsOneWidget);
    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-timeline-view-day-selector')),
          )
          .value,
      2,
    );
  });

  testWidgets('entry tile 依 master.type 顯示對應 tone 圓點', (tester) async {
    await _pumpTimeline(tester);

    // attraction → accent、restaurant → pink、transport → sage
    expect(_entryDotColor(tester, 11), TpColorsLight.accentDeep);
    expect(_entryDotColor(tester, 12), TpColorsLight.pinkDeep);

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    expect(_entryDotColor(tester, 21), TpColorsLight.sageDeep);
  });

  testWidgets('travel pill 使用出發 entry 的 travel 顯示各相鄰路段', (tester) async {
    await _pumpTimeline(
      tester,
      segments: const [
        TripSegment(
          id: 50,
          fromEntryId: 11,
          toEntryId: 12,
          mode: 'driving',
          version: 1,
        ),
        TripSegment(
          id: 51,
          fromEntryId: 12,
          toEntryId: 13,
          mode: 'walking',
          version: 1,
        ),
        TripSegment(
          id: 52,
          fromEntryId: 13,
          toEntryId: 14,
          mode: 'driving',
          version: 1,
        ),
        TripSegment(
          id: 53,
          fromEntryId: 21,
          toEntryId: 22,
          mode: 'transit',
          submode: 'monorail',
          version: 1,
        ),
      ],
    );

    expect(find.text('15 分鐘'), findsOneWidget);
    expect(find.text('10 分鐘'), findsOneWidget);
    expect(find.text('8 分鐘'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car), findsNWidgets(2));
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    expect(find.textContaining('20 分鐘'), findsOneWidget);
  });

  testWidgets('stale travel segment 顯示重算中並隱藏舊分鐘數', (tester) async {
    final repo = _MockTripRepository();
    const staleTripId = 'trip-stale-segment';
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _pumpTimeline(
      tester,
      repo: repo,
      tripId: staleTripId,
      fetchDays: () => _computableTravelGapDays,
      segments: [
        TripSegment.fromJson({
          'id': 50,
          'fromEntryId': 11,
          'toEntryId': 12,
          'mode': 'driving',
          'min': 15,
          'distanceM': 11000,
          'version': 1,
          'computedAt': null,
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('車程重新計算中'), findsOneWidget);
    expect(find.text('15 分鐘'), findsNothing);
    verify(() => repo.recomputeTravel(tripId: staleTripId, day: '1')).called(1);
  });

  testWidgets('stale travel segment 缺座標 → 顯示無法計算', (tester) async {
    await _pumpTimeline(
      tester,
      fetchDays: () => const [
        TripDay(
          id: 1,
          dayNum: 1,
          title: '北部海岸線',
          version: 1,
          timeline: [
            TimelineEntry(
              id: 11,
              sortOrder: 0,
              startTime: '09:00',
              title: '美麗海水族館',
              version: 1,
              travel: Travel(type: 'car', min: 15),
              master: EntryPoiInfo(
                poiId: 101,
                name: '沖繩美麗海水族館',
                lat: 26.6942,
                lng: 127.8778,
                type: 'attraction',
              ),
            ),
            TimelineEntry(
              id: 12,
              sortOrder: 1,
              startTime: '12:30',
              title: '海人食堂',
              version: 1,
              master: EntryPoiInfo(
                poiId: 102,
                name: '海人食堂',
                type: 'restaurant',
              ),
            ),
          ],
        ),
      ],
      segments: [
        TripSegment.fromJson({
          'id': 50,
          'fromEntryId': 11,
          'toEntryId': 12,
          'mode': 'driving',
          'min': 15,
          'distanceM': 11000,
          'version': 1,
          'computedAt': null,
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('缺座標，無法計算車程'), findsOneWidget);
    expect(find.text('車程重新計算中'), findsNothing);
    expect(find.text('15 分鐘'), findsNothing);
  });

  testWidgets('缺 travel segment 且兩端有座標 → 自動重算該日', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _pumpTimeline(
      tester,
      repo: repo,
      fetchDays: () => _computableTravelGapDays,
    );
    await tester.pump();

    expect(find.text('車程重新計算中'), findsOneWidget);
    expect(find.text('15 分鐘'), findsNothing);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
  });

  testWidgets('自動重算未回來就離開行程頁 → 不得因 use-after-dispose 崩潰', (tester) async {
    // build() 會 unawaited(_recomputeDay(auto: true))。網路回來前使用者離開,
    // _DaySection 已 unmount,await 之後的 ref.invalidate 會擲 StateError ——
    // 而 StateError 不是 Exception 子類,`on Exception` 攔不到 → 未捕捉例外 → 崩潰。
    // 自成一個 tripId:`_requestedTravelGapRecomputes` 是 module-level static
    // Set 且跨測試不重置,沿用 _tripId 會被前面的自動重算測試佔掉 key 而提早返回
    // (既有的 stalled 測試也是這樣各自獨立)。
    const tripId = 'trip-recompute-unmount';
    final repo = _MockTripRepository();
    final pendingRecompute = Completer<void>();
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) => pendingRecompute.future);

    await _pumpTimeline(
      tester,
      repo: repo,
      tripId: tripId,
      fetchDays: () => _computableTravelGapDays,
    );
    await tester.pump();
    verify(() => repo.recomputeTravel(tripId: tripId, day: '1')).called(1);

    // 使用者在回應抵達前離開 → 整個 section 連同 ref 一起 unmount。
    await tester.pumpWidget(const SizedBox.shrink());

    // 網路這時才回來。
    pendingRecompute.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('自動重算 travel segment 失敗 → 顯示車程待更新', (tester) async {
    final repo = _MockTripRepository();
    const tripId = 'trip-recompute-stalled';
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenThrow(Exception('recompute failed'));

    await _pumpTimeline(
      tester,
      repo: repo,
      tripId: tripId,
      fetchDays: () => _computableTravelGapDays,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('車程待更新'), findsOneWidget);
    expect(find.text('車程重新計算中'), findsNothing);
    verify(() => repo.recomputeTravel(tripId: tripId, day: '1')).called(1);
  });

  testWidgets('缺 travel segment 但缺座標 → 不自動重算', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _pumpTimeline(
      tester,
      repo: repo,
      fetchDays: () => const [
        TripDay(
          id: 1,
          dayNum: 1,
          title: '北部海岸線',
          version: 1,
          timeline: [
            TimelineEntry(
              id: 11,
              sortOrder: 0,
              startTime: '09:00',
              title: '美麗海水族館',
              version: 1,
              travel: Travel(type: 'car', min: 15),
              master: EntryPoiInfo(
                poiId: 101,
                name: '沖繩美麗海水族館',
                lat: 26.6942,
                lng: 127.8778,
                type: 'attraction',
              ),
            ),
            TimelineEntry(
              id: 12,
              sortOrder: 1,
              startTime: '12:30',
              title: '海人食堂',
              version: 1,
              master: EntryPoiInfo(
                poiId: 102,
                name: '海人食堂',
                type: 'restaurant',
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pump();

    expect(find.text('缺座標，無法計算車程'), findsOneWidget);
    expect(find.text('15 分鐘'), findsNothing);
    verifyNever(
      () => repo.recomputeTravel(
        tripId: _tripId,
        day: any(named: 'day'),
      ),
    );
  });

  testWidgets('行程每日不再顯示飯店摘要卡', (tester) async {
    await _pumpTimeline(tester);

    expect(find.text('美國村海濱飯店'), findsNothing);
    expect(find.byKey(const ValueKey('hotel-card-9')), findsNothing);
  });

  testWidgets('行程每日使用明確標示的天氣示意資料樣式', (tester) async {
    await _pumpTimeline(
      tester,
      fetchDays: () => const [
        TripDay(
          id: 91,
          dayNum: 1,
          date: '2026-04-23',
          title: '北部海岸線',
          version: 1,
          timeline: [
            TimelineEntry(
              id: 911,
              sortOrder: 0,
              startTime: '09:00',
              title: '美麗海水族館',
              version: 1,
              master: EntryPoiInfo(
                poiId: 901,
                name: '沖繩美麗海水族館',
                lat: 26.6942,
                lng: 127.8778,
              ),
            ),
          ],
        ),
      ],
      dayWeatherFetcher: (request) =>
          throw StateError('timeline 天氣示意不應呼叫遠端 weather API'),
    );

    expect(find.text('天氣示意'), findsOneWidget);
    expect(find.text('晴時多雲'), findsOneWidget);
    expect(find.text('28°C'), findsOneWidget);
    expect(find.text('降雨 20%'), findsOneWidget);
  });

  testWidgets('itinerary uses one pinned Sliver selector without overview', (
    tester,
  ) async {
    await _pumpTimeline(tester, fetchDays: _scrollSpyDays);
    await tester.pumpAndSettle();

    final timelineScroll = find.byKey(const ValueKey('trip-timeline-scroll'));
    expect(timelineScroll, findsOneWidget);
    expect(tester.widget(timelineScroll), isA<CustomScrollView>());
    expect(tester.getTopLeft(timelineScroll).dy, 0);
    expect(find.byType(PageView), findsNothing);
    expect(
      find.byKey(const ValueKey('trip-timeline-day-overview')),
      findsNothing,
    );

    final selector = find.byKey(
      const ValueKey('trip-timeline-view-day-selector'),
    );
    final topBefore = tester.getTopLeft(selector).dy;
    await tester.drag(timelineScroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(selector).dy, closeTo(topBefore, 0.5));
  });

  testWidgets(
    'vertical scroll updates Day selection and tapping Day scrolls back',
    (tester) async {
      await _pumpTimeline(tester, fetchDays: _scrollSpyDays);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('day-section-2')),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('trip-timeline-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      var selector = tester.widget<TpHorizontalSelector<int>>(
        find.byKey(const ValueKey('trip-timeline-view-day-selector')),
      );
      expect(selector.value, 2);

      await tester.tap(find.byKey(const ValueKey('day-pill-1')));
      await tester.pumpAndSettle();
      selector = tester.widget<TpHorizontalSelector<int>>(
        find.byKey(const ValueKey('trip-timeline-view-day-selector')),
      );
      expect(selector.value, 1);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('day-section-1'))).dy,
        greaterThanOrEqualTo(
          tester
                  .getBottomLeft(
                    find.byKey(
                      const ValueKey('trip-timeline-view-day-selector'),
                    ),
                  )
                  .dy -
              1,
        ),
      );
    },
  );

  testWidgets('Reduce Motion 直接切換 Day，不建立零秒捲動動畫', (tester) async {
    await _pumpTimeline(
      tester,
      fetchDays: _scrollSpyDays,
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-timeline-view-day-selector')),
          )
          .value,
      2,
    );
  });

  testWidgets('指定 initialDayNum：初始啟用該日 pill', (tester) async {
    await _pumpTimeline(tester, initialDayNum: 2);
    await tester.pumpAndSettle();

    final selected = tester.widget<GlassButton>(
      find.descendant(
        of: find.byKey(const ValueKey('day-pill-2')),
        matching: find.byType(GlassButton),
      ),
    );
    expect(selected.settings?.glassColor, TpColorsLight.dayThumb);
  });

  testWidgets('指定 initialEntryId：初始聚焦該停留點卡片', (tester) async {
    await _pumpTimeline(tester, initialEntryId: 22);
    await tester.pumpAndSettle();

    final focusedCard = tester.widget<Container>(
      find.byKey(const ValueKey('entry-card-22')),
    );
    final decoration = focusedCard.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(border.top.color, TpColorsLight.accentDeep);
    expect(border.top.width, 2);
  });

  testWidgets('days refresh preserves current scroll offset', (tester) async {
    final days = StreamController<List<TripDay>>();
    addTearDown(days.close);
    await _pumpTimeline(tester, daysStream: days.stream);

    days.add(_longDays('before'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('景點 before-29'),
      find.byKey(const ValueKey('trip-timeline-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final daySection = find.byKey(const ValueKey('day-drop-1'));
    final before = tester.getTopLeft(daySection).dy;
    expect(before, lessThan(0));

    days.add(_longDays('after'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(daySection).dy, before);
  });

  testWidgets('cross-day drag auto-scroll restores original offset on cancel', (
    tester,
  ) async {
    await _pumpTimeline(tester, fetchDays: () => _longDays('drag'));
    await _enableTimelineEditing(tester);

    final daySection = find.byKey(const ValueKey('day-drop-1'));
    final before = tester.getTopLeft(daySection).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('景點 drag-0')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 90));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getTopLeft(daySection).dy, lessThan(before));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(daySection).dy, before);
  });

  testWidgets(
    'cross-Day drag lifts the full card and marks only the insertion point',
    (tester) async {
      tester.view.physicalSize =
          const Size(800, 1200) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpTimeline(tester);
      await _enableTimelineEditing(tester);

      final drag = find.byKey(const ValueKey('entry-cross-drag-11'));
      final gesture = await tester.startGesture(tester.getCenter(drag));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey('entry-drag-feedback-11')),
        findsOneWidget,
      );
      expect(find.text('美麗海水族館'), findsWidgets);

      final target = find.byKey(const ValueKey('entry-drop-21'));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey('entry-drop-indicator-21')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('day-drop-outline-2')), findsNothing);

      await gesture.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('loading 顯示 skeleton 條列', (tester) async {
    final neverCompletes = Completer<List<TripDay>>();
    await _pumpTimeline(tester, fetchDays: () => neverCompletes.future);

    expect(find.byKey(const ValueKey('timeline-skeleton')), findsOneWidget);
  });

  testWidgets('error 顯示重試按鈕，點擊後重新載入', (tester) async {
    var fetchDaysAttempts = 0;
    await _pumpTimeline(
      tester,
      fetchDays: () {
        fetchDaysAttempts++;
        if (fetchDaysAttempts == 1) {
          throw Exception('network down');
        }
        return _fakeDays;
      },
    );

    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('2026-04-23（四）'), findsOneWidget);
    expect(fetchDaysAttempts, 2);
  });

  testWidgets('點 entry tile 開啟編輯 sheet（不顯示 legacy 標題欄）', (tester) async {
    await _pumpTimeline(tester);
    await tester.tap(find.text('美麗海水族館'));
    await tester.pumpAndSettle();
    expect(find.text('編輯停留點'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-edit-title')), findsNothing);
  });

  testWidgets('左滑 entry → 確認 → 刪除後重算交通', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.deleteEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);
    await _enableTimelineEditing(tester);

    await tester.drag(
      find.byKey(const ValueKey('entry-dismiss-11')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    verify(() => repo.deleteEntry(tripId: _tripId, entryId: 11)).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
  });

  testWidgets('點「新增停留點」開啟 Google Maps／收藏／自訂共用流程', (tester) async {
    await _pumpTimeline(tester);
    final addBtn = find.byKey(const ValueKey('add-entry-1'));
    await tester.ensureVisible(addBtn);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();
    expect(find.text('entry-add-search-1'), findsOneWidget);
  });

  group('computeReorderUpdates', () {
    test('移到末位（onReorderItem 已調整索引）+ 重編連續 sort_order', () {
      final updates = computeReorderUpdates([11, 12, 13], 0, 2);
      expect(updates.map((u) => u.id).toList(), [12, 13, 11]);
      expect(updates.map((u) => u.sortOrder).toList(), [0, 1, 2]);
      expect(updates.every((u) => u.dayId == null), isTrue);
    });
    test('末位移到首位', () {
      final updates = computeReorderUpdates([11, 12, 13], 2, 0);
      expect(updates.map((u) => u.id).toList(), [13, 11, 12]);
    });
  });

  group('computeCrossDayMoveUpdates', () {
    test('drop 在目標 entry 上 → 插該位並重排後段', () {
      final updates = computeCrossDayMoveUpdates(
        activeEntryId: 99,
        targetDayId: 7,
        targetEntryIds: [10, 20, 30],
        overEntryId: 20,
      );
      expect(updates, [
        (id: 99, sortOrder: 1, dayId: 7),
        (id: 20, sortOrder: 2, dayId: null),
        (id: 30, sortOrder: 3, dayId: null),
      ]);
    });

    test('drop 在 day 空白處 → 插末尾', () {
      final updates = computeCrossDayMoveUpdates(
        activeEntryId: 99,
        targetDayId: 7,
        targetEntryIds: [10, 20],
      );
      expect(updates, [(id: 99, sortOrder: 2, dayId: 7)]);
    });

    test('target 列表意外含 active → 先排除再算', () {
      final updates = computeCrossDayMoveUpdates(
        activeEntryId: 99,
        targetDayId: 7,
        targetEntryIds: [10, 99, 20],
        overEntryId: 20,
      );
      expect(updates, [
        (id: 99, sortOrder: 1, dayId: 7),
        (id: 20, sortOrder: 2, dayId: null),
      ]);
    });
  });

  testWidgets('每個 entry 有拖曳 handle', (tester) async {
    await _pumpTimeline(tester);
    await _enableTimelineEditing(tester);
    expect(find.byKey(const ValueKey('entry-drag-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-drag-12')), findsOneWidget);
  });

  testWidgets('同日排序的樂觀畫面與 onReorderItem API 順序一致', (tester) async {
    final repo = _MockTripRepository();
    final pendingReorder = Completer<void>();
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) => pendingReorder.future);
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);
    await _enableTimelineEditing(tester);

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView).first)
        .onReorderItem!(0, 2);
    await tester.pump();

    final item12Top = tester.getTopLeft(find.text('海人食堂')).dy;
    final item13Top = tester.getTopLeft(find.text('美國村購物')).dy;
    final item11Top = tester.getTopLeft(find.text('美麗海水族館')).dy;
    expect(item12Top, lessThan(item13Top));
    expect(item13Top, lessThan(item11Top));

    pendingReorder.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('點搬移鈕 → 選其他天 → reorderEntries 帶 day_id', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);
    await _enableTimelineEditing(tester);

    await tester.tap(find.byKey(const ValueKey('entry-move-to-day-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-day-2')));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => repo.reorderEntries(
                tripId: _tripId,
                updates: captureAny(named: 'updates'),
              ),
            ).captured.single
            as List<({int id, int sortOrder, int? dayId})>;
    expect(captured.single.id, 11);
    expect(captured.single.dayId, 2);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '2')).called(1);
  });

  testWidgets('跨日搬移先更新畫面，儲存失敗後回復原 Day', (tester) async {
    final repo = _MockTripRepository();
    final pendingMove = Completer<void>();
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) => pendingMove.future);
    await _pumpTimeline(tester, repo: repo);
    await _enableTimelineEditing(tester);

    await tester.tap(find.byKey(const ValueKey('entry-move-to-day-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-day-2')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('day-drop-1')),
        matching: find.text('美麗海水族館'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('day-drop-2')),
        matching: find.text('美麗海水族館'),
      ),
      findsOneWidget,
    );

    pendingMove.completeError(Exception('save failed'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('day-drop-2')),
        matching: find.text('美麗海水族館'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('day-pill-1')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('day-drop-1')),
        matching: find.text('美麗海水族館'),
      ),
      findsOneWidget,
    );
    expect(find.text('搬移失敗，請稍後再試'), findsOneWidget);
  });

  testWidgets('拖曳 entry 到其他天 → reorderEntries 帶 day_id 並重算兩天', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);
    await _enableTimelineEditing(tester);

    final source = tester.getCenter(
      find.byKey(const ValueKey('entry-cross-drag-11')),
    );
    final gesture = await tester.startGesture(source);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(source.dx, 590));
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(Offset(0, i.isEven ? -1 : 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 點在 DAY 2 的天氣示意空白區，避免誤落到內層 entry DragTarget。
    final target = tester.getCenter(
      find.byKey(const ValueKey('day-weather-preview-2')),
    );
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => repo.reorderEntries(
                tripId: _tripId,
                updates: captureAny(named: 'updates'),
              ),
            ).captured.single
            as List<({int id, int sortOrder, int? dayId})>;
    expect(captured.single, (id: 11, sortOrder: 2, dayId: 2));
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '2')).called(1);
  });

  testWidgets('拖曳 entry 到其他天的 entry 上 → 插入該位並重排目標日', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);
    await _enableTimelineEditing(tester);

    final source = tester.getCenter(
      find.byKey(const ValueKey('entry-cross-drag-11')),
    );
    final gesture = await tester.startGesture(source);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(source.dx, 590));
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(Offset(0, i.isEven ? -1 : 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final target = tester.getCenter(
      find.byKey(const ValueKey('entry-drop-21')),
    );
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => repo.reorderEntries(
                tripId: _tripId,
                updates: captureAny(named: 'updates'),
              ),
            ).captured.single
            as List<({int id, int sortOrder, int? dayId})>;
    expect(captured, [
      (id: 11, sortOrder: 0, dayId: 2),
      (id: 21, sortOrder: 1, dayId: null),
      (id: 22, sortOrder: 2, dayId: null),
    ]);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '2')).called(1);
  });

  testWidgets('entry 早於營業時間 → 不顯示「注意事項」卡', (tester) async {
    await _pumpTimeline(
      tester,
      fetchDays: () => const [
        TripDay(
          id: 1,
          dayNum: 1,
          title: '早起測試',
          version: 1,
          timeline: [
            TimelineEntry(
              id: 11,
              sortOrder: 0,
              startTime: '08:00',
              title: '美麗海水族館',
              version: 1,
              master: EntryPoiInfo(
                poiId: 101,
                name: '沖繩美麗海水族館',
                type: 'attraction',
                hours: '09:00-18:00',
              ),
            ),
          ],
        ),
      ],
    );

    expect(find.text('注意事項'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('無早於營業時間問題 → 不顯示「注意事項」卡', (tester) async {
    await _pumpTimeline(tester);
    expect(find.text('注意事項'), findsNothing);
  });

  testWidgets('點 travel pill → 大眾運輸填分鐘 → updateSegment', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        clearSubmode: any(named: 'clearSubmode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer(
      (_) async => const TripSegment(id: 50, mode: 'transit', version: 2),
    );
    await _pumpTimeline(
      tester,
      repo: repo,
      segments: const [
        TripSegment(
          id: 50,
          fromEntryId: 11,
          toEntryId: 12,
          mode: 'driving',
          version: 1,
        ),
      ],
    );
    // segments 改 StreamProvider 後，day section 內的 tripSegmentsProvider 訂閱在
    // days 渲染後才建立，需再 settle 一輪讓 stream 值傳達、travel pill 才會出現。
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('travel-edit-50')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-mode-transit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('travel-min')), '25');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('travel-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateSegment(
        tripId: _tripId,
        segmentId: 50,
        mode: 'transit',
        submode: '大眾運輸',
        clearSubmode: false,
        min: 25,
        noTravel: false,
        expectedVersion: 1,
      ),
    ).called(1);
  });

  testWidgets('火車類方式分鐘留白仍會儲存並交由後端自動估算', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        clearSubmode: any(named: 'clearSubmode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer(
      (_) async => const TripSegment(
        id: 50,
        mode: 'transit',
        submode: 'train',
        version: 2,
      ),
    );
    await _pumpTimeline(
      tester,
      repo: repo,
      segments: const [
        TripSegment(
          id: 50,
          fromEntryId: 11,
          toEntryId: 12,
          mode: 'driving',
          version: 1,
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('travel-edit-50')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-mode-train')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('travel-submit')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('travel-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateSegment(
        tripId: _tripId,
        segmentId: 50,
        mode: 'transit',
        submode: 'train',
        clearSubmode: false,
        min: null,
        noTravel: false,
        expectedVersion: 1,
      ),
    ).called(1);
  });

  testWidgets('單軌 travel segment 直接儲存 → 保留 submode 且不送 min 覆寫自動計算', (
    tester,
  ) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        clearSubmode: any(named: 'clearSubmode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer(
      (_) async => const TripSegment(
        id: 50,
        mode: 'transit',
        submode: 'monorail',
        version: 2,
      ),
    );
    await _pumpTimeline(
      tester,
      repo: repo,
      segments: const [
        TripSegment(
          id: 50,
          fromEntryId: 11,
          toEntryId: 12,
          mode: 'transit',
          submode: 'monorail',
          min: 18,
          source: 'haversine',
          version: 1,
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('travel-edit-50')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateSegment(
        tripId: _tripId,
        segmentId: 50,
        mode: 'transit',
        submode: 'monorail',
        clearSubmode: false,
        min: null,
        noTravel: false,
        expectedVersion: 1,
      ),
    ).called(1);
  });

  testWidgets('切換交通方式會清除舊的手動分鐘，避免鎖到新方式', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        clearSubmode: any(named: 'clearSubmode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer(
      (_) async => const TripSegment(
        id: 50,
        mode: 'transit',
        submode: 'train',
        version: 2,
      ),
    );
    await _pumpTimeline(
      tester,
      repo: repo,
      segments: const [
        TripSegment(
          id: 50,
          fromEntryId: 11,
          toEntryId: 12,
          mode: 'driving',
          min: 30,
          source: 'manual',
          version: 1,
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('travel-edit-50')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('travel-min')))
          .controller!
          .text,
      '30',
    );
    await tester.tap(find.byKey(const ValueKey('travel-mode-train')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('travel-min')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('travel-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateSegment(
        tripId: _tripId,
        segmentId: 50,
        mode: 'transit',
        submode: 'train',
        clearSubmode: false,
        min: null,
        noTravel: false,
        expectedVersion: 1,
      ),
    ).called(1);
  });

  testWidgets('沒有 segment row 時仍可點 travel pill 建立交通設定', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.createSegment(
        tripId: any(named: 'tripId'),
        fromEntryId: any(named: 'fromEntryId'),
        toEntryId: any(named: 'toEntryId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
      ),
    ).thenAnswer(
      (_) async => const TripSegment(
        id: 51,
        fromEntryId: 11,
        toEntryId: 12,
        mode: 'transit',
        submode: '大眾運輸',
        min: 25,
        noTravel: false,
        version: 1,
      ),
    );
    await _pumpTimeline(tester, repo: repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('travel-create-11-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-mode-transit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('travel-min')), '25');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('travel-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.createSegment(
        tripId: _tripId,
        fromEntryId: 11,
        toEntryId: 12,
        mode: 'transit',
        submode: '大眾運輸',
        min: 25,
        noTravel: false,
      ),
    ).called(1);
    verifyNever(
      () => repo.updateSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        clearSubmode: any(named: 'clearSubmode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    );
  });

  testWidgets('完全缺少 segment/travel 時可直接建立「不需計算路程」', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.createSegment(
        tripId: any(named: 'tripId'),
        fromEntryId: any(named: 'fromEntryId'),
        toEntryId: any(named: 'toEntryId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
      ),
    ).thenAnswer(
      (_) async => const TripSegment(
        id: 52,
        fromEntryId: 1,
        toEntryId: 2,
        mode: 'driving',
        noTravel: true,
        version: 1,
      ),
    );
    await _pumpTimeline(
      tester,
      repo: repo,
      fetchDays: () => const [
        TripDay(
          id: 1,
          dayNum: 1,
          version: 1,
          timeline: [
            TimelineEntry(id: 1, sortOrder: 0, title: 'A', version: 1),
            TimelineEntry(id: 2, sortOrder: 1, title: 'B', version: 1),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('travel-create-1-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-mode-no-travel')));
    await tester.tap(find.byKey(const ValueKey('travel-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.createSegment(
        tripId: _tripId,
        fromEntryId: 1,
        toEntryId: 2,
        mode: null,
        submode: null,
        min: null,
        noTravel: true,
      ),
    ).called(1);
  });
}
