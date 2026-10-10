/// HIG 修補（#415–#430）的截圖情境：每個情境用 fixture／provider override 灌資料，
/// 淺色與深色都走 App 自己的 `themeModeProvider`（`ThemeModeController(initialMode:)`），
/// 不依賴 `simctl ui appearance`。全部走 mock repository，不碰 prod。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart' show AccountDeletionPreview;
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/cache/cache_store.dart' show QueuedMutation;
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/api/share_repository.dart';
import 'package:tripline/app/app_version.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/offline/offline_sync.dart';
import 'package:tripline/features/chat/speech_service.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/models/share.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/trip_share.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_chip.dart';
import 'package:tripline/ui/tp_picker_field.dart';
import 'package:tripline/ui/tp_segmented_control.dart';

import 'app_flow_fixture.dart';

class MockAccountRepository extends Mock implements AccountRepository {}

class MockShareRepository extends Mock implements ShareRepository {}

class MockPoiRepository extends Mock implements PoiRepository {}

const higUser = UserInfo(
  id: 'u-1',
  email: 'ray@example.com',
  displayName: 'Ray',
  emailVerified: true,
);

/// 一個情境用的全部 fake（每個情境、每種明暗都重建，避免狀態外洩）。
class HigFakes {
  HigFakes._(this.fixture, this.account, this.share, this.poi);

  final AppFlowFixture fixture;
  final MockAccountRepository account;
  final MockShareRepository share;
  final MockPoiRepository poi;

  /// 預設 offline 假訊號；情境可改成 false 觸發「目前離線」橫幅。
  Stream<bool> network = const Stream<bool>.empty();

  MockAuthRepositoryAlias get auth => fixture.auth;
  MockTripRepository get trips => fixture.trips;
  MockMapRepository get map => fixture.map;
  MockRequestsRepository get requests => fixture.requests;
  StreamController<List<PoiFavorite>> get favoritesStream =>
      fixture.favoritesStream;

