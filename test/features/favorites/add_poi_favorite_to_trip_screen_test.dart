import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/add_poi_favorite_to_trip_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/poi.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const favorite = PoiFavorite(
    id: 88,
    userId: 'user-1',
    poiId: 501,
    favoritedAt: '2026-07-08T12:00:00Z',
    poiName: '首里城公園',
    poiAddress: '沖繩縣那霸市',
    poiType: 'attraction',
    poiRating: 4.4,
  );
  const trip = TripSummary(
    tripId: 'okinawa-trip-2026',
    name: 'okinawa-trip-2026',
    title: '沖繩家族之旅',
    totalDays: 3,
  );
  const day = TripDay(
    id: 11,
    dayNum: 2,
    date: '2026-04-24',
    title: '那霸市區',
    version: 1,
  );
  const searchResult = PoiSearchResult(
    placeId: 'ChIJ-shuri',
    name: '首里城',
    address: '沖繩縣那霸市首里金城町',
    lat: 26.217,
    lng: 127.719,
    category: 'tourist_attraction',
  );

  late MockTripRepository mockTripRepository;

  setUpAll(() {
    registerFallbackValue(searchResult);
  });

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchPoiFavorites(),
    ).thenAnswer((_) async => const [favorite]);
    when(
      () => mockTripRepository.fetchMyTrips(),
    ).thenAnswer((_) async => const [trip]);
    when(
      () => mockTripRepository.fetchDays('okinawa-trip-2026'),
    ).thenAnswer((_) async => const [day]);
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
        dayId: 11,
        sortOrder: 2,
        startTime: '09:00',
        endTime: '10:00',
      ),
    );
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
      () => mockTripRepository.recomputeTravel(
        any(),
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildRouterApp() {
    final fakeRouter = GoRouter(
      initialLocation: '/favorites/88/add-to-trip',
      routes: [
        GoRoute(
          path: '/favorites/:favoriteId/add-to-trip',
          builder: (context, state) => AddPoiFavoriteToTripScreen(
            favoriteId: int.parse(state.pathParameters['favoriteId']!),
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
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: fakeRouter,
      ),
    );
  }

  Widget buildDirectRouterApp() {
    final fakeRouter = GoRouter(
      initialLocation: '/add-to-trip',
      routes: [
        GoRoute(
          path: '/add-to-trip',
          builder: (context, state) =>
              const AddPoiFavoriteToTripScreen(directPoi: searchResult),
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
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: fakeRouter,
      ),
    );
  }

  testWidgets('渲染收藏摘要、trip/day 下拉與時間欄位', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('加入行程'), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('沖繩家族之旅'), findsOneWidget);
    expect(find.text('Day 2 · 那霸市區'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '09:00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10:00'), findsOneWidget);
  });

  testWidgets('送出後呼叫 addPoiFavoriteToTrip 並回到 trip detail', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '加入行程'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.addPoiFavoriteToTrip(
        88,
        tripId: 'okinawa-trip-2026',
        dayNum: 2,
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
    expect(find.text('trip:okinawa-trip-2026'), findsOneWidget);
  });

  testWidgets('direct-mode 送出後直建 entry 並觸發 recomputeTravel', (tester) async {
    await tester.pumpWidget(buildDirectRouterApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('首里城'), findsOneWidget);
    expect(find.text('沖繩縣那霸市首里金城町'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '加入行程'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.createEntryFromPoiSearchResult(
        tripId: 'okinawa-trip-2026',
        dayNum: 2,
        poi: searchResult,
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
    verify(
      () => mockTripRepository.recomputeTravel('okinawa-trip-2026', dayNum: 2),
    ).called(1);
    verifyNever(() => mockTripRepository.fetchPoiFavorites());
    expect(find.text('trip:okinawa-trip-2026'), findsOneWidget);
  });

  testWidgets('direct-mode recomputeTravel 失敗不阻擋已建立 entry 的導回', (tester) async {
    when(
      () => mockTripRepository.recomputeTravel(
        any(),
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((_) async => throw Exception('recompute failed'));

    await tester.pumpWidget(buildDirectRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '加入行程'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.createEntryFromPoiSearchResult(
        tripId: 'okinawa-trip-2026',
        dayNum: 2,
        poi: searchResult,
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
    verify(
      () => mockTripRepository.recomputeTravel('okinawa-trip-2026', dayNum: 2),
    ).called(1);
    expect(find.text('trip:okinawa-trip-2026'), findsOneWidget);
  });
}
