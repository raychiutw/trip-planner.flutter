import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/map_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/user.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTripRepository extends Mock implements TripRepository {}

class MockRequestsRepository extends Mock implements RequestsRepository {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

class MockMapRepository extends Mock implements MapRepository {}

const releaseSmokeTrip = Trip(id: 'okinawa', name: 'okinawa', title: '沖繩家族之旅');

const releaseSmokeTrips = [
  TripSummary(
    tripId: 'okinawa',
    name: 'okinawa',
    title: '沖繩家族之旅',
    totalDays: 2,
    countries: 'JP',
  ),
];

const releaseSmokeDays = [
  TripDay(
    id: 1,
    dayNum: 1,
    title: '抵達那霸',
    version: 0,
    timeline: [
      TimelineEntry(
        id: 11,
        sortOrder: 0,
        version: 0,
        startTime: '10:00',
        endTime: '11:00',
        title: '那霸機場',
      ),
    ],
  ),
  TripDay(
    id: 2,
    dayNum: 2,
    title: '首里散策',
    version: 0,
    timeline: [
      TimelineEntry(
        id: 21,
        sortOrder: 0,
        version: 0,
        startTime: '09:00',
        endTime: '10:00',
        title: '首里城',
      ),
    ],
  ),
];

const releaseSmokeFavorites = [
  PoiFavorite(
    id: 7,
    userId: 'u-1',
    poiId: 501,
    favoritedAt: '2026-06-01T10:00:00Z',
    poiName: '美麗海水族館',
    poiAddress: '沖繩縣國頭郡本部町石川424',
    poiType: 'attraction',
    note: '雨天備案',
    poiRating: 4.6,
  ),
  PoiFavorite(
    id: 8,
    userId: 'u-1',
    poiId: 502,
    favoritedAt: '2026-06-02T10:00:00Z',
    poiName: '暖暮拉麵',
    poiAddress: '那霸市牧志2-16-10',
    poiType: 'restaurant',
  ),
];

class AppFlowFixture {
  AppFlowFixture._({
    required this.auth,
    required this.trips,
    required this.requests,
    required this.favorites,
    required this.map,
    required this.apiClient,
  });

  factory AppFlowFixture.loggedOut() {
    final auth = MockAuthRepository();
    final trips = MockTripRepository();
    final requests = MockRequestsRepository();
    final favorites = MockFavoritesRepository();
    final map = MockMapRepository();
    final apiClient = MockApiClient();

    when(auth.currentUser).thenAnswer((_) async => null);
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const UserInfo(
        id: 'u-1',
        email: 'ray@example.com',
        displayName: 'Ray',
      ),
    );
    when(auth.fetchAiAuthorization).thenAnswer((_) async => true);
    when(auth.authorizeAi).thenAnswer((_) async => true);

    when(trips.watchMyTrips).thenAnswer((_) => Stream.value(releaseSmokeTrips));
    when(
      () => trips.watchTrip('okinawa'),
    ).thenAnswer((_) => Stream.value(releaseSmokeTrip));
    when(
      () => trips.watchDays('okinawa'),
    ).thenAnswer((_) => Stream.value(releaseSmokeDays));
    when(
      () => trips.watchNotes('okinawa'),
    ).thenAnswer((_) => Stream.value(const TripNotes()));
    when(
      () => trips.watchSegments(tripId: 'okinawa'),
    ).thenAnswer((_) => Stream.value(const <TripSegment>[]));

    when(
      () => requests.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));
    when(
      favorites.watchFavorites,
    ).thenAnswer((_) => Stream.value(releaseSmokeFavorites));

    return AppFlowFixture._(
      auth: auth,
      trips: trips,
      requests: requests,
      favorites: favorites,
      map: map,
      apiClient: apiClient,
    );
  }

  final MockAuthRepository auth;
  final MockTripRepository trips;
  final MockRequestsRepository requests;
  final MockFavoritesRepository favorites;
  final MockMapRepository map;
  final MockApiClient apiClient;

  Widget get app => ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      authRepositoryProvider.overrideWithValue(auth),
      tripRepositoryProvider.overrideWithValue(trips),
      requestsRepositoryProvider.overrideWithValue(requests),
      favoritesRepositoryProvider.overrideWithValue(favorites),
      mapRepositoryProvider.overrideWithValue(map),
      settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      tripMapCanvasBuilderProvider.overrideWithValue(fakeTripMapBuilder),
    ],
    child: const TriplineApp(),
  );
}

Widget fakeTripMapBuilder(TripMapCanvasConfig config) =>
    _FakeTripMapCanvas(config: config);

class _FakeTripMapCanvas extends StatefulWidget {
  const _FakeTripMapCanvas({required this.config});

  final TripMapCanvasConfig config;

  @override
  State<_FakeTripMapCanvas> createState() => _FakeTripMapCanvasState();
}

class _FakeTripMapCanvasState extends State<_FakeTripMapCanvas> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.config.onMapReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('fake-trip-map-canvas'),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: const Center(child: Text('Google Map fixture')),
  );
}

Finder _rootTab(String label) => find.descendant(
  of: find.byKey(const ValueKey('apple-root-tab-bar')),
  matching: find.bySemanticsLabel(label),
);

Future<void> runAppOwnedReleaseFlow(WidgetTester tester) async {
  final fixture = AppFlowFixture.loggedOut();
  await tester.pumpWidget(fixture.app);
  await tester.pumpAndSettle();

  expect(find.byType(LoginScreen), findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey('login-email-field')),
    'ray@example.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password-field')),
    'secret',
  );
  await tester.tap(find.byKey(const ValueKey('login-submit-button')));
  await tester.pumpAndSettle();

  expect(find.byType(TripsListScreen), findsOneWidget);
  verify(
    () => fixture.auth.login(email: 'ray@example.com', password: 'secret'),
  ).called(1);

  await tester.tap(find.text('沖繩家族之旅').first);
  await tester.pumpAndSettle();
  expect(find.text('那霸機場'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  expect(find.text('首里城'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-action-notes')));
  await tester.pumpAndSettle();
  expect(find.text('行程筆記'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('trip-timeline-map')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
  expect(find.byKey(const ValueKey('trip-map-day-selector')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('trip-map-day-1')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-map-itinerary')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );

  await tester.tap(find.byKey(const ValueKey('trip-title-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('trip-picker-sheet')), findsOneWidget);
  await tester.tap(find.text('取消'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('settings-appearance')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
  await tester.pumpAndSettle();

  await tester.tap(_rootTab('聊天'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey('chat-input')),
    'device smoke draft',
  );
  expect(find.text('device smoke draft'), findsOneWidget);

  await tester.tap(_rootTab('行程'));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );

  await tester.tap(_rootTab('地圖'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);

  await tester.tap(_rootTab('收藏'));
  await tester.pumpAndSettle();
  expect(find.text('美麗海水族館'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('favorites-search-action')));
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey('favorites-search-input')),
    '牧志',
  );
  await tester.pump();
  expect(find.text('暖暮拉麵'), findsOneWidget);
  expect(find.text('美麗海水族館'), findsNothing);
  await tester.tap(find.byKey(const ValueKey('favorites-search-close')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('favorites-sort-action')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('favorites-sort-oldest')));
  await tester.pumpAndSettle();
  expect(find.text('美麗海水族館'), findsOneWidget);

  expect(tester.takeException(), isNull);
}