  factory HigFakes.create({required ThemeMode mode, required bool loggedIn}) {
    final fixture = AppFlowFixture.loggedOut(initialThemeMode: mode);
    final account = MockAccountRepository();
    final share = MockShareRepository();
    final poi = MockPoiRepository();
    when(fixture.auth.logout).thenAnswer((_) async {});
    when(fixture.auth.fetchAccountDeletionPreview).thenAnswer(
      (_) async => const AccountDeletionPreview(
        hasPassword: true,
        tripsOwned: 2,
        collaboratorsAffected: 3,
      ),
    );
    if (loggedIn) {
      when(fixture.auth.currentUser).thenAnswer((_) async => higUser);
    }
    when(() => account.fetchAccountSessions()).thenAnswer(
      (_) async => AccountSessionsPage.fromJson({
        'current_sid': 's1',
        'sessions': [
          {
            'sid': 's1',
            'ua_summary': 'Tripline iOS · iPhone',
            'ip_hash_prefix': 'a1b2c3',
            'created_at': '2026-10-01T08:00:00Z',
            'last_seen_at': '2026-10-10T08:00:00Z',
            'is_current': true,
          },
          {
            'sid': 's2',
            'ua_summary': 'Safari · macOS',
            'ip_hash_prefix': 'd4e5f6',
            'created_at': '2026-09-20T08:00:00Z',
            'last_seen_at': '2026-10-08T08:00:00Z',
            'is_current': false,
          },
        ],
      }),
    );
    when(() => account.fetchConnectedApps()).thenAnswer(
      (_) async => [
        ConnectedApp.fromJson({
          'client_id': 'c1',
          'app_name': '行程助理',
          'app_description': '把行程同步到月曆',
          'status': 'active',
          'scopes': ['trips:read', 'trips:write'],
          'granted_at': 1760000000000,
        }),
      ],
    );
    when(() => account.fetchDeveloperApps()).thenAnswer(
      (_) async => [
        DeveloperApp.fromJson({
          'client_id': 'dev1',
          'client_type': 'confidential',
          'app_name': '我的小工具',
          'redirect_uris': ['https://example.com/cb'],
          'allowed_scopes': ['trips:read'],
          'status': 'active',
          'created_at': '2026-09-01T00:00:00Z',
          'updated_at': '2026-09-02T00:00:00Z',
        }),
      ],
    );
    when(() => account.fetchDeveloperApp('dev1')).thenAnswer(
      (_) async => DeveloperApp.fromJson({
        'client_id': 'dev1',
        'client_type': 'confidential',
        'app_name': '我的小工具',
        'redirect_uris': ['https://example.com/cb'],
        'allowed_scopes': ['trips:read'],
        'status': 'active',
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-02T00:00:00Z',
      }),
    );
    when(
      () => account.fetchAccountNotificationPreferences(),
    ).thenAnswer((_) async => AccountNotificationPreferences.fromJson({}));
    when(() => share.fetchShares(any())).thenAnswer((_) async => const []);
    when(
      () => share.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        expiresAt: any(named: 'expiresAt'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async => const ShareLink(
        id: 11,
        token: 'demo-token-0123456789',
        url: '/s/demo-token-0123456789',
        label: '給家人',
      ),
    );
    when(
      () => poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => [
        PoiSearchResult.fromJson({
          'place_id': 'p1',
          'name': '淺草寺',
          'address': '東京都台東區淺草 2-3-1',
          'category': 'attraction',
          'rating': 4.5,
          'lat': 35.71,
          'lng': 139.79,
        }),
        PoiSearchResult.fromJson({
          'place_id': 'p2',
          'name': '一蘭拉麵 新宿中央東口店',
          'address': '東京都新宿區新宿 3-34-11',
          'category': 'restaurant',
          'rating': 4.2,
          'lat': 35.69,
          'lng': 139.70,
        }),
      ],
    );
    when(
      fixture.favorites.fetchFavorites,
    ).thenAnswer((_) async => releaseSmokeFavorites);
    when(() => fixture.collab.fetchInvitation(any())).thenAnswer(
      (_) async => const InvitationDetails(
        tripId: 'okinawa',
        tripTitle: '沖繩家族之旅',
        invitedEmail: 'ray@example.com',
        inviterDisplayName: 'Mia',
        inviterEmail: 'mia@example.com',
        expiresAt: '2026-11-01T00:00:00Z',
      ),
    );
    when(
      () => fixture.trips.fetchDays(any()),
    ).thenAnswer((_) async => releaseSmokeDays);
    when(
      () => fixture.trips.fetchNotes(any()),
    ).thenAnswer((_) async => higNotes);
    when(
      () => fixture.trips.fetchFreshNotes(any()),
    ).thenAnswer((_) async => higNotes);
    when(
      () => fixture.trips.watchNotes('okinawa'),
    ).thenAnswer((_) => Stream.value(higNotes));
    when(
      () => fixture.trips.fetchPublicTripShare(any()),
    ).thenAnswer((_) async => higPublicShare);
    return HigFakes._(fixture, account, share, poi);
  }

  /// 與 `AppFlowFixture.app` 相同的 override 鏈，再補 account／share／poi 與網路訊號。
  Widget buildApp({double textScale = 1.0}) {
    final f = fixture;
    final app = ProviderScope(
      key: UniqueKey(),
      overrides: [
        apiClientProvider.overrideWithValue(f.apiClient),
        authRepositoryProvider.overrideWithValue(f.auth),
        tripRepositoryProvider.overrideWithValue(f.trips),
        collabRepositoryProvider.overrideWithValue(f.collab),
        requestsRepositoryProvider.overrideWithValue(f.requests),
        favoritesRepositoryProvider.overrideWithValue(f.favorites),
        favoritesProvider.overrideWith((ref) => f.favoritesStream.stream),
        offlinePendingCountProvider.overrideWith(
          (ref) => f.pendingCountStream.stream,
        ),
        mapRepositoryProvider.overrideWithValue(f.map),
        speechServiceProvider.overrideWithValue(f.speech),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        tripMapCanvasBuilderProvider.overrideWithValue(f.mapCanvasBuilder),
        appNetworkAvailabilityProvider.overrideWithValue(network),
        appVersionProvider.overrideWith(
          (ref) async => releaseSmokeFixtureAppVersion,
        ),
        themeModeProvider.overrideWith(
          () => ThemeModeController(initialMode: f.initialThemeMode!),
        ),
        accountRepositoryProvider.overrideWithValue(account),
        shareRepositoryProvider.overrideWithValue(share),
        poiRepositoryProvider.overrideWithValue(poi),
      ],
      child: const TriplineApp(),
    );
    if (textScale == 1.0) return app;
    return _TextScaled(scale: textScale, child: app);
  }
}

typedef MockAuthRepositoryAlias = MockAuthRepository;

class _TextScaled extends StatelessWidget {
  const _TextScaled({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  );
}

final higNotes = TripNotes.fromJson({
  'flights': [
    {
      'id': 1,
      'airline': '長榮航空',
      'flightNo': 'BR108',
      'departAirport': 'TPE',
      'arriveAirport': 'OKA',
      'departAt': '2026-11-01T09:00',
      'arriveAt': '2026-11-01T11:30',
    },
  ],
  'lodgings': [
    {
      'id': 2,
      'name': '那霸海濱飯店',
      'address': '沖繩縣那霸市西 1-2-3',
      'checkInAt': '2026-11-01',
      'checkOutAt': '2026-11-03',
    },
  ],
  'reservations': [
    {
      'id': 3,
      'kind': 'restaurant',
      'title': '牧志市場燒肉',
      'reservedAt': '2026-11-01T19:00',
      'partySize': 4,
    },
  ],
  'pretripNotes': [
    {
      'id': 4,
      'section': 'pretrip',
      'title': '行前確認',
      'content': '- 護照效期\n- 租車駕照日文譯本',
    },
  ],
  'emergencyContacts': [
    {'id': 5, 'name': '駐那霸辦事處', 'phone': '+81-98-862-7008', 'kind': 'embassy'},
  ],
});

final higPublicShare = PublicTripShare(
  name: 'okinawa',
  title: '沖繩家族之旅',
  countries: 'JP',
  sharedBy: 'Ray',
  destinations: const ['那霸', '首里'],
  days: releaseSmokeDays,
  notes: higNotes,
);

typedef HigCapture = Future<void> Function(String name);

/// 一個要拍的畫面。[tickets] 是這個畫面主要驗的票號。
class HigScene {
  const HigScene(
    this.name,
    this.tickets, {
    this.location,
    this.loggedIn = true,
    this.stub,
    this.act,
    this.textScale = 1.0,
    this.settle = true,
  });

