import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/trip_form_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

List<TripDay> _continuousTripDays() => const [
  TripDay(
    id: 11,
    dayNum: 1,
    date: '2026-10-01',
    dayOfWeek: '四',
    label: 'Day 1',
    title: '抵達日',
    version: 1,
  ),
  TripDay(
    id: 12,
    dayNum: 2,
    date: '2026-10-02',
    dayOfWeek: '五',
    label: 'Day 2',
    title: '市區散策',
    version: 1,
    timeline: [
      TimelineEntry(id: 101, dayId: 12, sortOrder: 0, title: '首里城', version: 1),
      TimelineEntry(id: 102, dayId: 12, sortOrder: 1, title: '國際通', version: 1),
    ],
  ),
  TripDay(
    id: 13,
    dayNum: 3,
    date: '2026-10-03',
    dayOfWeek: '六',
    label: 'Day 3',
    title: '北部觀光',
    version: 1,
  ),
];

List<TripDay> _gapTripDays() => const [
  TripDay(
    id: 11,
    dayNum: 1,
    date: '2026-10-01',
    dayOfWeek: '四',
    label: 'Day 1',
    title: '抵達日',
    version: 1,
  ),
  TripDay(
    id: 13,
    dayNum: 2,
    date: '2026-10-03',
    dayOfWeek: '六',
    label: 'Day 2',
    title: '北部觀光',
    version: 1,
  ),
];

