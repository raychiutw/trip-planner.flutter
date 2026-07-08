import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/add_entry_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/poi.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const tripId = 'okinawa-trip-2026';
  const trip = Trip(id: tripId, name: 'Okinawa', title: '沖繩家族之旅');
  const days = [
    TripDay(id: 11, dayNum: 1, date: '2026-04-23', title: '抵達', version: 1),
    TripDay(id: 12, dayNum: 2, date: '2026-04-24', title: '那霸', version: 1),
  ];
  const searchResult = PoiSearchResult(
    placeId: 'ChIJ-shuri',
    name: '首里城',
    address: '沖繩縣那霸市首里金城町',
    lat: 26.217,
    lng: 127.719,
    category: 'tourist_attraction',
    rating: 4.4,
  );
  const favorite = PoiFavorite(
    id: 88,
    userId: 'user-1',
    poiId: 501,
    favoritedAt: '2026-07-08T12:00:00Z',
    poiName: '玉陵',
    poiAddress: '沖繩縣那霸市',
    poiType: 'attraction',
    poiRating: 4.2,
  );

  late MockTripRepository mockTripRepository;

  setUpAll(() {
    registerFallbackValue(searchResult);
  });

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchTrip(tripId),
    ).thenAnswer((_) async => trip);
    when(
      () => mockTripRepository.fetchDays(tripId),
    ).thenAnswer((_) async => days);
    when(
      () => mockTripRepository.fetchPoiFavorites(),
    ).thenAnswer((_) async => const [favorite]);
    when(
      () => mockTripRepository.searchPois(
        query: any(named: 'query'),
        region: any(named: 'region'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const [searchResult]);
    when(
      () => mockTripRepository.createEntryFromPoiSearchResult(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        poi: any(named: 'poi'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTripRepository.createCustomEntry(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        name: any(named: 'name'),
        note: any(named: 'note'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        poiType: any(named: 'poiType'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTripRepository.recomputeTravel(
        any(),
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTripRepository.addPoiFavoriteToTrip(
        any(),
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer(
      (_) async => const PoiFavoriteAddToTripResult(
        ok: true,
        entryId: 901,
        dayId: 12,
        sortOrder: 2,
        startTime: '09:00',
        endTime: '10:00',
      ),
    );
  });

  Widget buildRouterApp({
    String initialLocation = '/trips/$tripId/add-entry?day=2',
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/trips/:tripId/add-entry',
          builder: (context, state) => AddEntryScreen(
            tripId: state.pathParameters['tripId']!,
            initialDayNum: int.tryParse(state.uri.queryParameters['day'] ?? ''),
            initialSource: state.uri.queryParameters['tab'],
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/add-custom-stop',
          builder: (context, state) => AddEntryScreen(
            tripId: state.pathParameters['tripId']!,
            initialDayNum: int.tryParse(state.uri.queryParameters['day'] ?? ''),
            initialSource: 'custom',
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

  testWidgets('搜尋 POI 後可加入指定 day 並觸發 recompute', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('新增景點'), findsOneWidget);
    expect(find.text('Day 2 · 那霸'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('add-entry-search-input')),
      '首里城',
    );
    await tester.tap(find.byTooltip('搜尋'));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(of: find.byType(Card), matching: find.text('首里城')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('add-entry-add-search-ChIJ-shuri')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.createEntryFromPoiSearchResult(
        tripId: tripId,
        dayNum: 2,
        poi: searchResult,
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
    verify(
      () => mockTripRepository.recomputeTravel(tripId, dayNum: 2),
    ).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });

  testWidgets('收藏 tab 可用 4-field favorite fast-path 加入 day', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('收藏'));
    await tester.pump();
    await tester.pump();

    expect(find.text('玉陵'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-entry-add-favorite-88')));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.addPoiFavoriteToTrip(
        88,
        tripId: tripId,
        dayNum: 2,
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });

  testWidgets('自訂 tab 可用座標新增景點並觸發 recompute', (tester) async {
    await tester.pumpWidget(
      buildRouterApp(initialLocation: '/trips/$tripId/add-custom-stop?day=2'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('自訂'), findsOneWidget);
    expect(find.text('Day 2 · 那霸'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('add-entry-custom-title')),
      '巷口咖啡',
    );
    await tester.enterText(
      find.byKey(const ValueKey('add-entry-start-time')),
      '14:30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('add-entry-end-time')),
      '15:30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('add-entry-custom-lat')),
      '26.2145',
    );
    await tester.enterText(
      find.byKey(const ValueKey('add-entry-custom-lng')),
      '127.6812',
    );
    await tester.enterText(
      find.byKey(const ValueKey('add-entry-custom-note')),
      '朋友推薦的甜點店',
    );
    final submitButton = find.byKey(const ValueKey('add-entry-add-custom'));
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.createCustomEntry(
        tripId: tripId,
        dayNum: 2,
        name: '巷口咖啡',
        note: '朋友推薦的甜點店',
        lat: 26.2145,
        lng: 127.6812,
        poiType: 'attraction',
        startTime: '14:30',
        endTime: '15:30',
      ),
    ).called(1);
    verify(
      () => mockTripRepository.recomputeTravel(tripId, dayNum: 2),
    ).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });
}
