import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/trip_timeline_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

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
        master: EntryPoiInfo(poiId: 103, name: '美國村', type: 'shopping', category: '購物'),
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
        master: EntryPoiInfo(poiId: 202, name: '首里城', type: 'attraction', rating: 4.4),
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
  _MockTripRepository? repo,
  List<TripSegment> segments = const [],
}) async {
  final router = GoRouter(
    initialLocation: '/trips/$_tripId',
    routes: [
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) =>
            TripTimelineScreen(tripId: state.pathParameters['tripId']!),
        routes: [
          GoRoute(
            path: 'map',
            builder: (context, state) => const Scaffold(body: Text('map-page')),
          ),
          GoRoute(
            path: 'notes',
            builder: (context, state) => const Scaffold(body: Text('notes-page')),
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
        tripDetailProvider(_tripId)
            .overrideWith((ref) => (fetchTrip ?? () => _fakeTrip)()),
        tripDaysProvider(_tripId)
            .overrideWith((ref) => (fetchDays ?? () => _fakeDays)()),
        tripSegmentsProvider(_tripId).overrideWith((ref) async => segments),
        if (repo != null) tripRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pump();
}

Color _entryDotColor(WidgetTester tester, int entryId) {
  final dotContainer =
      tester.widget<Container>(find.byKey(ValueKey('entry-dot-$entryId')));
  return (dotContainer.decoration! as BoxDecoration).color!;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<({int id, int sortOrder, int? dayId})>[]);
  });

  testWidgets('AppBar 顯示行程標題與地圖/筆記 actions', (tester) async {
    await _pumpTimeline(tester);

    expect(find.text('沖繩自駕五日'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
  });

  testWidgets('點地圖 icon 以 go_router 導向行程地圖頁', (tester) async {
    await _pumpTimeline(tester);

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('map-page'), findsOneWidget);
  });

  testWidgets('渲染 2 天 day headers（eyebrow + displayTitle）與 day pills', (tester) async {
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

  testWidgets('hotel 卡以 sage tone 渲染（subtle 底 + bed icon）', (tester) async {
    await _pumpTimeline(tester);

    expect(find.text('美國村海濱飯店'), findsOneWidget);
    expect(find.byIcon(Icons.bed_outlined), findsOneWidget);

    final hotelCardContainer =
        tester.widget<Container>(find.byKey(const ValueKey('hotel-card-9')));
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

  testWidgets('loading 顯示 skeleton 條列', (tester) async {
    final neverCompletes = Completer<List<TripDay>>();
    await _pumpTimeline(tester, fetchDays: () => neverCompletes.future);

    expect(find.byKey(const ValueKey('timeline-skeleton')), findsOneWidget);
  });

  testWidgets('error 顯示重試按鈕，點擊後重新載入', (tester) async {
    var fetchDaysAttempts = 0;
    await _pumpTimeline(tester, fetchDays: () {
      fetchDaysAttempts++;
      if (fetchDaysAttempts == 1) {
        throw Exception('network down');
      }
      return _fakeDays;
    });

    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('北部海岸線'), findsOneWidget);
    expect(fetchDaysAttempts, 2);
  });

  testWidgets('點 entry tile 開啟編輯 sheet（預填標題）', (tester) async {
    await _pumpTimeline(tester);
    await tester.tap(find.text('美麗海水族館'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-edit-title')), findsOneWidget);
    expect(find.widgetWithText(TextField, '美麗海水族館'), findsOneWidget);
  });

  testWidgets('左滑 entry → 確認 → 呼叫 deleteEntry', (tester) async {
    final repo = _MockTripRepository();
    when(() => repo.deleteEntry(
          tripId: any(named: 'tripId'),
          entryId: any(named: 'entryId'),
        )).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);

    await tester.drag(
        find.byKey(const ValueKey('entry-dismiss-11')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    verify(() => repo.deleteEntry(tripId: _tripId, entryId: 11)).called(1);
  });

  testWidgets('點「新增停留點」開啟新增 sheet', (tester) async {
    await _pumpTimeline(tester);
    final addBtn = find.byKey(const ValueKey('add-entry-1'));
    await tester.ensureVisible(addBtn);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-edit-title')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新增'), findsOneWidget);
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

  testWidgets('每個 entry 有拖曳 handle', (tester) async {
    await _pumpTimeline(tester);
    expect(find.byKey(const ValueKey('entry-drag-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-drag-12')), findsOneWidget);
  });

  testWidgets('點搬移鈕 → 選其他天 → reorderEntries 帶 day_id', (tester) async {
    final repo = _MockTripRepository();
    when(() => repo.reorderEntries(
          tripId: any(named: 'tripId'),
          updates: any(named: 'updates'),
        )).thenAnswer((_) async {});
    when(() => repo.recomputeTravel(
          tripId: any(named: 'tripId'),
          day: any(named: 'day'),
        )).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('entry-menu-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-day-2')));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.reorderEntries(
            tripId: _tripId, updates: captureAny(named: 'updates')))
        .captured
        .single as List<({int id, int sortOrder, int? dayId})>;
    expect(captured.single.id, 11);
    expect(captured.single.dayId, 2);
  });

  testWidgets('點 travel pill → 大眾運輸填分鐘 → updateSegment', (tester) async {
    final repo = _MockTripRepository();
    when(() => repo.updateSegment(
          tripId: any(named: 'tripId'),
          segmentId: any(named: 'segmentId'),
          mode: any(named: 'mode'),
          min: any(named: 'min'),
          expectedVersion: any(named: 'expectedVersion'),
        )).thenAnswer(
        (_) async => const TripSegment(id: 50, mode: 'transit', version: 2));
    await _pumpTimeline(tester, repo: repo, segments: const [
      TripSegment(
          id: 50, fromEntryId: 11, toEntryId: 12, mode: 'driving', version: 1),
    ]);

    await tester.tap(find.byKey(const ValueKey('travel-edit-50')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('travel-mode-transit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('travel-min')), '25');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('travel-submit')));
    await tester.pumpAndSettle();

    verify(() => repo.updateSegment(
        tripId: _tripId,
        segmentId: 50,
        mode: 'transit',
        min: 25,
        expectedVersion: 1)).called(1);
  });
}
