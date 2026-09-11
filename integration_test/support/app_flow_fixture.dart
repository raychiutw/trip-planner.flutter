import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, defaultTargetPlatform, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/map_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/app/app_version.dart';
import 'package:tripline/features/account/settings/appearance_screen.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
import 'package:tripline/features/chat/speech_service.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/offline/offline_sync.dart';
import 'package:tripline/features/trips/collab/collab_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTripRepository extends Mock implements TripRepository {}

class MockCollabRepository extends Mock implements CollabRepository {}

class MockRequestsRepository extends Mock implements RequestsRepository {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

class MockMapRepository extends Mock implements MapRepository {}

class MockSpeechService extends Mock implements SpeechService {}

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
    totalDays: 1,
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
        master: EntryPoiInfo(
          poiId: 1001,
          name: '那霸機場',
          lat: 26.2065,
          lng: 127.6461,
          type: 'transport',
        ),
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
        master: EntryPoiInfo(
          poiId: 1002,
          name: '首里城',
          lat: 26.217,
          lng: 127.7195,
          type: 'attraction',
        ),
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
        master: EntryPoiInfo(
          poiId: 1101,
          name: '東京車站',
          lat: 35.6812,
          lng: 139.7671,
          type: 'transport',
        ),
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

/// 既有 release 流程的版本 footer 替身；真機視覺情境改讀平台的實際版本。
const releaseSmokeFixtureAppVersion = AppVersion(
  version: '0.9.1',
  buildNumber: '12',
);

class AppFlowFixture {
  AppFlowFixture._({
    required this.auth,
    required this.trips,
    required this.collab,
    required this.requests,
    required this.favorites,
    required this.map,
    required this.apiClient,
    required this.speech,
    required this.favoritesStream,
    required this.pendingCountStream,
    required this.mapCanvasBuilder,
    required this.fixedAppVersion,
    required this.initialThemeMode,
  });

