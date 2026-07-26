import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/day_weather.dart';
import 'package:tripline/features/trip_detail/selected_day_provider.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/trip_timeline_screen.dart';
import 'package:tripline/features/trip_detail/widgets/travel_pill.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/swipe_to_delete.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';

import '../../helpers/branch_keepalive.dart';

const _tripId = 'okinawa-2026';

class _MockTripRepository extends Mock implements TripRepository {}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(TripTimelineScreen)),
      listen: false,
    );

int? _sharedDayNum(WidgetTester tester, [String tripId = _tripId]) =>
    _containerOf(tester).read(selectedDayProvider).dayNumFor(tripId);

int _selectorDayNum(WidgetTester tester) => tester
    .widget<TpHorizontalSelector<int>>(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    )
    .value;

class _TripSwitchHarness extends StatelessWidget {
  const _TripSwitchHarness(this.tripId);

  final ValueListenable<String> tripId;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: tripId,
    builder: (context, value, child) => TripTimelineScreen(tripId: value),
  );
}

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
        description: '黑潮之海旁集合',
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
  List<TripSummary>? trips,
  SelectedTripDay? initialSelectedDay,
  ValueListenable<bool>? branchActive,
}) async {
  final router = GoRouter(
    initialLocation: '/trips/$tripId',
    routes: [
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => MaybeBranch(
          active: branchActive,
          child: TripTimelineScreen(
            tripId: state.pathParameters['tripId']!,
            initialEntryId: initialEntryId,
            initialDayNum: initialDayNum,
          ),
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
          for (final action in ['edit', 'pois', 'move', 'copy'])
            GoRoute(
              path: 'entries/:entryId/$action',
              builder: (context, state) => Scaffold(
                body: Text('entry-$action-${state.pathParameters['entryId']}'),
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
        if (trips != null)
          myTripsProvider.overrideWith((ref) => Stream.value(trips)),
        if (repo != null) tripRepositoryProvider.overrideWithValue(repo),
        if (dayWeatherFetcher != null)
          dayWeatherFetcherProvider.overrideWithValue(dayWeatherFetcher),
        if (initialSelectedDay != null)
          selectedDayProvider.overrideWith(
            () => SeededSelectedDayController(initialSelectedDay),
          ),
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

List<TripDay> _selectorDays() => [
  for (var day = 1; day <= 8; day++)
    TripDay(
      id: day,
      dayNum: day,
      date: '2026-08-${day.toString().padLeft(2, '0')}',
      version: 1,
    ),
];

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

  testWidgets('Root Glass Header 顯示行程選擇、功能選單與 Account 入口', (tester) async {
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
    // 與 root tab「地圖」重複的 bar button 已移除，改由 tab 承擔。
    expect(find.byKey(const ValueKey('trip-timeline-map')), findsNothing);
    expect(find.byIcon(CupertinoIcons.map), findsNothing);
    expect(
      find.byKey(const ValueKey('trip-timeline-day-overview')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('trip-secondary-map')), findsNothing);
    expect(find.byKey(const ValueKey('trip-secondary-notes')), findsNothing);
    expect(find.byIcon(CupertinoIcons.printer), findsNothing);
    expect(find.byIcon(Icons.history_outlined), findsNothing);
    final headerRect = tester.getRect(
      find.byKey(const ValueKey('tp-root-glass-header')),
    );
    final selectorRect = tester.getRect(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    );
    expect(selectorRect.top - headerRect.bottom, closeTo(TpSpacing.s2, 1));

    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-edit-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-action-notes')), findsOneWidget);
  });

  testWidgets('前景分支：目前 DAY 寫入共用選取日', (tester) async {
    await _pumpTimeline(tester);
    await tester.pumpAndSettle();

    expect(_sharedDayNum(tester), 1);

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    expect(_sharedDayNum(tester), 2);
  });

  testWidgets('背景分支處理到 days 重新 emit 也不寫入共用選取日', (tester) async {
    // riverpod 3 會在 TickerMode 關閉時 pause 訂閱，背景分支多半根本收不到 emit；
    // 但「emit 落在切到背景的同一批」時，暫停前就已標記 dirty 的畫面仍會以背景身分
    // 重建一次，並在其中處理新的 days —— 這一格才是共用狀態真正會被污染的縫。
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    final days = StreamController<List<TripDay>>();
    addTearDown(days.close);
    await _pumpTimeline(tester, daysStream: days.stream, branchActive: active);
    days.add(_fakeDays);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();
    expect(_sharedDayNum(tester), 2);

    // SWR 第二段 emit 少掉 DAY 2，同一批切到背景：畫面內部會退回 DAY 1，
    // 但背景分支不得把這個退回寫進共用狀態。
    days.add([_fakeDays.first]);
    active.value = false;
    await tester.pumpAndSettle();

    expect(_sharedDayNum(tester), 2);
  });

  testWidgets('查詢參數缺席時採用共用選取日', (tester) async {
    await _pumpTimeline(
      tester,
      initialSelectedDay: const SelectedTripDay(tripId: _tripId, dayNum: 2),
    );
    await tester.pumpAndSettle();

    expect(_selectorDayNum(tester), 2);
  });

  testWidgets('深連結 day 優先於共用選取日', (tester) async {
    await _pumpTimeline(
      tester,
      initialDayNum: 1,
      initialSelectedDay: const SelectedTripDay(tripId: _tripId, dayNum: 2),
    );
    await tester.pumpAndSettle();

    expect(_selectorDayNum(tester), 1);
    expect(_sharedDayNum(tester), 1);
  });

  testWidgets('切換行程後不殘留前一個行程的共用選取日', (tester) async {
    await _pumpTimeline(
      tester,
      initialSelectedDay: const SelectedTripDay(
        tripId: 'tokyo-2026',
        dayNum: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(_selectorDayNum(tester), 1);
  });

  testWidgets('切回前景時接住其他 tab 變更的共用選取日', (tester) async {
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    await _pumpTimeline(tester, branchActive: active);
    await tester.pumpAndSettle();
    expect(_selectorDayNum(tester), 1);

    final container = _containerOf(tester);
    active.value = false;
    await tester.pumpAndSettle();
    container
        .read(selectedDayProvider.notifier)
        .select(tripId: _tripId, dayNum: 2);
    await tester.pumpAndSettle();
    expect(_selectorDayNum(tester), 1);

    active.value = true;
    await tester.pumpAndSettle();

    expect(_selectorDayNum(tester), 2);
  });

  testWidgets('切換 Trip 會重設 DAY 1，並拒絕舊行程的移動與複製 sheet', (tester) async {
    const otherTripId = 'tokyo-2026';
    final activeTripId = ValueNotifier(_tripId);
    final repo = _MockTripRepository();
    addTearDown(activeTripId.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          tripDetailProvider(
            _tripId,
          ).overrideWith((ref) => Stream.value(_fakeTrip)),
          tripDetailProvider(otherTripId).overrideWith(
            (ref) => Stream.value(
              const Trip(id: otherTripId, name: '東京', title: '東京五日'),
            ),
          ),
          tripDaysProvider(
            _tripId,
          ).overrideWith((ref) => Stream.value(_fakeDays)),
          tripDaysProvider(
            otherTripId,
          ).overrideWith((ref) => Stream.value(_fakeDays)),
          tripSegmentsProvider(
            _tripId,
          ).overrideWith((ref) => Stream.value(const <TripSegment>[])),
          tripSegmentsProvider(
            otherTripId,
          ).overrideWith((ref) => Stream.value(const <TripSegment>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: _TripSwitchHarness(activeTripId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-timeline-view-day-selector')),
          )
          .value,
      2,
    );
    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-edit-mode')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tp-root-header-primary-action')),
      findsOneWidget,
    );

    activeTripId.value = otherTripId;
    await tester.pumpAndSettle();
    expect(find.text('東京五日'), findsOneWidget);
    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-timeline-view-day-selector')),
          )
          .value,
      1,
    );
    expect(find.byKey(const ValueKey('trip-actions-menu')), findsOneWidget);

    activeTripId.value = _tripId;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-actions-menu')), findsOneWidget);
    final finishEditing = find.byKey(
      const ValueKey('tp-root-header-primary-action'),
    );
    if (finishEditing.evaluate().isNotEmpty) {
      await tester.tap(finishEditing);
      await tester.pumpAndSettle();
    }
    await tester.drag(
      find.byKey(const ValueKey('trip-timeline-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-move-11')));
    await tester.pumpAndSettle();
    activeTripId.value = otherTripId;
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-move-to-day-2')));
    await tester.pumpAndSettle();
    verifyNever(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    );

    activeTripId.value = _tripId;
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('trip-timeline-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-copy-11')));
    await tester.pumpAndSettle();
    activeTripId.value = otherTripId;
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-copy-to-day-2')));
    await tester.pumpAndSettle();
    verifyNever(
      () => repo.copyEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    );
  });

  testWidgets('排序請求中切換 Trip，交通重算仍只作用於原行程', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const otherTripId = 'tokyo-2026';
    final activeTripId = ValueNotifier(_tripId);
    final pendingReorder = Completer<void>();
    addTearDown(activeTripId.dispose);
    final repo = _MockTripRepository();
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          myTripsProvider.overrideWith(
            (ref) => Stream.value(const [
              TripSummary(tripId: _tripId, name: '沖繩'),
              TripSummary(tripId: otherTripId, name: '東京'),
            ]),
          ),
          tripDetailProvider(
            _tripId,
          ).overrideWith((ref) => Stream.value(_fakeTrip)),
          tripDetailProvider(otherTripId).overrideWith(
            (ref) => Stream.value(
              const Trip(id: otherTripId, name: '東京', title: '東京五日'),
            ),
          ),
          tripDaysProvider(
            _tripId,
          ).overrideWith((ref) => Stream.value(_fakeDays)),
          tripDaysProvider(
            otherTripId,
          ).overrideWith((ref) => Stream.value(_fakeDays)),
          tripSegmentsProvider(
            _tripId,
          ).overrideWith((ref) => Stream.value(const <TripSegment>[])),
          tripSegmentsProvider(
            otherTripId,
          ).overrideWith((ref) => Stream.value(const <TripSegment>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: _TripSwitchHarness(activeTripId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _enableTimelineEditing(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('entry-drag-11'))),
    );
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('entry-drop-2-1'))),
    );
    await gesture.up();
    await tester.pump();

    activeTripId.value = otherTripId;
    await tester.pump();
    pendingReorder.complete();
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderEntries(
        tripId: _tripId,
        updates: any(named: 'updates'),
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '2')).called(1);
    verifyNever(
      () => repo.recomputeTravel(
        tripId: otherTripId,
        day: any(named: 'day'),
      ),
    );
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

  testWidgets('排序模式只保留短按拖曳並顯示精簡卡片', (tester) async {
    await _pumpTimeline(tester);

    expect(find.byKey(const ValueKey('entry-move-to-day-11')), findsNothing);
    expect(find.byKey(const ValueKey('entry-drag-11')), findsNothing);
    expect(find.byKey(const ValueKey('entry-category-11')), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('黑潮之海旁集合'), findsOneWidget);
    expect(find.byType(TravelPill), findsWidgets);
    final normalCardHeight = tester
        .getSize(find.byKey(const ValueKey('entry-card-11')))
        .height;

    await _enableTimelineEditing(tester);

    expect(
      find.byWidgetPredicate((widget) => widget is LongPressDraggable),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate((widget) => widget is Draggable),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('entry-move-to-day-11')), findsNothing);
    final dragHandle = find.byKey(const ValueKey('entry-drag-11'));
    expect(dragHandle, findsOneWidget);
    expect(find.byKey(const ValueKey('entry-dismiss-11')), findsNothing);
    expect(find.byKey(const ValueKey('entry-category-11')), findsNothing);
    expect(find.text('4.6'), findsNothing);
    expect(find.text('黑潮之海旁集合'), findsNothing);
    expect(find.byType(TravelPill), findsNothing);
    final card = tester.getRect(find.byKey(const ValueKey('entry-card-11')));
    final drag = tester.getRect(dragHandle);
    expect(card.height, lessThan(normalCardHeight));
    expect(card.contains(drag.center), isTrue);
    expect(drag.size, const Size(44, 44));
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

  testWidgets('200 percent text keeps metadata and travel pill within layout', (
    tester,
  ) async {
    await _pumpTimeline(tester, textScaler: const TextScaler.linear(2));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byKey(const ValueKey('entry-card-12')));
    final time = tester.getRect(find.byKey(const ValueKey('entry-time-12')));
    final travel = tester.getRect(find.byType(TravelPill).first);

    expect(card.contains(time.center), isTrue);
    expect(travel.left, greaterThan(card.left - 60));
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

  testWidgets('entry tile 不因 master.type 恢復三色圓點', (tester) async {
    await _pumpTimeline(tester);

    expect(_entryDotColor(tester, 11), TpSystemColorsLight.tintDeep);
    expect(_entryDotColor(tester, 12), TpSystemColorsLight.tintDeep);

    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    expect(_entryDotColor(tester, 21), TpSystemColorsLight.tintDeep);
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

  testWidgets('Day selector 支援左右方向鍵切換目前行程日', (tester) async {
    await _pumpTimeline(tester, fetchDays: _scrollSpyDays);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('day-pill-1')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    var selector = tester.widget<TpHorizontalSelector<int>>(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    );
    expect(selector.value, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    selector = tester.widget<TpHorizontalSelector<int>>(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    );
    expect(selector.value, 1);
  });

  testWidgets('Day selector 以總天數與已選取狀態提供語意', (tester) async {
    await _pumpTimeline(tester);
    await tester.pumpAndSettle();

    final selected = tester
        .getSemantics(find.byKey(const ValueKey('day-pill-1')))
        .getSemanticsData();

    expect(selected.label, '第 1 天，共 2 天');
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('窄螢幕 Day selector 露出下一項並將指定 Day 置中', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpTimeline(tester, fetchDays: _selectorDays, initialDayNum: 5);
    await tester.pumpAndSettle();

    final selector = find.byKey(
      const ValueKey('trip-timeline-view-day-selector'),
    );
    final selected = find.byKey(const ValueKey('day-pill-5'));
    expect(
      tester.getCenter(selected).dx,
      closeTo(tester.getCenter(selector).dx, 1),
    );

    await _pumpTimeline(tester, fetchDays: _selectorDays, initialDayNum: 1);
    await tester.pumpAndSettle();
    final firstSelector = find.byKey(
      const ValueKey('trip-timeline-view-day-selector'),
    );
    final nextEdge = tester.getRect(find.byKey(const ValueKey('day-pill-4')));
    final selectorEdge = tester.getRect(firstSelector);
    expect(nextEdge.left, lessThan(selectorEdge.right));
    expect(nextEdge.right, greaterThan(selectorEdge.right));
  });

  testWidgets('3.2 倍輔助文字下 Day selector 與固定 header 隨內容增高', (tester) async {
    await _pumpTimeline(tester, textScaler: const TextScaler.linear(3.2));
    await tester.pumpAndSettle();

    final selector = find.byKey(
      const ValueKey('trip-timeline-view-day-selector'),
    );
    final selectorRect = tester.getRect(selector);
    final selectedLabelRect = tester.getRect(find.text('DAY 1'));

    expect(tester.takeException(), isNull);
    expect(selectorRect.height, greaterThan(TpSpacing.tapMin));
    expect(selectedLabelRect.top, greaterThanOrEqualTo(selectorRect.top));
    expect(selectedLabelRect.bottom, lessThanOrEqualTo(selectorRect.bottom));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('day-section-1'))).dy,
      greaterThanOrEqualTo(selectorRect.bottom - 1),
    );
  });

  testWidgets('水平拖曳只瀏覽 Day，點選才變更目前行程日', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpTimeline(tester, fetchDays: _selectorDays);
    await tester.pumpAndSettle();

    final selectorFinder = find.byKey(
      const ValueKey('trip-timeline-view-day-selector'),
    );
    await tester.drag(selectorFinder, const Offset(-180, 0));
    await tester.pumpAndSettle();

    var selector = tester.widget<TpHorizontalSelector<int>>(selectorFinder);
    expect(selector.value, 1);

    await tester.tap(find.byKey(const ValueKey('day-pill-4')));
    await tester.pumpAndSettle();
    selector = tester.widget<TpHorizontalSelector<int>>(selectorFinder);
    expect(selector.value, 4);
  });

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

  testWidgets('Reduce Motion 在窄螢幕直接定位遠距 Day selector', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpTimeline(
      tester,
      fetchDays: _selectorDays,
      initialDayNum: 5,
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(
      const ValueKey('trip-timeline-view-day-selector'),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.byKey(const ValueKey('day-pill-5'))).dx,
      closeTo(tester.getCenter(selector).dx, 1),
    );
  });

  testWidgets('指定 initialDayNum：初始啟用該日 pill', (tester) async {
    await _pumpTimeline(tester, initialDayNum: 2);
    await tester.pumpAndSettle();

    // 只有選取態才會長出膠囊；它是自己畫的實心填色，不是玻璃 —— 巢狀玻璃的
    // `glassColor` 會被軌道的 LiquidGlassLayer 吃掉，畫不出顏色。
    final pill = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('day-pill-2')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .where((deco) => deco.color != null)
        .single
        .color!;
    expect(
      (pill.r, pill.g, pill.b),
      isNot((
        TpSystemColorsLight.tint.r,
        TpSystemColorsLight.tint.g,
        TpSystemColorsLight.tint.b,
      )),
    );
    expect(pill.a, 1, reason: '半透明填色會被玻璃 shader 衰減到看不見');
  });

  testWidgets('無效 day deep link fallback 後共用選取日為實際 Day 1', (tester) async {
    await _pumpTimeline(tester, initialDayNum: 99);
    await tester.pumpAndSettle();

    expect(_selectorDayNum(tester), 1);
    expect(_sharedDayNum(tester), 1);
  });

  testWidgets('指定 initialEntryId：初始聚焦該停留點卡片', (tester) async {
    await _pumpTimeline(tester, initialEntryId: 22);
    await tester.pumpAndSettle();

    final focusedCard = tester.widget<Container>(
      find.byKey(const ValueKey('entry-card-22')),
    );
    final decoration = focusedCard.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(border.top.color, AppTheme.light().colorScheme.primary);
    expect(border.top.width, 2);
  });

  testWidgets('entry deep link 聚焦後共用選取日為 entry 所在 Day', (tester) async {
    await _pumpTimeline(tester, initialEntryId: 22);
    await tester.pumpAndSettle();

    expect(_selectorDayNum(tester), 2);
    expect(_sharedDayNum(tester), 2);
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
    final daySection = find.byKey(const ValueKey('day-section-1'));
    final before = tester.getTopLeft(daySection).dy;
    expect(before, lessThan(0));

    days.add(_longDays('after'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(daySection).dy, before);
  });

  testWidgets('days refresh 移除目前 Day 時同步 selector 與共用選取日', (tester) async {
    final days = StreamController<List<TripDay>>();
    addTearDown(days.close);
    await _pumpTimeline(tester, daysStream: days.stream);

    days.add(_fakeDays);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    days.add([_fakeDays.first]);
    await tester.pumpAndSettle();

    expect(_selectorDayNum(tester), 1);
    expect(_sharedDayNum(tester), 1);
  });

  testWidgets('loading 顯示 skeleton 條列', (tester) async {
    final neverCompletes = Completer<List<TripDay>>();
    await _pumpTimeline(tester, fetchDays: () => neverCompletes.future);

    expect(find.byKey(const ValueKey('timeline-skeleton')), findsOneWidget);
    final semantics = tester
        .getSemantics(find.byKey(const ValueKey('timeline-loading-state')))
        .getSemanticsData();
    expect(semantics.label, '正在載入行程時間軸');
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('detail 載入中仍以目前行程摘要顯示 selector title', (tester) async {
    final neverCompletes = Completer<Trip>();
    await _pumpTimeline(
      tester,
      fetchTrip: () => neverCompletes.future,
      trips: const [
        TripSummary(tripId: _tripId, name: 'okinawa', title: '沖繩摘要名稱'),
      ],
    );

    expect(find.text('沖繩摘要名稱'), findsOneWidget);
  });

  testWidgets('detail 沒有 title 時不以 slug 覆蓋摘要顯示名稱', (tester) async {
    await _pumpTimeline(
      tester,
      fetchTrip: () => const Trip(id: _tripId, name: 'okinawa'),
      trips: const [
        TripSummary(tripId: _tripId, name: 'okinawa', title: '沖繩摘要名稱'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('沖繩摘要名稱'), findsOneWidget);
    expect(find.text('okinawa'), findsNothing);
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
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('timeline-error-state')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('2026-04-23（四）'), findsOneWidget);
    expect(fetchDaysAttempts, 2);
  });

  testWidgets('點 entry tile 展開備選景點，不直接開啟編輯', (tester) async {
    await _pumpTimeline(tester);
    await tester.tap(find.text('美麗海水族館'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-alternates-11')), findsOneWidget);
    expect(find.text('尚無備選景點'), findsOneWidget);
    expect(find.text('編輯停留點'), findsNothing);

    await tester.tap(find.text('美麗海水族館'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-alternates-11')), findsNothing);
  });

  testWidgets('時間軸資料刷新保留已展開的停留點', (tester) async {
    final days = StreamController<List<TripDay>>();
    addTearDown(days.close);
    await _pumpTimeline(tester, daysStream: days.stream);

    days.add(_fakeDays);
    await tester.pumpAndSettle();
    await tester.tap(find.text('美麗海水族館'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-alternates-11')), findsOneWidget);

    days.add(List<TripDay>.from(_fakeDays));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entry-alternates-11')), findsOneWidget);
  });

  testWidgets('展開備選後可設為正選並重算當日交通', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.setEntryMaster(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    const alternateDays = [
      TripDay(
        id: 1,
        dayNum: 1,
        version: 1,
        timeline: [
          TimelineEntry(
            id: 11,
            sortOrder: 0,
            title: '美麗海水族館',
            version: 1,
            entryPoisVersion: '4',
            master: EntryPoiInfo(poiId: 101, name: '目前景點'),
            alternates: [EntryPoiInfo(poiId: 102, name: '備選景點')],
          ),
        ],
      ),
    ];
    await _pumpTimeline(tester, repo: repo, fetchDays: () => alternateDays);

    await tester.tap(find.text('美麗海水族館'));
    await tester.pumpAndSettle();
    final setMaster = find.byKey(const ValueKey('alternate-set-master-102'));
    await tester.ensureVisible(setMaster);
    await tester.pumpAndSettle();
    await tester.tap(setMaster);
    await tester.pumpAndSettle();

    verify(
      () => repo.setEntryMaster(
        tripId: _tripId,
        entryId: 11,
        poiId: 102,
        entryPoisVersion: '4',
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
  });

  testWidgets('景點更多選單固定六項三組，編輯使用短任務表單 sheet', (tester) async {
    await _pumpTimeline(tester);
    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-alternates-11')), findsNothing);

    for (final label in ['重新排序', '換景點', '編輯景點', '移動到其他天', '複製到其他天', '刪除景點']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(Divider), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('entry-edit-11')));
    await tester.pumpAndSettle();
    expect(find.text('編輯停留點'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-edit-submit')), findsOneWidget);
    expect(find.text('取消'), findsWidgets);
    expect(find.text('entry-edit-11'), findsNothing);
  });

  testWidgets('只有一天時移動與複製停用並說明原因', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpTimeline(tester, fetchDays: () => [_fakeDays.first]);
    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();

    for (final action in ['move', 'copy']) {
      final finder = find.byKey(ValueKey('entry-$action-11'));
      expect(
        tester
            .widget<TextButton>(
              find.descendant(of: finder, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );
      final label = action == 'move' ? '移動到其他天' : '複製到其他天';
      expect(find.bySemanticsLabel('$label，目前行程只有一天，無法使用'), findsOneWidget);
    }
    semantics.dispose();
  });

  testWidgets('移至其他 Day 使用短任務 sheet，並只送出一次 batch', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-move-11')));
    await tester.pumpAndSettle();

    expect(find.text('移至其他 Day'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-move-to-day-2')), findsOneWidget);
    expect(find.text('entry-move-11'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entry-move-to-day-2')));
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderEntries(
        tripId: _tripId,
        updates: [
          (id: 12, sortOrder: 0, dayId: 1),
          (id: 13, sortOrder: 1, dayId: 1),
          (id: 14, sortOrder: 2, dayId: 1),
          (id: 21, sortOrder: 0, dayId: 2),
          (id: 22, sortOrder: 1, dayId: 2),
          (id: 11, sortOrder: 2, dayId: 2),
        ],
      ),
    ).called(1);
    verifyNever(
      () => repo.moveEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    );
  });

  testWidgets('複製到其他 Day 使用短任務 sheet，pending 與失敗保留目標', (tester) async {
    final repo = _MockTripRepository();
    final firstAttempt = Completer<int>();
    var attempts = 0;
    when(
      () => repo.copyEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    ).thenAnswer((_) {
      attempts++;
      return attempts == 1 ? firstAttempt.future : Future.value(99);
    });
    await _pumpTimeline(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-copy-11')));
    await tester.pumpAndSettle();
    expect(find.text('複製到其他 Day'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-copy-to-day-2')));
    await tester.pump();
    expect(find.byKey(const ValueKey('entry-copy-progress')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('app-selection-cancel')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    firstAttempt.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('複製到其他 Day'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-copy-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-copy-to-day-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-copy-to-day-2')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('複製到其他 Day'), findsNothing);
  });

  testWidgets('移動 sheet 開啟後資料重排，依 entry ID 重找位置再送 batch', (tester) async {
    final days = StreamController<List<TripDay>>();
    addTearDown(days.close);
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
    await _pumpTimeline(tester, repo: repo, daysStream: days.stream);
    days.add(_fakeDays);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-move-11')));
    await tester.pumpAndSettle();

    final first = _fakeDays.first;
    days.add([
      TripDay(
        id: first.id,
        dayNum: first.dayNum,
        date: first.date,
        dayOfWeek: first.dayOfWeek,
        title: first.title,
        version: first.version + 1,
        timeline: [
          first.timeline[1],
          first.timeline[2],
          first.timeline[0],
          first.timeline[3],
        ],
      ),
      _fakeDays.last,
    ]);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('entry-move-to-day-2')));
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderEntries(
        tripId: _tripId,
        updates: [
          (id: 12, sortOrder: 0, dayId: 1),
          (id: 13, sortOrder: 1, dayId: 1),
          (id: 14, sortOrder: 2, dayId: 1),
          (id: 21, sortOrder: 0, dayId: 2),
          (id: 22, sortOrder: 1, dayId: 2),
          (id: 11, sortOrder: 2, dayId: 2),
        ],
      ),
    ).called(1);
  });

  testWidgets('移動 sheet 開啟後 entry 已被跨 Day 移動，拒絕 stale intent', (tester) async {
    final days = StreamController<List<TripDay>>();
    addTearDown(days.close);
    final repo = _MockTripRepository();
    await _pumpTimeline(tester, repo: repo, daysStream: days.stream);
    days.add(_fakeDays);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-move-11')));
    await tester.pumpAndSettle();

    final source = _fakeDays.first;
    final target = _fakeDays.last;
    days.add([
      TripDay(
        id: source.id,
        dayNum: source.dayNum,
        date: source.date,
        dayOfWeek: source.dayOfWeek,
        title: source.title,
        version: source.version + 1,
        timeline: source.timeline.skip(1).toList(),
      ),
      TripDay(
        id: target.id,
        dayNum: target.dayNum,
        date: target.date,
        dayOfWeek: target.dayOfWeek,
        title: target.title,
        version: target.version + 1,
        timeline: [source.timeline.first, ...target.timeline],
      ),
    ]);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-move-to-day-2')));
    await tester.pumpAndSettle();

    expect(find.text('行程內容已更新，請重新操作'), findsOneWidget);
    verifyNever(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    );
  });

  testWidgets('景點選單刪除先確認，確認前不呼叫 API', (tester) async {
    final repo = _MockTripRepository();
    final pendingDelete = Completer<void>();
    when(
      () => repo.deleteEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) => pendingDelete.future);
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-delete-11')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.deleteEntry(tripId: _tripId, entryId: 11));
    expect(find.textContaining('相關交通時間將重新計算'), findsOneWidget);
    expect(find.textContaining('無法復原'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('刪除'),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('delete-progress')), findsOneWidget);
    verify(() => repo.deleteEntry(tripId: _tripId, entryId: 11)).called(1);
    pendingDelete.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('刪除失敗保留資料並可重試，成功前不關閉資料狀態', (tester) async {
    final repo = _MockTripRepository();
    var attempts = 0;
    when(
      () => repo.deleteEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
    });
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-delete-11')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('刪除'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entry-11')), findsOneWidget);
    expect(find.text('刪除失敗，原資料已保留'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    verify(() => repo.deleteEntry(tripId: _tripId, entryId: 11)).called(2);
  });

  testWidgets('DELETE 成功後即使交通重算失敗也只刪除一次', (tester) async {
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
    ).thenThrow(StateError('recompute disposed'));
    await _pumpTimeline(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-delete-11')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('刪除'),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => repo.deleteEntry(tripId: _tripId, entryId: 11)).called(1);
    expect(find.text('刪除失敗，原資料已保留'), findsNothing);
    expect(find.text('重試'), findsNothing);
  });

  testWidgets('一般模式左滑 entry → 確認 → 刪除後重算交通', (tester) async {
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
    expect(
      tester
          .widget<SwipeToDelete>(find.byType(SwipeToDelete).first)
          .actionLabel,
      '刪除景點',
    );

    await tester.drag(
      find.byKey(const ValueKey('entry-dismiss-11')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    verifyNever(() => repo.deleteEntry(tripId: _tripId, entryId: 11));
    await tester.tap(
      find.byKey(
        const ValueKey<Object>((
          'swipe-delete-action',
          ValueKey('entry-dismiss-11'),
        )),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('刪除'),
      ),
    );
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

  testWidgets('每個 entry 有拖曳 handle', (tester) async {
    await _pumpTimeline(tester);
    await _enableTimelineEditing(tester);
    expect(find.byKey(const ValueKey('entry-drag-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-drag-12')), findsOneWidget);
  });

  testWidgets('拖曳 handle 提供上移、下移與移至其他 Day 輔助操作，並共用 batch', (tester) async {
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

    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('entry-drag-12')),
    );
    final actions = semantics.properties.customSemanticsActions!;
    expect(actions.keys.map((action) => action.label), [
      '上移',
      '下移',
      '移至其他 Day',
    ]);

    actions.entries.singleWhere((entry) => entry.key.label == '上移').value();
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderEntries(
        tripId: _tripId,
        updates: [
          (id: 12, sortOrder: 0, dayId: 1),
          (id: 11, sortOrder: 1, dayId: 1),
          (id: 13, sortOrder: 2, dayId: 1),
          (id: 14, sortOrder: 3, dayId: 1),
        ],
      ),
    ).called(1);
  });

  testWidgets('Full Keyboard Access 方向鍵與拖曳共用 batch 排序', (tester) async {
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

    final handle = find.byKey(const ValueKey('entry-drag-12'));
    Focus.of(tester.element(handle)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderEntries(
        tripId: _tripId,
        updates: any(named: 'updates'),
      ),
    ).called(1);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('entry-12'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('entry-11'))).dy),
    );
  });

  testWidgets('拖曳 feedback 維持原行程卡寬度', (tester) async {
    tester.view.physicalSize = const Size(393, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTimeline(tester);
    await _enableTimelineEditing(tester);

    final cardWidth = tester
        .getSize(find.byKey(const ValueKey('entry-card-11')))
        .width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('entry-drag-11'))),
    );
    await tester.pump();

    final feedback = find.byKey(const ValueKey('entry-drag-feedback-11'));
    expect(feedback, findsOneWidget);
    expect(tester.getSize(feedback).width, closeTo(cardWidth, 0.1));

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('拖曳停在邊緣時持續自動捲動，結束後立即停止', (tester) async {
    tester.view.physicalSize = const Size(393, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTimeline(tester);
    await _enableTimelineEditing(tester);

    final scroll = tester
        .widget<CustomScrollView>(
          find.byKey(const ValueKey('trip-timeline-scroll')),
        )
        .controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(0));

    final handle = find.byKey(const ValueKey('entry-drag-11'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveTo(Offset(tester.getCenter(handle).dx, 690));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -1));
    await tester.pump(const Duration(milliseconds: 60));
    final firstOffset = scroll.offset;

    await tester.pump(const Duration(milliseconds: 250));
    expect(scroll.offset, greaterThan(firstOffset));

    await gesture.cancel();
    await tester.pump();
    final stoppedOffset = scroll.offset;
    await tester.pump(const Duration(milliseconds: 250));
    expect(scroll.offset, stoppedOffset);
  });

  testWidgets('短按拖曳 handle 同日排序，畫面與 API 順序一致', (tester) async {
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

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('entry-drag-11'))),
    );
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('entry-drop-1-3'))),
    );
    await gesture.up();
    await tester.pump();

    final item12Top = tester.getTopLeft(find.text('海人食堂')).dy;
    final item13Top = tester.getTopLeft(find.text('美國村購物')).dy;
    final item11Top = tester.getTopLeft(find.text('美麗海水族館')).dy;
    expect(item12Top, lessThan(item13Top));
    expect(item13Top, lessThan(item11Top));

    final captured =
        verify(
              () => repo.reorderEntries(
                tripId: _tripId,
                updates: captureAny(named: 'updates'),
              ),
            ).captured.single
            as List<({int id, int sortOrder, int? dayId})>;
    expect(captured.map((item) => item.id), [12, 13, 11, 14]);
    expect(captured.every((item) => item.dayId == 1), isTrue);
    final busyHandle = tester.widget<Semantics>(
      find.byKey(const ValueKey('entry-drag-12')),
    );
    expect(busyHandle.properties.enabled, isFalse);
    expect(busyHandle.properties.value, '正在更新');
    expect(
      busyHandle.properties.customSemanticsActions,
      anyOf(isNull, isEmpty),
    );

    pendingReorder.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('短按拖曳 handle 可跨 DAY，單次 API 同步兩天順序', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('entry-drag-11'))),
    );
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('entry-drop-2-1'))),
    );
    await gesture.up();
    await tester.pump();

    final captured =
        verify(
              () => repo.reorderEntries(
                tripId: _tripId,
                updates: captureAny(named: 'updates'),
              ),
            ).captured.single
            as List<({int id, int sortOrder, int? dayId})>;
    expect(captured, [
      (id: 12, sortOrder: 0, dayId: 1),
      (id: 13, sortOrder: 1, dayId: 1),
      (id: 14, sortOrder: 2, dayId: 1),
      (id: 21, sortOrder: 0, dayId: 2),
      (id: 11, sortOrder: 1, dayId: 2),
      (id: 22, sortOrder: 2, dayId: 2),
    ]);
    expect(
      tester.getTopLeft(find.text('單軌電車移動')).dy,
      lessThan(tester.getTopLeft(find.text('美麗海水族館')).dy),
    );
    expect(
      tester.getTopLeft(find.text('美麗海水族館')).dy,
      lessThan(tester.getTopLeft(find.text('首里城公園')).dy),
    );

    pendingReorder.complete();
    await tester.pumpAndSettle();
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '1')).called(1);
    verify(() => repo.recomputeTravel(tripId: _tripId, day: '2')).called(1);
  });

  testWidgets('跨 DAY 排序失敗會還原來源與目標日', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _MockTripRepository();
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenThrow(Exception('network'));
    await _pumpTimeline(tester, repo: repo);
    await _enableTimelineEditing(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('entry-drag-11'))),
    );
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('entry-drop-2-1'))),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('排序失敗，已還原原本順序'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('entry-11'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('entry-12'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('entry-14'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('entry-21'))).dy),
    );
    verifyNever(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    );
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