  final String name;
  final String tickets;
  final String? location;
  final bool loggedIn;
  final FutureOr<void> Function(HigFakes f)? stub;
  final Future<void> Function(WidgetTester tester, HigFakes f)? act;
  final double textScale;

  /// false 時只固定跑幾幀（畫面上有永不停止的動畫，例如載入中）。
  final bool settle;
}

Future<void> higSettle(WidgetTester tester, {bool settle = true}) async {
  if (!settle) {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return;
  }
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 8),
    );
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 以 [mode] 把 [scene] 跑到定位並呼叫 [capture]。
Future<void> runHigScene(
  WidgetTester tester,
  HigScene scene,
  ThemeMode mode,
  HigCapture capture,
) async {
  final f = HigFakes.create(mode: mode, loggedIn: scene.loggedIn);
  addTearDown(f.fixture.dispose);
  await scene.stub?.call(f);
  await tester.pumpWidget(f.buildApp(textScale: scene.textScale));
  await higSettle(tester, settle: scene.settle);
  final loc = scene.location;
  if (loc != null) {
    final ctx = tester.element(find.byType(TriplineApp));
    ProviderScope.containerOf(ctx).read(appRouterProvider).go(loc);
    await higSettle(tester, settle: scene.settle);
  }
  if (scene.act != null) {
    await scene.act!(tester, f);
    await higSettle(tester, settle: scene.settle);
  }
  await capture(scene.name);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsWidgets, reason: 'key $key');
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await higSettle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: 'text $text');
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await higSettle(tester);
}

/// 以 [Navigator] 目前最上層頁面為準，捲到頂 / 底。
Future<void> _scrollDown(WidgetTester tester, [double dy = -600]) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  await tester.drag(scrollables.first, Offset(0, dy));
  await higSettle(tester);
}

final _failure = ApiError(status: 500, code: 'SERVER_ERROR', message: 'boom');