void main() {
  late MockTripRepository mockTripRepository;

  setUpAll(() {
    registerFallbackValue(const <TripDestinationInput>[]);
  });

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.createTrip(
        id: any(named: 'id'),
        name: any(named: 'name'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) async => 'trip-generated');
    when(() => mockTripRepository.fetchTrip(any())).thenAnswer(
      (_) async => const Trip(
        id: 'okinawa-trip-2026',
        name: '沖繩',
        title: '沖繩家族旅行',
        description: '想放慢步調',
        published: false,
        lang: 'zh-TW',
        startDate: '2026-10-01',
        endDate: '2026-10-03',
        destinations: [
          TripDestination(name: '那霸', lat: 26.2145, lng: 127.6812),
        ],
      ),
    );
    when(
      () => mockTripRepository.fetchDays(any()),
    ).thenAnswer((_) async => _continuousTripDays());
    when(
      () => mockTripRepository.updateTrip(
        id: any(named: 'id'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        published: any(named: 'published'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTripRepository.createTripDay(
        tripId: any(named: 'tripId'),
        position: any(named: 'position'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) async => const TripDay(
        id: 14,
        dayNum: 4,
        date: '2026-10-04',
        dayOfWeek: '日',
        label: 'Day 4',
        title: 'Day 4',
        version: 0,
      ),
    );
    when(
      () => mockTripRepository.deleteTripDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer(
      (_) async => const TripDayDeleteResult(ok: true, removedEntryCount: 2),
    );
    when(
      () => mockTripRepository.shiftTripDays(
        tripId: any(named: 'tripId'),
        startDate: any(named: 'startDate'),
      ),
    ).thenAnswer(
      (_) async => const TripDaysShiftResult(
        ok: true,
        newStartDate: '2026-10-05',
        newEndDate: '2026-10-07',
        daysShifted: 3,
      ),
    );
  });

  Widget buildRouterApp({required String initialLocation}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) =>
              const Scaffold(body: Text('trips-list-probe')),
        ),
        GoRoute(
          path: '/trips/new',
          builder: (context, state) => const TripFormScreen.create(),
        ),
        GoRoute(
          path: '/trips/:tripId/edit',
          builder: (context, state) =>
              TripFormScreen.edit(tripId: state.pathParameters['tripId']!),
        ),
      ],
    );
    return ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(mockTripRepository)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('新增行程表單送出 createTrip 並回到 trips list', (tester) async {
    await tester.pumpWidget(buildRouterApp(initialLocation: '/trips/new'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('trip-form-destination-0')),
      '那霸',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-title')),
      '沖繩家族旅行',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-start-date')),
      '2026-10-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-end-date')),
      '2026-10-03',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-description')),
      '想放慢步調',
    );
    await tester.tap(find.byKey(const ValueKey('trip-form-submit')));
    await tester.pumpAndSettle();

    final captured = verify(
      () => mockTripRepository.createTrip(
        id: captureAny(named: 'id'),
        name: '那霸',
        title: '沖繩家族旅行',
        description: '想放慢步調',
        startDate: '2026-10-01',
        endDate: '2026-10-03',
        countries: 'JP',
        published: true,
        lang: 'zh-TW',
        destinations: captureAny(named: 'destinations'),
      ),
    ).captured;
    expect(captured.first as String, startsWith('trip-'));
    final destinations = captured.last as List<TripDestinationInput>;
    expect(destinations.single.name, '那霸');
    expect(find.text('trips-list-probe'), findsOneWidget);
  });

  testWidgets('編輯行程表單載入既有資料並送出 updateTrip', (tester) async {
    await tester.pumpWidget(
      buildRouterApp(initialLocation: '/trips/okinawa-trip-2026/edit'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('編輯行程'), findsOneWidget);
    expect(find.text('2026-10-01 - 2026-10-03'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('trip-form-title')),
      '沖繩慢旅行',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-description')),
      '',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('trip-form-submit')));
    await tester.tap(find.byKey(const ValueKey('trip-form-published')));
    await tester.tap(find.byKey(const ValueKey('trip-form-submit')));
    await tester.pumpAndSettle();

    final captured = verify(
      () => mockTripRepository.updateTrip(
        id: 'okinawa-trip-2026',
        title: '沖繩慢旅行',
        description: null,
        published: true,
        lang: 'zh-TW',
        destinations: captureAny(named: 'destinations'),
      ),
    ).captured;
    final destinations = captured.single as List<TripDestinationInput>;
    expect(destinations.single.name, '那霸');
    expect(find.text('trips-list-probe'), findsOneWidget);
  });

  testWidgets('編輯行程可從結尾新增一天', (tester) async {
    await tester.pumpWidget(
      buildRouterApp(initialLocation: '/trips/okinawa-trip-2026/edit'),
    );
    await tester.pumpAndSettle();

    expect(find.text('行程天數'), findsOneWidget);
    expect(find.text('2026-10-01 - 2026-10-03'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-form-day-append')),
    );
    await tester.tap(find.byKey(const ValueKey('trip-form-day-append')));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.createTripDay(
        tripId: 'okinawa-trip-2026',
        position: 'end',
        date: null,
      ),
    ).called(1);
  });

  testWidgets('編輯行程可補回缺漏日期', (tester) async {
    when(
      () => mockTripRepository.fetchDays(any()),
    ).thenAnswer((_) async => _gapTripDays());
    await tester.pumpWidget(
      buildRouterApp(initialLocation: '/trips/okinawa-trip-2026/edit'),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-form-day-gap-2026-10-02')),
    );
    await tester.tap(
      find.byKey(const ValueKey('trip-form-day-gap-2026-10-02')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.createTripDay(
        tripId: 'okinawa-trip-2026',
        position: 'insert',
        date: '2026-10-02',
      ),
    ).called(1);
  });

  testWidgets('編輯行程刪除有景點的 day 前會確認並顯示影響範圍', (tester) async {
    await tester.pumpWidget(
      buildRouterApp(initialLocation: '/trips/okinawa-trip-2026/edit'),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-form-day-remove-2')),
    );
    await tester.tap(find.byKey(const ValueKey('trip-form-day-remove-2')));
    await tester.pumpAndSettle();

    expect(find.text('這會刪除 Day 2 與 2 個景點，後續行程日會重新編號。'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('trip-form-day-delete-confirm')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.deleteTripDay(
        tripId: 'okinawa-trip-2026',
        dayNum: 2,
      ),
    ).called(1);
  });

  testWidgets('編輯行程可整段平移日期', (tester) async {
    await tester.pumpWidget(
      buildRouterApp(initialLocation: '/trips/okinawa-trip-2026/edit'),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-form-day-shift')),
    );
    await tester.tap(find.byKey(const ValueKey('trip-form-day-shift')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-day-shift-date')),
      '2026-10-05',
    );
    await tester.tap(find.byKey(const ValueKey('trip-form-day-shift-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.shiftTripDays(
        tripId: 'okinawa-trip-2026',
        startDate: '2026-10-05',
      ),
    ).called(1);
  });
}
