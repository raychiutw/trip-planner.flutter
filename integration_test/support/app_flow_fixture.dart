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
import 'package:tripline/app/app_version.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
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
const releaseSmokeTokyoTrip = Trip(id: 'tokyo', name: 'tokyo', title: '東京週末旅行');

const releaseSmokeTrips = [
  TripSummary(
    tripId: 'okinawa',
    name: 'okinawa',
    title: '沖繩家族之旅',
    totalDays: 2,
    countries: 'JP',
  ),
  TripSummary(
    tripId: 'tokyo',
    name: 'tokyo',
    title: '東京週末旅行',
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

const releaseSmokeTokyoDays = [
  TripDay(
    id: 101,
    dayNum: 1,
    title: '抵達東京',
    version: 0,
    timeline: [
      TimelineEntry(
        id: 111,
        sortOrder: 0,
        version: 0,
        startTime: '10:00',
        endTime: '11:00',
        title: '東京車站',
      ),
    ],
  ),
  TripDay(
    id: 102,
    dayNum: 2,
    title: '淺草散策',
    version: 0,
    timeline: [
      TimelineEntry(
        id: 121,
        sortOrder: 0,
        version: 0,
        startTime: '09:00',
        endTime: '10:00',
        title: '淺草寺',
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

    when(
      () => apiClient.queueFlushRequests,
    ).thenAnswer((_) => const Stream<void>.empty());
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
      () => trips.fetchTrip('okinawa'),
    ).thenAnswer((_) async => releaseSmokeTrip);
    when(
      () => trips.watchDays('okinawa'),
    ).thenAnswer((_) => Stream.value(releaseSmokeDays));
    when(
      () => trips.fetchDaySummaries('okinawa'),
    ).thenAnswer((_) async => releaseSmokeDays);
    when(
      () => trips.watchNotes('okinawa'),
    ).thenAnswer((_) => Stream.value(const TripNotes()));
    when(
      () => trips.watchSegments(tripId: 'okinawa'),
    ).thenAnswer((_) => Stream.value(const <TripSegment>[]));
    when(
      () => trips.watchTrip('tokyo'),
    ).thenAnswer((_) => Stream.value(releaseSmokeTokyoTrip));
    when(
      () => trips.fetchTrip('tokyo'),
    ).thenAnswer((_) async => releaseSmokeTokyoTrip);
    when(
      () => trips.watchDays('tokyo'),
    ).thenAnswer((_) => Stream.value(releaseSmokeTokyoDays));
    when(
      () => trips.fetchDaySummaries('tokyo'),
    ).thenAnswer((_) async => releaseSmokeTokyoDays);
    when(
      () => trips.watchNotes('tokyo'),
    ).thenAnswer((_) => Stream.value(const TripNotes()));
    when(
      () => trips.watchSegments(tripId: 'tokyo'),
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
      appNetworkAvailabilityProvider.overrideWithValue(const Stream.empty()),
      appVersionProvider.overrideWith(
        (ref) async => const AppVersion(version: '0.9.1', buildNumber: '12'),
      ),
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
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('fake-google-poi-trigger'),
    behavior: HitTestBehavior.opaque,
    onTap: () => widget.config.onGooglePoiSelected?.call(
      const GoogleMapPoiSelection(
        placeId: 'ChIJ-release-fixture',
        name: '首里城公園',
        point: TripMapPoint(26.217, 127.719),
      ),
    ),
    child: ColoredBox(
      key: const ValueKey('fake-trip-map-canvas'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: const Center(child: Text('Google Map fixture')),
    ),
  );
}

Finder _rootTab(String label) {
  return find.byKey(ValueKey('root-tab-$label'));
}

typedef AppFlowCapture = Future<void> Function(String name);
typedef AppFlowAppWrapper = Widget Function(Widget child);
typedef AppFlowEnterText = Future<void> Function(Finder finder, String text);

Future<void> runAppOwnedReleaseFlow(
  WidgetTester tester, {
  AppFlowCapture? capture,
  AppFlowAppWrapper? appWrapper,
  AppFlowEnterText? enterText,
}) async {
  Future<void> captureState(String name) async {
    if (capture != null) await capture(name);
  }

  final typeText = enterText ?? tester.enterText;

  final fixture = AppFlowFixture.loggedOut();
  final app = fixture.app;
  await tester.pumpWidget(appWrapper?.call(app) ?? app);
  await tester.pumpAndSettle();

  expect(find.byType(WelcomeScreen), findsOneWidget);
  await captureState('welcome');
  await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
  await typeText(
    find.byKey(const ValueKey('login-email-field')),
    'ray@example.com',
  );
  await typeText(find.byKey(const ValueKey('login-password-field')), 'secret');
  await tester.tap(find.byKey(const ValueKey('login-submit-button')));
  await tester.pumpAndSettle();

  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .join(' | ');
  expect(
    () => verify(
      () => fixture.auth.login(email: 'ray@example.com', password: 'secret'),
    ).called(1),
    returnsNormally,
    reason: visibleText,
  );
  expect(find.byType(TripsListScreen), findsOneWidget, reason: visibleText);

  await tester.drag(
    find.byKey(const ValueKey('trip-dismiss-okinawa')),
    const Offset(-320, 0),
  );
  await tester.pumpAndSettle();
  expect(find.text('刪除'), findsOneWidget);
  expect(find.textContaining('此動作無法復原'), findsNothing);
  await tester.tap(find.text('刪除'));
  await tester.pumpAndSettle();
  expect(find.textContaining('此動作無法復原'), findsOneWidget);
  await captureState('destructive-confirm');
  await tester.tap(find.text('取消'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('沖繩家族之旅').first);
  await tester.pumpAndSettle();
  expect(find.text('那霸機場'), findsOneWidget);

  await tester.ensureVisible(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  expect(find.text('首里城'), findsOneWidget);
  await captureState('itinerary');

  await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-action-notes')));
  await tester.pumpAndSettle();
  expect(find.text('行程筆記'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-action-edit-info')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('edit-save')), findsOneWidget);
  await captureState('form');
  await tester.tap(find.byKey(const ValueKey('tp-app-bar-cancel')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('trip-timeline-map')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
  expect(find.byKey(const ValueKey('trip-map-day-selector')), findsOneWidget);
  expect(find.text('總覽'), findsOneWidget);
  expect(tester.widget<PageView>(find.byType(PageView)).pageSnapping, isFalse);
  await captureState('map-tripline-poi');
  await tester.tap(find.byKey(const ValueKey('fake-google-poi-trigger')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);
  await captureState('map-native-google-poi');
  await tester.tap(find.byKey(const ValueKey('google-poi-close')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('trip-map-day-1')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-map-day-1')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('trip-map-itinerary')));
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
  await captureState('trip-picker');
  await tester.tap(find.text('取消'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
  expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
  final accountScroll = find.descendant(
    of: find.byKey(const ValueKey('account-sheet-content')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('account-version-footer')),
    200,
    scrollable: accountScroll,
  );
  await tester.pumpAndSettle();
  expect(find.text('版本 0.9.1（12）'), findsOneWidget);
  await captureState('account');
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('settings-appearance')),
    -200,
    scrollable: accountScroll,
  );
  await tester.drag(accountScroll, const Offset(0, 160));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-appearance')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('tp-app-bar-back')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('app-large-sheet')), findsNothing);
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  expect(find.text('首里城'), findsOneWidget);

  await tester.tap(_rootTab('聊天'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
  await typeText(
    find.byKey(const ValueKey('chat-input')),
    'device smoke draft',
  );
  final chatInput = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const ValueKey('chat-input')),
      matching: find.byType(EditableText),
    ),
  );
  expect(find.text('device smoke draft'), findsOneWidget);
  expect(chatInput.focusNode.hasFocus, isTrue);
  await tester.tap(find.text('從一個指令開始'));
  await tester.pump();
  expect(chatInput.focusNode.hasFocus, isFalse);
  await tester.tap(find.byKey(const ValueKey('chat-trip-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-picker-item-tokyo')));
  await tester.pumpAndSettle();
  expect(find.text('東京週末旅行'), findsOneWidget);
  await captureState('chat');

  await tester.tap(_rootTab('行程'));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );
  expect(find.text('東京週末旅行'), findsOneWidget);
  expect(find.text('淺草寺'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('trip-timeline-trip-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-picker-item-okinawa')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );
  expect(find.text('沖繩家族之旅'), findsOneWidget);
  expect(find.text('首里城'), findsOneWidget);

  await tester.tap(_rootTab('聊天'));
  await tester.pumpAndSettle();
  expect(find.text('沖繩家族之旅'), findsOneWidget);
  expect(find.text('device smoke draft'), findsOneWidget);

  await tester.tap(_rootTab('地圖'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
  expect(find.byKey(const ValueKey('global-trip-map-okinawa')), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-picker-item-tokyo')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('global-trip-map-tokyo')), findsOneWidget);

  await tester.tap(_rootTab('行程'));
  await tester.pumpAndSettle();
  expect(find.text('東京週末旅行'), findsOneWidget);
  expect(find.text('淺草寺'), findsOneWidget);

  await tester.tap(_rootTab('聊天'));
  await tester.pumpAndSettle();
  expect(find.text('東京週末旅行'), findsOneWidget);
  expect(find.text('device smoke draft'), findsNothing);

  await tester.tap(_rootTab('收藏'));
  await tester.pumpAndSettle();
  expect(find.text('美麗海水族館'), findsOneWidget);
  await captureState('favorites');
  await typeText(find.byKey(const ValueKey('favorites-search-input')), '牧志');
  await tester.pump();
  expect(find.text('暖暮拉麵'), findsOneWidget);
  expect(find.text('美麗海水族館'), findsNothing);
  await typeText(find.byKey(const ValueKey('favorites-search-input')), '');
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('favorites-sort-action')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('favorites-sort-oldest')));
  await tester.pumpAndSettle();
  expect(find.text('美麗海水族館'), findsOneWidget);

  expect(tester.takeException(), isNull);
}