/// 全部情境（依使用者清單排列）。
List<HigScene> higScenes() => [
  // ── auth ──
  const HigScene(
    'auth-welcome',
    '#423 #428',
    location: '/welcome',
    loggedIn: false,
  ),
  const HigScene(
    'auth-login',
    '#420 #424',
    location: '/login',
    loggedIn: false,
  ),
  HigScene(
    'auth-login-error',
    '#420 #424',
    location: '/login',
    loggedIn: false,
    stub: (f) => when(
      () => f.auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => throw _failure),
    act: (tester, f) async {
      await tester.enterText(
        find.byKey(const ValueKey('login-email-field')),
        'ray@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password-field')),
        'wrong-password',
      );
      await _tapKey(tester, 'login-submit-button');
    },
  ),
  const HigScene(
    'auth-signup',
    '#424 #428',
    location: '/signup',
    loggedIn: false,
  ),
  const HigScene(
    'auth-forgot-password',
    '#420 #424',
    location: '/login/forgot',
    loggedIn: false,
  ),

  // ── 行程列表／建立／編輯 ──
  const HigScene('trips-list', '#426 #427', location: '/trips'),
  HigScene(
    'trips-list-load-failed',
    '#418',
    location: '/trips',
    stub: (f) =>
        when(f.trips.watchMyTrips).thenAnswer((_) => Stream.error(_failure)),
  ),
  HigScene(
    'trips-list-empty',
    '#418 #427',
    location: '/trips',
    stub: (f) => when(
      f.trips.watchMyTrips,
    ).thenAnswer((_) => Stream.value(const <TripSummary>[])),
  ),
  const HigScene('trip-create', '#424 #426', location: '/new-trip'),
  HigScene(
    'trip-edit',
    '#417 #424',
    location: '/edit-trip/okinawa',
    stub: (f) => when(() => f.trips.fetchTrip('okinawa')).thenAnswer(
      (_) async => const Trip(
        id: 'okinawa',
        name: 'okinawa',
        title: '沖繩家族之旅',
        description: '四天三夜',
        lang: 'zh-TW',
        startDate: '2026-11-01',
        endDate: '2026-11-04',
      ),
    ),
  ),
  HigScene(
    'trip-edit-load-failed',
    '#417',
    location: '/edit-trip/okinawa',
    stub: (f) => when(
      () => f.trips.fetchTrip('okinawa'),
    ).thenAnswer((_) async => throw _failure),
  ),

  // ── 行程詳情 ──
  const HigScene('trip-timeline', '#421 #423', location: '/trips/okinawa'),
  const HigScene('trip-map', '#418', location: '/trips/okinawa/map'),
  HigScene(
    'trip-map-route-failed',
    '#418',
    location: '/trips/okinawa/map',
    stub: (f) => when(
      () => f.map.fetchRoute(
        fromLat: any(named: 'fromLat'),
        fromLng: any(named: 'fromLng'),
        toLat: any(named: 'toLat'),
        toLng: any(named: 'toLng'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => throw _failure),
  ),
  const HigScene('trip-notes', '#419 #422', location: '/trips/okinawa/notes'),
  const HigScene('trip-print', '#419', location: '/trips/okinawa/print'),

  // ── 收藏／探索 ──
  HigScene(
    'favorites',
    '#418 #426',
    location: '/favorites',
    act: (tester, f) async {
      f.favoritesStream.add(releaseSmokeFavorites);
    },
  ),
  HigScene(
    'favorites-load-failed',
    '#418',
    location: '/favorites',
    act: (tester, f) async {
      f.favoritesStream.addError(StateError('fixture'));
    },
  ),
  const HigScene('explore', '#418 #426', location: '/favorites/explore'),
  HigScene(
    'explore-empty-results',
    '#418',
    location: '/favorites/explore',
    stub: (f) => when(
      () => f.poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const <PoiSearchResult>[]),
  ),
  HigScene(
    'explore-search-failed',
    '#418',
    location: '/favorites/explore',
    stub: (f) => when(
      () => f.poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => throw _failure),
  ),

  // ── 聊天 ──
  HigScene(
    'chat',
    '#429',
    location: '/chat',
    stub: (f) =>
        when(
          () => f.requests.fetchRequests(
            tripId: any(named: 'tripId'),
            limit: any(named: 'limit'),
            sort: any(named: 'sort'),
            before: any(named: 'before'),
            beforeId: any(named: 'beforeId'),
          ),
        ).thenAnswer(
          (_) async => (
            items: <TripRequest>[
              const TripRequest(
                id: 1,
                tripId: 'okinawa',
                message: '第二天下雨怎麼辦？',
                reply: '建議改去**美麗海水族館**，室內行程不怕雨。\n\n- 09:00 出發\n- 預估車程 90 分鐘',
                status: RequestStatus.completed,
              ),
            ],
            hasMore: false,
          ),
        ),
  ),

  // ── 帳號 ──
  const HigScene('account-home', '#425', location: '/trips?account=home'),
  const HigScene(
    'account-sessions',
    '#425',
    location: '/trips?account=sessions',
  ),
  HigScene(
    'account-sessions-load-failed',
    '#425 #418',
    location: '/trips?account=sessions',
    stub: (f) => when(
      () => f.account.fetchAccountSessions(),
    ).thenAnswer((_) async => throw _failure),
  ),
  const HigScene(
    'account-connected-apps',
    '#425',
    location: '/trips?account=connected-apps',
  ),
  const HigScene(
    'account-developer-apps',
    '#425',
    location: '/trips?account=developer-apps',
  ),
  const HigScene(
    'account-developer-app-new',
    '#424 #425',
    location: '/trips?account=developer-apps/new',
  ),
  const HigScene(
    'account-settings-appearance',
    '#426',
    location: '/trips?account=appearance',
  ),
  const HigScene(
    'account-settings-profile',
    '#424',
    location: '/trips?account=profile',
  ),
  const HigScene(
    'account-settings-notifications',
    '#425',
    location: '/trips?account=notifications',
  ),
  HigScene(
    'account-delete-dialog',
    '#425',
    location: '/trips?account=home',
    act: (tester, f) async {
      await _scrollDown(tester, -1200);
      await _tapKey(tester, 'settings-delete-account');
    },
  ),

  // ── 邀請 ──
  const HigScene(
    'invite-signed-in',
    '#415',
    location: '/invite?token=demo-invite-token',
  ),
  HigScene(
    'invite-wrong-account',
    '#415',
    location: '/invite?token=demo-invite-token',
    stub: (f) => when(() => f.fixture.collab.fetchInvitation(any())).thenAnswer(
      (_) async => const InvitationDetails(
        tripId: 'okinawa',
        tripTitle: '沖繩家族之旅',
        invitedEmail: 'someone-else@example.com',
        inviterDisplayName: 'Mia',
        inviterEmail: 'mia@example.com',
        expiresAt: '2026-11-01T00:00:00Z',
      ),
    ),
  ),
  HigScene(
    'invite-wrong-account-pending',
    '#415',
    location: '/invite?token=demo-invite-token',
    stub: (f) => when(() => f.fixture.collab.fetchInvitation(any())).thenAnswer(
      (_) async => const InvitationDetails(
        tripId: 'okinawa',
        tripTitle: '沖繩家族之旅',
        invitedEmail: 'someone-else@example.com',
        inviterDisplayName: 'Mia',
        inviterEmail: 'mia@example.com',
        expiresAt: '2026-11-01T00:00:00Z',
      ),
    ),
    act: (tester, f) async {
      // logout_confirm 讀的是 cacheStore 佇列，不是 pending 計數串流。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TriplineApp)),
      );
      for (var i = 0; i < 3; i++) {
        await container
            .read(cacheStoreProvider)
            .appendMutation(
              QueuedMutation(
                id: 'q$i',
                method: 'PATCH',
                path: '/trips/okinawa',
                type: 'update-entry',
                cacheKey: 'trips/okinawa',
                args: const {},
                createdAt: '2026-10-10T00:00:00Z',
              ),
            );
      }
      await _tapText(tester, '切換帳號');
    },
  ),
  HigScene(
    'invite-load-failed',
    '#415',
    location: '/invite?token=demo-invite-token',
    stub: (f) => when(
      () => f.fixture.collab.fetchInvitation(any()),
    ).thenAnswer((_) async => throw _failure),
  ),
  const HigScene(
    'invite-logged-out',
    '#415',
    location: '/invite?token=demo-invite-token',
    loggedIn: false,
  ),

  // ── 分享 ──
  const HigScene('share-manage', '#416 #430', location: '/share-trip/okinawa'),
  HigScene(
    'share-custom-expiry-missing',
    '#416',
    location: '/share-trip/okinawa',
    act: (tester, f) async {
      await _tapText(tester, '自訂');
      await _tapKey(tester, 'share-create');
    },
  ),
  HigScene(
    'share-created-card',
    '#416 #430',
    location: '/share-trip/okinawa',
    act: (tester, f) async {
      await _tapKey(tester, 'share-create');
    },
  ),
  HigScene(
    'share-create-failed',
    '#416',
    location: '/share-trip/okinawa',
    stub: (f) => when(
      () => f.share.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        expiresAt: any(named: 'expiresAt'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer((_) async => throw _failure),
    act: (tester, f) async {
      await _tapKey(tester, 'share-create');
    },
  ),
  HigScene(
    'share-list-load-failed',
    '#416',
    location: '/share-trip/okinawa',
    stub: (f) => when(
      () => f.share.fetchShares(any()),
    ).thenAnswer((_) async => throw _failure),
  ),
  const HigScene(
    'public-share',
    '#428',
    location: '/s/demo-token-0123456789',
    loggedIn: false,
  ),
  const HigScene(
    'public-share-signed-in',
    '#428',
    location: '/s/demo-token-0123456789',
  ),

  // ── 離線與 AX 字級 ──
  HigScene(
    'offline-banner-network',
    '#419',
    location: '/trips',
    stub: (f) => f.network = Stream<bool>.value(false),
  ),
  HigScene(
    'offline-banner-pending',
    '#415 #419',
    location: '/trips',
    act: (tester, f) async {
      f.fixture.pendingCountStream.add(2);
    },
  ),
  const HigScene(
    'ax-welcome-2x',
    '#422',
    location: '/welcome',
    loggedIn: false,
    textScale: 2.0,
  ),
  const HigScene(
    'ax-login-2x',
    '#422',
    location: '/login',
    loggedIn: false,
    textScale: 2.0,
  ),
  const HigScene(
    'ax-trips-list-2x',
    '#422',
    location: '/trips',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-trip-timeline-2x',
    '#422 #423',
    location: '/trips/okinawa',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-share-manage-2x',
    '#422 #416',
    location: '/share-trip/okinawa',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-account-home-2x',
    '#422 #425',
    location: '/trips?account=home',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-invite-2x',
    '#422 #415',
    location: '/invite?token=demo-invite-token',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-trips-list-3x',
    '#422',
    location: '/trips',
    textScale: 3.0,
  ),
];

/// TpChip／TpSegmentedControl／TpPickerField 的元件展示頁（跟隨 [mode]）。
Future<void> runHigComponentsScene(
  WidgetTester tester,
  ThemeMode mode,
  HigCapture capture, {
  String name = 'components',
  double textScale = 1.0,
}) async {
  final theme = mode == ThemeMode.dark ? AppTheme.dark() : AppTheme.light();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('TpChip'),
              Wrap(
                spacing: 8,
                children: [
                  TpChip(label: '全部', selected: true, onPressed: () {}),
                  TpChip(label: '景點', onPressed: () {}),
                  TpChip(label: '餐廳', onPressed: () {}),
                  const TpChip(label: '停用'),
                ],
              ),
              const SizedBox(height: 24),
              const Text('TpSegmentedControl'),
              TpSegmentedControl<String>(
                value: 'b',
                options: const {'a': '永久', 'b': '24 小時', 'c': '7 天', 'd': '自訂'},
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              TpSegmentedControl<String>(
                value: 'a',
                options: const {'a': '永久', 'b': '24 小時'},
                onChanged: null,
              ),
              const SizedBox(height: 24),
              const Text('TpPickerField'),
              TpPickerField<String>(
                label: '語言',
                value: 'zh',
                options: const {'zh': '繁體中文', 'en': 'English'},
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              TpPickerField<String>(
                label: '交通方式',
                value: null,
                options: const {'car': '開車', 'walk': '步行'},
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              TpPickerField<String>(
                label: '停用欄位',
                value: 'zh',
                options: const {'zh': '繁體中文'},
                onChanged: null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await higSettle(tester);
  await capture(name);
}