  /// [mapCanvasBuilder] 預設是假地圖；真機視覺情境才傳 production canvas。
  /// [fixedAppVersion] 傳 null 時不覆寫 `appVersionProvider`，footer 顯示平台版本。
  /// [initialThemeMode] 走 main.dart 也在用的 `ThemeModeController(initialMode:)`；null 維持跟隨系統。
  factory AppFlowFixture.loggedOut({
    TripMapCanvasBuilder mapCanvasBuilder = fakeTripMapBuilder,
    AppVersion? fixedAppVersion = releaseSmokeFixtureAppVersion,
    ThemeMode? initialThemeMode,
  }) {
    final auth = MockAuthRepository();
    final trips = MockTripRepository();
    final collab = MockCollabRepository();
    final requests = MockRequestsRepository();
    final favorites = MockFavoritesRepository();
    final map = MockMapRepository();
    final apiClient = MockApiClient();
    final speech = MockSpeechService();
    final favoritesStream = StreamController<List<PoiFavorite>>.broadcast();
    final pendingCountStream = StreamController<int>.broadcast();

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
    when(() => collab.fetchMembers(any())).thenAnswer(
      (_) async => const [
        TripMember(
          id: 1,
          email: 'ray@example.com',
          displayName: 'Ray',
          role: 'owner',
          userId: 'u-1',
        ),
      ],
    );
    when(
      () => collab.fetchInvites(any()),
    ).thenAnswer((_) async => const <TripInvite>[]);

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
      () => requests.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer(
      (invocation) async => TripRequest(
        id: 901,
        tripId: invocation.namedArguments[#tripId]! as String,
        message: invocation.namedArguments[#message]! as String,
        status: RequestStatus.processing,
      ),
    );
    when(() => requests.fetchRequest(901)).thenAnswer(
      (_) async => const TripRequest(
        id: 901,
        tripId: 'okinawa',
        message: 'device smoke draft',
        reply: '收到',
        status: RequestStatus.completed,
      ),
    );
    when(() => speech.isAvailable).thenReturn(false);
    when(speech.init).thenAnswer((_) async => false);
    when(() => speech.listen(any())).thenAnswer((_) async {});
    when(speech.openSettings).thenAnswer((_) async => true);
    when(
      favorites.watchFavorites,
    ).thenAnswer((_) => Stream.value(releaseSmokeFavorites));

    return AppFlowFixture._(
      auth: auth,
      trips: trips,
      collab: collab,
      requests: requests,
      favorites: favorites,
      map: map,
      apiClient: apiClient,
      speech: speech,
      favoritesStream: favoritesStream,
      pendingCountStream: pendingCountStream,
      mapCanvasBuilder: mapCanvasBuilder,
      fixedAppVersion: fixedAppVersion,
      initialThemeMode: initialThemeMode,
    );
  }

  final MockAuthRepository auth;
  final MockTripRepository trips;
  final MockCollabRepository collab;
  final MockRequestsRepository requests;
  final MockFavoritesRepository favorites;
  final MockMapRepository map;
  final MockApiClient apiClient;
  final MockSpeechService speech;
  final StreamController<List<PoiFavorite>> favoritesStream;
  final StreamController<int> pendingCountStream;
  final TripMapCanvasBuilder mapCanvasBuilder;
  final AppVersion? fixedAppVersion;
  final ThemeMode? initialThemeMode;

  Future<void> dispose() async {
    await favoritesStream.close();
    await pendingCountStream.close();
  }

  Widget get app {
    final appVersion = fixedAppVersion;
    final themeMode = initialThemeMode;
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        authRepositoryProvider.overrideWithValue(auth),
        tripRepositoryProvider.overrideWithValue(trips),
        collabRepositoryProvider.overrideWithValue(collab),
        requestsRepositoryProvider.overrideWithValue(requests),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        favoritesProvider.overrideWith((ref) => favoritesStream.stream),
        offlinePendingCountProvider.overrideWith(
          (ref) => pendingCountStream.stream,
        ),
        mapRepositoryProvider.overrideWithValue(map),
        speechServiceProvider.overrideWithValue(speech),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        tripMapCanvasBuilderProvider.overrideWithValue(mapCanvasBuilder),
        appNetworkAvailabilityProvider.overrideWithValue(const Stream.empty()),
        if (appVersion != null)
          appVersionProvider.overrideWith((ref) async => appVersion),
        if (themeMode != null)
          themeModeProvider.overrideWith(
            () => ThemeModeController(initialMode: themeMode),
          ),
      ],
      child: const TriplineApp(),
    );
  }
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
  if (find
      .byKey(const ValueKey('apple-regular-root-tabs'))
      .evaluate()
      .isNotEmpty) {
    return find.byKey(ValueKey('regular-root-tab-$label'));
  }
  return find.byKey(ValueKey('root-tab-$label'));
}

typedef AppFlowCapture = Future<void> Function(String name);
typedef AppFlowAppWrapper = Widget Function(Widget child);
typedef AppFlowEnterText = Future<void> Function(Finder finder, String text);
typedef AppFlowKeyboardVisibility = Future<void> Function(bool visible);

Future<void> runAppOwnedReleaseFlow(
  WidgetTester tester, {
  AppFlowCapture? capture,
  AppFlowAppWrapper? appWrapper,
  AppFlowEnterText? enterText,
  AppFlowKeyboardVisibility? setKeyboardVisible,
}) async {
  Future<void> captureState(String name) async {
    if (capture != null) await capture(name);
  }

  final typeText = enterText ?? tester.enterText;

  final fixture = AppFlowFixture.loggedOut();
  addTearDown(fixture.dispose);
  final app = fixture.app;
  await tester.pumpWidget(appWrapper?.call(app) ?? app);
  await tester.pumpAndSettle();

  await _signInFromWelcome(
    tester,
    fixture,
    typeText: typeText,
    captureState: captureState,
  );
  await captureState('trips');

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

  // 行程與地圖之間改由 root tab 進出（兩顆重複的 bar button 已移除）。
  await tester.tapAt(tester.getCenter(_rootTab('地圖')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
  expect(find.byKey(const ValueKey('trip-map-day-selector')), findsOneWidget);
  expect(find.text('全部'), findsOneWidget);
  expect(tester.widget<PageView>(find.byType(PageView)).pageSnapping, isFalse);
  await captureState('map-tripline-poi');
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey('fake-google-poi-trigger')),
      )
      .onTap!();
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);
  await captureState('map-native-google-poi');
  await tester.tap(find.byKey(const ValueKey('google-poi-close')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('trip-map-day-1')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-map-day-1')));
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getCenter(_rootTab('行程')));
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
  final appearanceRow = find.byKey(const ValueKey('settings-appearance'));
  await tester.scrollUntilVisible(
    appearanceRow,
    -200,
    scrollable: accountScroll,
  );
  await tester.pumpAndSettle();
  await tester.tap(appearanceRow);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('appearance-page')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('theme-dark')));
  await tester.pumpAndSettle();
  expect(
    Theme.of(
      tester.element(find.byKey(const ValueKey('appearance-page'))),
    ).brightness,
    Brightness.dark,
  );
  await tester.tap(find.byKey(const ValueKey('theme-system')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
  await tester.pumpAndSettle();
  expect(find.text('跟隨系統'), findsOneWidget);
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

  await tester.tapAt(tester.getCenter(_rootTab('聊天')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
  await typeText(
    find.byKey(const ValueKey('chat-input')),
    'device smoke draft',
  );
  await tester.pump();
  final chatInput = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const ValueKey('chat-input')),
      matching: find.byType(EditableText),
    ),
  );
  expect(find.text('device smoke draft'), findsOneWidget);
  expect(chatInput.focusNode.hasFocus, isTrue);
  expect(find.byKey(const ValueKey('chat-send')), findsOneWidget);
  expect(find.byKey(const ValueKey('chat-mic-button')), findsNothing);
  if (setKeyboardVisible != null) {
    final rootNavigationKey =
        find
            .byKey(const ValueKey('apple-regular-root-tabs'))
            .evaluate()
            .isNotEmpty
        ? const ValueKey('apple-regular-root-tabs')
        : const ValueKey('apple-root-tab-bar');
    await setKeyboardVisible(true);
    expect(find.byKey(rootNavigationKey), findsNothing);
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('chat-composer-glass')))
          .dy,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
            tester.view.viewInsets.bottom +
            1,
      ),
    );
    await setKeyboardVisible(false);
    expect(find.byKey(rootNavigationKey), findsOneWidget);
  }

  await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
  await tester.pumpAndSettle();
  expect(find.text('device smoke draft'), findsOneWidget);

  await tester.tap(find.text('從一個指令開始'));
  await tester.pump();
  expect(chatInput.focusNode.hasFocus, isFalse);
  await tester.tap(find.byKey(const ValueKey('chat-trip-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-picker-item-tokyo')));
  await tester.pumpAndSettle();
  expect(find.text('東京週末旅行'), findsWidgets);
  expect(find.byKey(const ValueKey('chat-mic-button')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('chat-mic-button')));
  await tester.pumpAndSettle();
  expect(find.text('使用語音輸入？'), findsOneWidget);
  await tester.tap(find.text('繼續'));
  await tester.pumpAndSettle();
  expect(find.text('無法使用語音輸入'), findsOneWidget);
  await tester.tap(find.text('稍後再說'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('chat-mic-button')));
  await tester.pumpAndSettle();
  expect(find.text('使用語音輸入？'), findsNothing);
  expect(find.text('無法使用語音輸入'), findsOneWidget);
  await tester.tap(find.text('稍後再說'));
  await tester.pumpAndSettle();
  verify(fixture.speech.init).called(1);
  verifyNever(() => fixture.speech.listen(any()));
  await captureState('chat');

  await tester.tapAt(tester.getCenter(_rootTab('行程')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );
  expect(find.text('東京週末旅行'), findsWidgets);
  expect(find.byKey(const ValueKey('day-pill-1')), findsOneWidget);
  expect(find.text('東京車站'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('trip-timeline-trip-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-picker-item-okinawa')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );
  expect(find.text('沖繩家族之旅'), findsWidgets);
  await tester.ensureVisible(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  // release build 的 RenderObject.debugSemantics 永遠是 null，tester.getSemantics
  // 會丟 No Semantics data found；改從公開語意樹以可及性名稱讀 selected。
  final selectedDayPill = find.semantics.byLabel('第 2 天，共 2 天');
  expect(selectedDayPill, findsOne);
  expect(
    selectedDayPill
        .evaluate()
        .single
        .getSemanticsData()
        .flagsCollection
        .isSelected,
    Tristate.isTrue,
  );

  await tester.tapAt(tester.getCenter(_rootTab('聊天')));
  await tester.pumpAndSettle();
  expect(find.text('沖繩家族之旅'), findsWidgets);
  expect(find.text('device smoke draft'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('chat-send')));
  await tester.pumpAndSettle();
  verify(
    () => fixture.requests.sendRequest(
      tripId: 'okinawa',
      message: 'device smoke draft',
    ),
  ).called(1);
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('chat-input')))
        .controller!
        .text,
    isEmpty,
  );

  await tester.tapAt(tester.getCenter(_rootTab('地圖')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
  expect(find.byKey(const ValueKey('global-trip-map-okinawa')), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-picker-item-tokyo')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('global-trip-map-tokyo')), findsOneWidget);

  await tester.tapAt(tester.getCenter(_rootTab('行程')));
  await tester.pumpAndSettle();
  expect(find.text('東京週末旅行'), findsWidgets);
  expect(find.byKey(const ValueKey('day-pill-1')), findsOneWidget);
  expect(find.text('東京車站'), findsOneWidget);

  await tester.tapAt(tester.getCenter(_rootTab('聊天')));
  await tester.pumpAndSettle();
  expect(find.text('東京週末旅行'), findsWidgets);
  expect(find.text('device smoke draft'), findsNothing);

  await tester.tapAt(tester.getCenter(_rootTab('收藏')));
  await tester.pump();
  fixture.favoritesStream.add(releaseSmokeFavorites);
  await tester.pumpAndSettle();
  expect(find.text('美麗海水族館'), findsOneWidget);
  await captureState('favorites');
  await typeText(find.byKey(const ValueKey('favorites-search-input')), '牧志');
  await tester.pump();
  expect(find.text('暖暮拉麵'), findsOneWidget);
  expect(find.text('美麗海水族館'), findsNothing);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  await tester.tapAt(tester.getCenter(_rootTab('聊天')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('從一個指令開始'));
  await tester.pump();
  await tester.tapAt(tester.getCenter(_rootTab('收藏')));
  await tester.pumpAndSettle();
  final favoritesSearch = find.byKey(const ValueKey('favorites-search-input'));
  expect(
    tester
        .widget<EditableText>(
          find.descendant(
            of: favoritesSearch,
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text,
    '牧志',
  );
  expect(find.text('暖暮拉麵'), findsOneWidget);

  await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<EditableText>(
          find.descendant(
            of: favoritesSearch,
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text,
    isEmpty,
  );
  expect(find.text('美麗海水族館'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('favorites-sort-action')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('favorites-sort-oldest')));
  await tester.pumpAndSettle();
  expect(find.text('美麗海水族館'), findsOneWidget);

  fixture.pendingCountStream.add(1);
  await tester.pumpAndSettle();
  expect(find.text('1 筆變更待同步'), findsOneWidget);
  expect(_rootTab('收藏'), findsOneWidget);
  await captureState('offline');

  fixture.pendingCountStream.add(0);
  fixture.favoritesStream.addError(StateError('release fixture error'));
  await tester.pumpAndSettle();
  expect(find.text('載入失敗'), findsOneWidget);
  expect(find.text('無法取得收藏清單，請檢查網路後再試一次。'), findsOneWidget);
  expect(_rootTab('收藏'), findsOneWidget);
  await captureState('error');

  await tester.tap(find.text('重試'));
  await tester.pump();
  fixture.favoritesStream.add(releaseSmokeFavorites);
  await tester.pumpAndSettle();
  expect(find.text('美麗海水族館'), findsOneWidget);

  expect(tester.takeException(), isNull);
}

/// 兩條流程共用的登入段：從 welcome 進 login、送出、確認進到行程列表。
Future<void> _signInFromWelcome(
  WidgetTester tester,
  AppFlowFixture fixture, {
  required AppFlowEnterText typeText,
  required Future<void> Function(String name) captureState,
}) async {
  expect(find.byType(WelcomeScreen), findsOneWidget);
  await captureState('welcome');
  await tester.ensureVisible(find.byKey(const ValueKey('welcome-login-hero')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
  await captureState('login');
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
}

typedef AppFlowEvidenceLog = void Function(String line);

/// 包住 [canvas]（真機 production、host 假地圖），以 controller 身分記住哪張
/// canvas 真的回報過 onMapReady；production 只在 view 建立時回報一次。
class TripMapCanvasEvidence {
  TripMapCanvasEvidence({required TripMapCanvasBuilder canvas})
    : _canvas = canvas;

  final TripMapCanvasBuilder _canvas;
  final _readyControllers = <TripMapController>{};
  int _readyCount = 0;

  /// 真實 onMapReady 回呼次數；只有 canvas 重新建立才會再加一。
  int get readyCount => _readyCount;

  /// 目前畫面上那張 canvas 是否已收過真正的 onMapReady；同時只允許一張在畫面上。
  bool isCurrentCanvasReady(WidgetTester tester) {
    final host = tester
        .widget<_TripMapCanvasEvidenceHost>(
          find.byType(_TripMapCanvasEvidenceHost),
        )
        .controller;
    return _readyControllers.contains(host);
  }

  // TripMapCanvasConfig 沒有 copyWith；新增欄位時要一併轉交。
  Widget build(TripMapCanvasConfig config) => _TripMapCanvasEvidenceHost(
    controller: config.controller,
    child: _canvas(
      TripMapCanvasConfig(
        controller: config.controller,
        tilePreset: config.tilePreset,
        initialFitPoints: config.initialFitPoints,
        initialCenter: config.initialCenter,
        initialZoom: config.initialZoom,
        initialPadding: config.initialPadding,
        initialMaxZoom: config.initialMaxZoom,
        routes: config.routes,
        markers: config.markers,
        clusterMarkers: config.clusterMarkers,
        onMapReady: () {
          _readyCount += 1;
          _readyControllers.add(config.controller);
          config.onMapReady?.call();
        },
        onCameraIdle: config.onCameraIdle,
        onMapStyleApplied: config.onMapStyleApplied,
        onTap: config.onTap,
        onGooglePoiSelected: config.onGooglePoiSelected,
        mapKey: config.mapKey,
      ),
    ),
  );
}

/// 只標記畫面上這張 canvas 的 controller 身分，不改版面。
class _TripMapCanvasEvidenceHost extends StatelessWidget {
  const _TripMapCanvasEvidenceHost({
    required this.controller,
    required this.child,
  });

  final TripMapController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// 真機視覺證據流程：走過 production chrome 與真實地圖背景，每個情境記錄外觀
/// 與注入的無障礙設定；API／認證／聊天／收藏仍是替身。
Future<void> runAppOwnedVisualEvidenceFlow(
  WidgetTester tester, {
  required TripMapCanvasEvidence mapEvidence,
  required AppFlowEnterText enterText,
  AppFlowCapture? capture,
  AppFlowAppWrapper? appWrapper,
  AppFlowEvidenceLog? log,
  Duration dwell = const Duration(milliseconds: 1200),
}) async {
  Future<void> captureState(String name) async {
    if (capture != null) await capture(name);
  }

  final writeLog = log ?? debugPrint;
  final injection = ValueNotifier(_InjectedAccessibility.none);
  addTearDown(injection.dispose);

  /// 每個情境先讓畫面靜止、記錄 App 實際觀察到的外觀與無障礙值，再停留給錄影。
  /// 明暗只走 App 自己的外觀設定，log 讀的是 themeModeProvider 的實際狀態。
  Future<void> scene(String name) async {
    await tester.pumpAndSettle();
    final appContext = tester.element(find.byType(Navigator).first);
    final appearanceSetting = themeModeLabel(
      ProviderScope.containerOf(appContext).read(themeModeProvider),
    );
    writeLog(
      'Tripline visual evidence | scene=$name'
      ' | appearance=${Theme.of(appContext).brightness.name}'
      ' | App 外觀=$appearanceSetting'
      ' | observed reduceMotion=${MediaQuery.disableAnimationsOf(appContext)}'
      ' increasedContrast=${MediaQuery.highContrastOf(appContext)}'
      ' reduceTransparency='
      '${AppAccessibilityScope.reduceTransparencyOf(appContext)}'
      ' | injected accessibility=${injection.value.label}'
      ' (test wrapper, not OS settings; OS bridge/VoiceOver not covered)'
      ' | dwell=${dwell.inMilliseconds}ms',
    );
    await captureState(name);
    await tester.pump(dwell);
  }

  /// 切換注入值後確認 App 真的觀察到它，避免情境名稱與畫面不符。
  Future<void> inject(_InjectedAccessibility injected) async {
    injection.value = injected;
    await tester.pumpAndSettle();
    final appContext = tester.element(find.byType(Navigator).first);
    expect(MediaQuery.disableAnimationsOf(appContext), injected.reduceMotion);
    expect(MediaQuery.highContrastOf(appContext), injected.increasedContrast);
    expect(
      AppAccessibilityScope.reduceTransparencyOf(appContext),
      injected.reduceTransparency,
    );
  }

  /// 行程卡「⋯」開錨定玻璃選單、停留、外點關閉且不觸發卡片導航。
  Future<void> tripCardMenuScene(String name) async {
    await tester.tap(find.byKey(const ValueKey('trip-card-more-okinawa')));
    await tester.pumpAndSettle();
    _expectTripCardMenu(present: true);
    await scene(name);
    await tester.tapAt(_outsideMenuPoint(tester));
    await tester.pumpAndSettle();
    _expectTripCardMenu(present: false);
    expect(find.byType(TripsListScreen), findsOneWidget);
  }

  /// 帳號面板進場、停留、關閉回到原頁。
  Future<void> accountSheetScene(String name) async {
    await _openAccountSheet(tester);
    await scene(name);
    await _closeAccountSheet(tester);
  }

  // 淺色情境不依賴 Test Lab 裝置的系統外觀：啟動就明確選 App 淺色，深色稍後走帳號 UI。
  final fixture = AppFlowFixture.loggedOut(
    mapCanvasBuilder: mapEvidence.build,
    fixedAppVersion: null,
    initialThemeMode: ThemeMode.light,
  );
  addTearDown(fixture.dispose);
  final app = _InjectedAccessibilityScope(
    injection: injection,
    child: fixture.app,
  );
  writeLog(
    'Tripline visual evidence | start'
    ' | releaseMode=$kReleaseMode | platform=${defaultTargetPlatform.name}'
    ' | API/認證/聊天/收藏=mock，地圖 canvas 由呼叫端決定'
    ' | dwell=${dwell.inMilliseconds}ms',
  );
  await tester.pumpWidget(appWrapper?.call(app) ?? app);
  await tester.pumpAndSettle();

  await _signInFromWelcome(
    tester,
    fixture,
    typeText: enterText,
    captureState: (_) async {},
  );
  await scene('light/trips-list');

  // 行程卡「⋯」與長按開同一份錨定玻璃選單；選「共編」只推一個 route（一次 callback）。
  await tripCardMenuScene('light/trip-card-menu');
  await tester.longPress(find.text('沖繩家族之旅').first);
  await tester.pumpAndSettle();
  _expectTripCardMenu(present: true);
  await scene('light/trip-card-long-press-menu');
  await tester.tap(find.byKey(const ValueKey('trip-menu-collab-okinawa')));
  await tester.pumpAndSettle();
  _expectTripCardMenu(present: false);
  expect(find.byType(CollabScreen, skipOffstage: false), findsOneWidget);
  await scene('light/collab-from-trip-card-menu');
  await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
  await tester.pumpAndSettle();
  expect(find.byType(CollabScreen, skipOffstage: false), findsNothing);
  expect(find.byType(TripsListScreen), findsOneWidget);

  // 帳號面板蓋在文字列表上；footer 是平台回報的版本，供 root 對照 build metadata。
  await _openAccountSheet(tester);
  await scene('light/account-sheet');
  final footer = find.byKey(const ValueKey('account-version-footer'));
  await tester.scrollUntilVisible(
    footer,
    200,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('account-sheet-content')),
      matching: find.byType(Scrollable),
    ),
  );
  await _pumpUntil(
    tester,
    () => tester.widget<Text>(footer).data != '版本 …',
    reason: 'appVersionProvider 尚未回報平台版本',
  );
  writeLog(
    'Tripline visual evidence | build identity (account footer, '
    'appVersionProvider → PackageInfo.fromPlatform；fixture 替身已停用) = '
    '${tester.widget<Text>(footer).data}',
  );
  await _closeAccountSheet(tester);
  expect(find.byType(TripsListScreen), findsOneWidget);

  // 時間軸選 Day 2 → 帳號開關 → 仍停在同一行程同一天（公開語意樹讀選取態）。
  await tester.tap(find.text('沖繩家族之旅').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  expect(find.text('首里城'), findsOneWidget);
  await scene('light/timeline-day-2');
  await _openAccountSheet(tester);
  await _closeAccountSheet(tester);
  expect(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    findsOneWidget,
  );
  _expectSelectedDaySemantics('第 2 天，共 2 天');
  expect(find.text('首里城'), findsOneWidget);
  await scene('light/timeline-after-account-close');

  // 時間軸 header 既有的玻璃選單（文字列表上）。
  await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('trip-action-notes')), findsOneWidget);
  await scene('light/timeline-header-menu');
  await tester.tapAt(_outsideMenuPoint(tester));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('trip-action-notes')), findsNothing);

  // 真實地圖背景：等 canvas 真正回報 onMapReady 後才讓 chrome 停留。
  await _openMapTab(tester, mapEvidence);
  writeLog(
    'Tripline visual evidence | map ready count=${mapEvidence.readyCount}',
  );
  await scene('light/map');
  await tester.tap(find.byKey(const ValueKey('trip-map-day-1')));
  await tester.pumpAndSettle();
  _expectSelectedDaySemantics('第 1 天，共 2 天');
  await scene('light/map-day-1');
  await accountSheetScene('light/map-account-sheet');
  _expectSelectedDaySemantics('第 1 天，共 2 天');
  await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('trip-picker-sheet')), findsOneWidget);
  await scene('light/map-trip-picker');
  await tester.tap(find.text('取消'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('trip-picker-sheet')), findsNothing);

  // 聊天 composer：沒有「＋」入口，空白時麥克風、有字時送出；草稿跨帳號開關保留。
  await tester.tapAt(tester.getCenter(_rootTab('聊天')));
  await tester.pumpAndSettle();
  final composer = find.byKey(const ValueKey('chat-composer-glass'));
  expect(composer, findsOneWidget);
  expect(find.byKey(const ValueKey('chat-mic-button')), findsOneWidget);
  expect(find.byKey(const ValueKey('chat-add-button')), findsNothing);
  expect(
    find.descendant(of: composer, matching: find.byIcon(CupertinoIcons.add)),
    findsNothing,
  );
  await scene('light/chat-composer');
  await enterText(
    find.byKey(const ValueKey('chat-input')),
    'visual evidence draft',
  );
  await tester.pump();
  expect(find.byKey(const ValueKey('chat-send')), findsOneWidget);
  expect(find.byKey(const ValueKey('chat-mic-button')), findsNothing);
  await scene('light/chat-composer-draft');
  await _openAccountSheet(tester);
  await _closeAccountSheet(tester);
  expect(find.text('visual evidence draft'), findsOneWidget);
  await scene('light/chat-draft-after-account-close');
  // 真機鍵盤還開著會藏起 root tab bar；收鍵盤只 unfocus，草稿仍在。
  await tester.tap(find.text('從一個指令開始'));
  await tester.pumpAndSettle();
  expect(find.text('visual evidence draft'), findsOneWidget);

  /// 文字列表上的行程卡選單 ＋ 真實地圖，是每個材質情境都要比對的兩種背景；
  /// 降低動態效果另看帳號面板的進場。
  Future<void> menuAndMapScenes(
    String prefix, {
    bool withAccountSheet = false,
  }) async {
    await _openTripsList(tester);
    await tripCardMenuScene('$prefix/trip-card-menu');
    if (withAccountSheet) await accountSheetScene('$prefix/account-sheet');
    await _openMapTab(tester, mapEvidence);
    await scene('$prefix/map');
  }

  /// 三個注入的無障礙設定各自獨立，明暗兩種外觀都要各走一遍。
  Future<void> injectedScenes(String appearance) async {
    for (final injected in const [
      _InjectedAccessibility(increasedContrast: true),
      _InjectedAccessibility(reduceTransparency: true),
      _InjectedAccessibility(reduceMotion: true),
    ]) {
      await inject(injected);
      await menuAndMapScenes(
        '$appearance+${injected.sceneSuffix}',
        withAccountSheet: injected.reduceMotion,
      );
    }
    await inject(_InjectedAccessibility.none);
  }

  await injectedScenes('light');

  // 深色走 App 外觀設定（帳號 → 外觀），再走一遍列表／選單／帳號／地圖／composer。
  await _setAppAppearance(tester, mode: ThemeMode.dark);
  await _openTripsList(tester);
  await scene('dark/trips-list');
  await tripCardMenuScene('dark/trip-card-menu');
  await accountSheetScene('dark/account-sheet');
  await _openMapTab(tester, mapEvidence);
  await scene('dark/map');
  await tester.tapAt(tester.getCenter(_rootTab('聊天')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('chat-composer-glass')), findsOneWidget);
  expect(find.text('visual evidence draft'), findsOneWidget);
  await scene('dark/chat-composer');

  await injectedScenes('dark');

  expect(tester.takeException(), isNull);
}

/// 回到行程列表：行程 branch 保留著時間軸時先按返回。
Future<void> _openTripsList(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(_rootTab('行程')));
  await tester.pumpAndSettle();
  final timelineBack = find.byKey(const ValueKey('trip-timeline-back'));
  if (timelineBack.evaluate().isNotEmpty) {
    await tester.tap(timelineBack);
    await tester.pumpAndSettle();
  }
  expect(find.byType(TripsListScreen), findsOneWidget);
}

/// 走 App 自己的外觀設定（帳號 → 外觀）切換明暗，不動系統設定。
Future<void> _setAppAppearance(
  WidgetTester tester, {
  required ThemeMode mode,
}) async {
  await _openAccountSheet(tester);
  final appearanceRow = find.byKey(const ValueKey('settings-appearance'));
  await tester.scrollUntilVisible(
    appearanceRow,
    100,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('account-sheet-content')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(appearanceRow);
  await tester.pumpAndSettle();
  final page = find.byKey(const ValueKey('appearance-page'));
  expect(page, findsOneWidget);
  await tester.tap(find.byKey(ValueKey('theme-${mode.name}')));
  await tester.pumpAndSettle();
  expect(
    Theme.of(tester.element(page)).brightness,
    mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
  );
  await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
  await tester.pumpAndSettle();
  await _closeAccountSheet(tester);
}

/// 真機視覺情境注入的無障礙值。這不是 OS 設定：Reduce Motion／Increase Contrast
/// 走 MediaQuery，Reduce Transparency 走 `AppAccessibilityScope` 的注入入口。
class _InjectedAccessibility {
  const _InjectedAccessibility({
    this.reduceMotion = false,
    this.increasedContrast = false,
    this.reduceTransparency = false,
  });

  static const none = _InjectedAccessibility();

  final bool reduceMotion;
  final bool increasedContrast;
  final bool reduceTransparency;

  String get label {
    final enabled = [
      if (reduceMotion) 'reduceMotion',
      if (increasedContrast) 'increasedContrast',
      if (reduceTransparency) 'reduceTransparency',
    ];
    return enabled.isEmpty ? 'none' : enabled.join('+');
  }

  /// 情境名稱用的 kebab-case 片段。
  String get sceneSuffix => [
    if (reduceMotion) 'reduce-motion',
    if (increasedContrast) 'increased-contrast',
    if (reduceTransparency) 'reduce-transparency',
  ].join('+');
}

/// 等同 lib/main.dart 的 `_triplineGlassTheme`：光暈主色換成品牌 tint，
/// 以 AppTheme 的 `colorScheme.primary` 取同一個 token。
GlassThemeData productionEquivalentGlassTheme() => GlassThemeData(
  light: GlassThemeVariant.light.copyWith(
    glowColors: GlassGlowColors(primary: AppTheme.light().colorScheme.primary),
  ),
  dark: GlassThemeVariant.dark.copyWith(
    glowColors: GlassGlowColors(primary: AppTheme.dark().colorScheme.primary),
  ),
);

class _InjectedAccessibilityScope extends StatelessWidget {
  const _InjectedAccessibilityScope({
    required this.injection,
    required this.child,
  });

  final ValueListenable<_InjectedAccessibility> injection;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: injection,
    builder: (context, injected, _) => AppAccessibilityScope(
      reduceTransparency: injected.reduceTransparency,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: injected.reduceMotion,
          highContrast: injected.increasedContrast,
        ),
        child: child,
      ),
    ),
  );
}

