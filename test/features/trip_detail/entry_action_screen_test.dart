import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/entry_action_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const tripId = 'okinawa-trip-2026';
  const entry = TimelineEntry(
    id: 101,
    dayId: 11,
    sortOrder: 0,
    startTime: '10:00',
    endTime: '11:30',
    title: '首里城公園',
    version: 7,
    master: EntryPoiInfo(poiId: 501, name: '首里城公園', type: 'attraction'),
  );
  const refreshedEntry = TimelineEntry(
    id: 101,
    dayId: 11,
    sortOrder: 0,
    startTime: '10:00',
    endTime: '11:30',
    title: '首里城公園',
    version: 8,
    master: EntryPoiInfo(poiId: 501, name: '首里城公園', type: 'attraction'),
  );
  const days = [
    TripDay(id: 11, dayNum: 1, date: '2026-04-23', title: '抵達', version: 1),
    TripDay(id: 12, dayNum: 2, date: '2026-04-24', title: '那霸', version: 1),
  ];

  late MockTripRepository mockTripRepository;

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchEntry(tripId, 101),
    ).thenAnswer((_) async => entry);
    when(
      () => mockTripRepository.fetchDays(tripId),
    ).thenAnswer((_) async => days);
    when(
      () => mockTripRepository.copyEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    ).thenAnswer(
      (_) async => const TimelineEntry(
        id: 902,
        dayId: 12,
        sortOrder: 2,
        title: '首里城公園',
        version: 1,
      ),
    );
    when(
      () => mockTripRepository.moveEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer(
      (_) async => const TimelineEntry(
        id: 101,
        dayId: 12,
        sortOrder: 2,
        title: '首里城公園',
        version: 8,
      ),
    );
    when(
      () => mockTripRepository.recomputeTravel(
        any(),
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildRouterApp(EntryActionKind action) {
    final actionSegment = action == EntryActionKind.copy ? 'copy' : 'move';
    final router = GoRouter(
      initialLocation: '/trips/$tripId/stop/101/$actionSegment',
      routes: [
        GoRoute(
          path: '/trips/:tripId/stop/:entryId/:action',
          builder: (context, state) => EntryActionScreen(
            tripId: state.pathParameters['tripId']!,
            entryId: int.parse(state.pathParameters['entryId']!),
            action: state.pathParameters['action'] == 'move'
                ? EntryActionKind.move
                : EntryActionKind.copy,
          ),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('trip:${state.pathParameters['tripId']}')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(mockTripRepository)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('copy：選目標 day 後複製 entry 並重算目標日', (tester) async {
    await tester.pumpWidget(buildRouterApp(EntryActionKind.copy));
    await tester.pump();
    await tester.pump();

    expect(find.text('複製到哪一天'), findsOneWidget);
    expect(find.text('Day 1 · 抵達（目前）'), findsOneWidget);
    expect(find.text('Day 2 · 那霸'), findsOneWidget);

    await tester.tap(find.text('Day 2 · 那霸'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '複製'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.copyEntry(
        tripId: tripId,
        entryId: 101,
        targetDayId: 12,
      ),
    ).called(1);
    verify(
      () => mockTripRepository.recomputeTravel(tripId, dayNum: 2),
    ).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });

  testWidgets('move：選目標 day 後帶 expectedVersion 移動並重算來源/目標日', (tester) async {
    await tester.pumpWidget(buildRouterApp(EntryActionKind.move));
    await tester.pump();
    await tester.pump();

    expect(find.text('移動到哪一天'), findsOneWidget);

    await tester.tap(find.text('Day 2 · 那霸'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '移動'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.moveEntry(
        tripId: tripId,
        entryId: 101,
        targetDayId: 12,
        expectedVersion: 7,
      ),
    ).called(1);
    verify(
      () => mockTripRepository.recomputeTravel(tripId, dayNum: 1),
    ).called(1);
    verify(
      () => mockTripRepository.recomputeTravel(tripId, dayNum: 2),
    ).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });

  testWidgets('move 遇到 STALE_ENTRY 時重抓 entry version 後 retry', (tester) async {
    var fetchCount = 0;
    when(() => mockTripRepository.fetchEntry(tripId, 101)).thenAnswer((
      _,
    ) async {
      fetchCount++;
      return fetchCount == 1 ? entry : refreshedEntry;
    });
    when(
      () => mockTripRepository.moveEntry(
        tripId: tripId,
        entryId: 101,
        targetDayId: 12,
        expectedVersion: 7,
      ),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'STALE_ENTRY',
        message: 'expected version 7, current 8',
      ),
    );
    when(
      () => mockTripRepository.moveEntry(
        tripId: tripId,
        entryId: 101,
        targetDayId: 12,
        expectedVersion: 8,
      ),
    ).thenAnswer(
      (_) async => const TimelineEntry(
        id: 101,
        dayId: 12,
        sortOrder: 2,
        title: '首里城公園',
        version: 9,
      ),
    );

    await tester.pumpWidget(buildRouterApp(EntryActionKind.move));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Day 2 · 那霸'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '移動'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.moveEntry(
        tripId: tripId,
        entryId: 101,
        targetDayId: 12,
        expectedVersion: 7,
      ),
    ).called(1);
    verify(
      () => mockTripRepository.moveEntry(
        tripId: tripId,
        entryId: 101,
        targetDayId: 12,
        expectedVersion: 8,
      ),
    ).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });
}
