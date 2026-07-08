import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/trip_timeline_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

const _tripId = 'okinawa-2026';

const _fakeTrip = Trip(id: _tripId, name: '沖繩自駕 2026', title: '沖繩自駕五日');

class _MockTripRepository extends Mock implements TripRepository {}

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
        travel: Travel(type: 'car', min: 15),
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
        travel: Travel(type: 'walk', min: 10),
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
        travel: Travel(type: 'car', min: 8),
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
        master: EntryPoiInfo(poiId: 201, name: '沖繩都市單軌電車', type: 'transport'),
      ),
      TimelineEntry(
        id: 22,
        sortOrder: 1,
        startTime: '11:00',
        title: '首里城公園',
        version: 1,
        travel: Travel(type: 'monorail', min: 20),
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

/// 以 create callback 注入假資料（flutter_riverpod 3.x 未匯出 Override 型別，
/// 故在此 helper 內 inline 組 overrides，型別交由推斷）。
Future<void> _pumpTimeline(
  WidgetTester tester, {
  String initialLocation = '/trips/$_tripId',
  DateTime? today,
  FutureOr<Trip> Function()? fetchTrip,
  FutureOr<List<TripDay>> Function()? fetchDays,
  FutureOr<List<TripSegment>> Function()? fetchSegments,
  TripRepository? repository,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => TripTimelineScreen(
          tripId: state.pathParameters['tripId']!,
          focusEntryId: int.tryParse(state.uri.queryParameters['focus'] ?? ''),
          today: today,
        ),
        routes: [
          GoRoute(
            path: 'map',
            builder: (context, state) => const Scaffold(body: Text('map-page')),
          ),
          GoRoute(
            path: 'notes',
            builder: (context, state) =>
                const Scaffold(body: Text('notes-page')),
          ),
          GoRoute(
            path: 'health',
            builder: (context, state) =>
                const Scaffold(body: Text('health-page')),
          ),
          GoRoute(
            path: 'collab',
            builder: (context, state) =>
                const Scaffold(body: Text('collab-page')),
          ),
          GoRoute(
            path: 'add-entry',
            builder: (context, state) =>
                const Scaffold(body: Text('add-entry-page')),
          ),
          GoRoute(
            path: 'stop/:entryId/edit',
            builder: (context, state) =>
                Scaffold(body: Text('edit:${state.pathParameters['entryId']}')),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      // 關閉 riverpod 3 預設自動 retry：error 測試需要 provider 停在 AsyncError
      retry: (retryCount, error) => null,
      overrides: [
        if (repository != null)
          tripRepositoryProvider.overrideWithValue(repository),
        tripDetailProvider(
          _tripId,
        ).overrideWith((ref) => (fetchTrip ?? () => _fakeTrip)()),
        tripDaysProvider(
          _tripId,
        ).overrideWith((ref) => (fetchDays ?? () => _fakeDays)()),
        tripSegmentsProvider(_tripId).overrideWith(
          (ref) => (fetchSegments ?? () => const <TripSegment>[])(),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pump();
}

Color _entryDotColor(WidgetTester tester, int entryId) {
  final dotContainer = tester.widget<Container>(
    find.byKey(ValueKey('entry-dot-$entryId')),
  );
  return (dotContainer.decoration! as BoxDecoration).color!;
}

Color _dayPillColor(WidgetTester tester, int dayNum) {
  final dayPill = tester.widget<Container>(
    find.byKey(ValueKey('day-pill-$dayNum')),
  );
  return (dayPill.decoration! as BoxDecoration).color!;
}

void main() {
  const editableSegment = TripSegment(
    id: 9001,
    tripId: _tripId,
    fromEntryId: 11,
    toEntryId: 12,
    mode: 'driving',
    min: 18,
    distanceM: 7400,
    source: 'google',
    computedAt: 1783500000000,
    updatedAt: 1783500010000,
    version: 4,
  );

  testWidgets('AppBar 顯示行程標題與地圖/筆記 actions', (tester) async {
    await _pumpTimeline(tester);

    expect(find.text('沖繩自駕五日'), findsOneWidget);
    expect(find.byIcon(Icons.add_location_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
  });

  testWidgets('AppBar overflow menu 提供 AI 健檢與共編設定', (tester) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byKey(const ValueKey('timeline-overflow-actions')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timeline-overflow-health')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timeline-overflow-collab')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('timeline-overflow-health')));
    await tester.pumpAndSettle();

    expect(find.text('health-page'), findsOneWidget);
  });

  testWidgets('點新增景點 icon 以 go_router 導向 add-entry 頁', (tester) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('add-entry-page'), findsOneWidget);
  });

  testWidgets('點地圖 icon 以 go_router 導向行程地圖頁', (tester) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('map-page'), findsOneWidget);
  });

  testWidgets('點 entry 編輯 icon 導向 stop/:entryId/edit', (tester) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byTooltip('編輯景點').first);
    await tester.pumpAndSettle();

    expect(find.text('edit:11'), findsOneWidget);
  });

  testWidgets('渲染 2 天 day headers（eyebrow + displayTitle）與 day pills', (
    tester,
  ) async {
    await _pumpTimeline(tester);

    // 'DAY 01' 同時出現在頂部 pill 與 day header eyebrow
    expect(find.text('DAY 01'), findsNWidgets(2));
    expect(find.text('DAY 02'), findsNWidgets(2));
    expect(find.text('北部海岸線'), findsOneWidget);
    expect(find.text('南部文化'), findsOneWidget);
  });

  testWidgets('entry tile 依 master.type 顯示對應 tone 圓點', (tester) async {
    await _pumpTimeline(tester);

    // attraction → accent、restaurant → pink、transport → sage
    expect(_entryDotColor(tester, 11), TpColorsLight.accentDeep);
    expect(_entryDotColor(tester, 12), TpColorsLight.pinkDeep);
    expect(_entryDotColor(tester, 21), TpColorsLight.sageDeep);
  });

  testWidgets('travel pill 顯示移動分鐘數與 type icon', (tester) async {
    await _pumpTimeline(tester);

    expect(find.text('15 分鐘'), findsOneWidget);
    expect(find.text('10 分鐘'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car), findsNWidgets(2));
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);
  });

  testWidgets('segments provider 覆蓋 legacy travel，點 pill 開啟移動方式編輯', (
    tester,
  ) async {
    await _pumpTimeline(tester, fetchSegments: () => const [editableSegment]);

    expect(find.text('18 分鐘'), findsOneWidget);
    expect(find.text('15 分鐘'), findsNothing);

    await tester.tap(find.text('18 分鐘'));
    await tester.pumpAndSettle();

    expect(find.text('調整移動方式'), findsOneWidget);
    expect(find.text('美麗海水族館 到 海人食堂'), findsOneWidget);
    expect(find.text('開車'), findsOneWidget);
    expect(find.text('步行'), findsOneWidget);
    expect(find.text('大眾運輸'), findsOneWidget);
  });

  testWidgets('切換 walking 時 PATCH segment 並帶 expectedVersion', (tester) async {
    final repository = _MockTripRepository();
    when(
      () => repository.updateTripSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        min: any(named: 'min'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer(
      (_) async => const TripSegment(
        id: 9001,
        tripId: _tripId,
        fromEntryId: 11,
        toEntryId: 12,
        mode: 'walking',
        min: 12,
        distanceM: 900,
        source: 'google',
        computedAt: 1783500020000,
        updatedAt: 1783500020000,
        version: 5,
      ),
    );

    await _pumpTimeline(
      tester,
      fetchSegments: () => const [editableSegment],
      repository: repository,
    );

    await tester.tap(find.text('18 分鐘'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('步行'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-segment-save')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateTripSegment(
        tripId: _tripId,
        segmentId: 9001,
        mode: 'walking',
        min: null,
        expectedVersion: 4,
      ),
    ).called(1);
  });

  testWidgets('transit 分鐘需介於 1 到 1440，無效時不送 PATCH', (tester) async {
    final repository = _MockTripRepository();

    await _pumpTimeline(
      tester,
      fetchSegments: () => const [editableSegment],
      repository: repository,
    );

    await tester.tap(find.text('18 分鐘'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('大眾運輸'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('travel-segment-min')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey('travel-segment-save')));
    await tester.pumpAndSettle();

    expect(find.text('大眾運輸時間需介於 1 到 1440 分鐘'), findsOneWidget);
    verifyNever(
      () => repository.updateTripSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        min: any(named: 'min'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    );
  });

  testWidgets('segment PATCH 遇到 STALE_ENTRY 時抓最新 version 後 retry', (
    tester,
  ) async {
    final repository = _MockTripRepository();
    const refreshedSegment = TripSegment(
      id: 9001,
      tripId: _tripId,
      fromEntryId: 11,
      toEntryId: 12,
      mode: 'driving',
      min: 19,
      distanceM: 7600,
      source: 'google',
      computedAt: 1783500020000,
      updatedAt: 1783500020000,
      version: 6,
    );
    when(
      () => repository.updateTripSegment(
        tripId: _tripId,
        segmentId: 9001,
        mode: 'walking',
        min: null,
        expectedVersion: 4,
      ),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'STALE_ENTRY',
        message: 'expected version 4, current 6',
      ),
    );
    when(
      () => repository.fetchTripSegments(_tripId),
    ).thenAnswer((_) async => const [refreshedSegment]);
    when(
      () => repository.updateTripSegment(
        tripId: _tripId,
        segmentId: 9001,
        mode: 'walking',
        min: null,
        expectedVersion: 6,
      ),
    ).thenAnswer(
      (_) async => const TripSegment(
        id: 9001,
        tripId: _tripId,
        fromEntryId: 11,
        toEntryId: 12,
        mode: 'walking',
        min: 12,
        distanceM: 900,
        source: 'google',
        computedAt: 1783500030000,
        updatedAt: 1783500030000,
        version: 7,
      ),
    );

    await _pumpTimeline(
      tester,
      fetchSegments: () => const [editableSegment],
      repository: repository,
    );

    await tester.tap(find.text('18 分鐘'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('步行'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-segment-save')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateTripSegment(
        tripId: _tripId,
        segmentId: 9001,
        mode: 'walking',
        min: null,
        expectedVersion: 4,
      ),
    ).called(1);
    verify(() => repository.fetchTripSegments(_tripId)).called(1);
    verify(
      () => repository.updateTripSegment(
        tripId: _tripId,
        segmentId: 9001,
        mode: 'walking',
        min: null,
        expectedVersion: 6,
      ),
    ).called(1);
  });

  testWidgets('hotel 卡以 sage tone 渲染（subtle 底 + bed icon）', (tester) async {
    await _pumpTimeline(tester);

    expect(find.text('美國村海濱飯店'), findsOneWidget);
    expect(find.byIcon(Icons.bed_outlined), findsOneWidget);

    final hotelCardContainer = tester.widget<Container>(
      find.byKey(const ValueKey('hotel-card-9')),
    );
    final hotelCardDecoration = hotelCardContainer.decoration! as BoxDecoration;
    expect(hotelCardDecoration.color, TpColorsLight.sageSubtle);
  });

  testWidgets('點 day pill 捲動至該日 section', (tester) async {
    await _pumpTimeline(tester);

    final day2TitleTopBeforeTap = tester.getTopLeft(find.text('南部文化')).dy;

    // 第一個 'DAY 02' 是頂部 pill（pill 列在捲動內容之前）
    await tester.tap(find.text('DAY 02').first);
    await tester.pumpAndSettle();

    final day2TitleTopAfterTap = tester.getTopLeft(find.text('南部文化')).dy;
    expect(day2TitleTopAfterTap, lessThan(day2TitleTopBeforeTap));
  });

  testWidgets('手動捲動到 day section 時同步 active day pill', (tester) async {
    await _pumpTimeline(tester);

    expect(_dayPillColor(tester, 1), TpColorsLight.accentSubtle);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -560),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('南部文化')).dy, lessThan(360));
    expect(_dayPillColor(tester, 2), TpColorsLight.accentSubtle);
  });

  testWidgets('focus query 初載捲到指定 entry 並同步 active day', (tester) async {
    await _pumpTimeline(tester, initialLocation: '/trips/$_tripId?focus=22');
    await tester.pumpAndSettle();

    final focusedEntryTop = tester.getTopLeft(find.text('首里城公園')).dy;
    expect(focusedEntryTop, lessThan(500));

    expect(_dayPillColor(tester, 2), TpColorsLight.accentSubtle);
  });

  testWidgets('今日日期初載自動定位到相同日期 day', (tester) async {
    await _pumpTimeline(tester, today: DateTime(2026, 4, 24));
    await tester.pumpAndSettle();

    final todaySectionTop = tester.getTopLeft(find.text('南部文化')).dy;
    expect(todaySectionTop, lessThan(360));
    expect(_dayPillColor(tester, 2), TpColorsLight.accentSubtle);
  });

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

    expect(find.text('北部海岸線'), findsOneWidget);
    expect(fetchDaysAttempts, 2);
  });
}