/// 切到地圖 tab，等畫面上這張 canvas 真的回報過 onMapReady，再確認 chrome 齊全。
/// 首次進入一定等真正的回呼；回到保留中的同一張地圖則直接通過。
Future<void> _openMapTab(
  WidgetTester tester,
  TripMapCanvasEvidence mapEvidence,
) async {
  await tester.tapAt(tester.getCenter(_rootTab('地圖')));
  await tester.pumpAndSettle();
  await _pumpUntil(
    tester,
    () => mapEvidence.isCurrentCanvasReady(tester),
    reason: '畫面上的地圖 canvas 沒有回報 onMapReady',
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('global-trip-map-okinawa')), findsOneWidget);
  expect(find.byKey(const ValueKey('trip-map-trip-picker')), findsOneWidget);
  expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
  expect(find.byKey(const ValueKey('trip-map-day-selector')), findsOneWidget);
  expect(find.byKey(const ValueKey('tripline-poi-accessory')), findsOneWidget);
  expect(find.byKey(const ValueKey('trip-map-locate-button')), findsOneWidget);
  expect(_rootTab('地圖'), findsOneWidget);
}

Future<void> _openAccountSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
}

Future<void> _closeAccountSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('app-large-sheet')), findsNothing);
}

/// release 版 `getSemantics` 讀不到 debugSemantics，選取態一律走公開語意樹。
void _expectSelectedDaySemantics(String label) {
  final day = find.semantics.byLabel(label);
  expect(day, findsOne);
  expect(day.evaluate().single.flagsCollection.isSelected, Tristate.isTrue);
}

/// 以 100ms 為步進等待條件成立；host 走假時間、真機走實際時間。
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  const step = Duration(milliseconds: 100);
  var waited = Duration.zero;
  while (!condition()) {
    if (waited >= timeout) fail('$reason（等待 ${timeout.inSeconds}s）');
    await tester.pump(step);
    waited += step;
  }
}

void _expectTripCardMenu({required bool present}) {
  for (final action in ['share', 'collab', 'health', 'export', 'delete']) {
    expect(
      find.byKey(ValueKey('trip-menu-$action-okinawa')),
      present ? findsOneWidget : findsNothing,
      reason: action,
    );
  }
}

/// 選單面板與螢幕邊緣至少留 8pt，所以左緣 8pt 內一定是選單外。
Offset _outsideMenuPoint(WidgetTester tester) => Offset(
  4,
  tester.view.physicalSize.height / tester.view.devicePixelRatio / 2,
);
