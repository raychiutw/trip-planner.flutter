/// HIG 修補（#415–#430）的截圖情境：每個情境用 fixture／provider override 灌資料，
/// 淺色與深色都走 App 自己的 `themeModeProvider`（`ThemeModeController(initialMode:)`），
/// 不依賴 `simctl ui appearance`。全部走 mock repository，不碰 prod。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActionSheet, CupertinoAlertDialog;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart' show AccountDeletionPreview;
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/cache/cache_store.dart' show QueuedMutation;
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/api/share_repository.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/app_version.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/offline/offline_sync.dart';
import 'package:tripline/features/chat/speech_service.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/day.dart' show TripDay;
import 'package:tripline/models/entry.dart' show EntryPoiInfo, TimelineEntry;
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/models/share.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_audit.dart';
import 'package:tripline/models/trip_health.dart';
import 'package:tripline/models/trip_poi_health.dart';
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

  /// App 鎖情境：非 null 時以此初始狀態啟動；[biometric] 預設永不回應，
  /// 畫面才會停在鎖定頁而不是自動解鎖。
  bool? appLockEnabled;

  /// 預設裝置沒有生物辨識：否則每個已登入場景都會被「要用 Face ID 登入嗎？」詢問蓋住，
  /// 截圖與量測量到的是對話框而不是畫面本體。需要的場景自行換成 [_PendingBiometric]／[_OkBiometric]。
  BiometricAuthenticator biometric = _NoBiometric();

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
    when(fixture.auth.fetchAccountDeletionPreview).thenAnswer(
      (_) async => const AccountDeletionPreview(
        hasPassword: true,
        tripsOwned: 2,
        collaboratorsAffected: 3,
      ),
    );
    if (loggedIn) {
      fixture.session.signedIn = true;
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
  Widget buildApp({double textScale = 1.0, bool highContrast = false}) {
    final f = fixture;
    final app = ProviderScope(
      key: UniqueKey(),
      // 與 widget test 慣例相同:關掉自動 retry,才拍得到真正的錯誤態
      // (產品行為見 #471)。
      retry: (retryCount, error) => null,
      overrides: [
        ...f.authOverrides,
        biometricAuthenticatorProvider.overrideWithValue(biometric),
        appLockProvider.overrideWith(
          () => AppLockController(initialEnabled: appLockEnabled ?? false),
        ),
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
    if (textScale == 1.0 && !highContrast) return app;
    return _TextScaled(
      scale: textScale,
      highContrast: highContrast,
      child: app,
    );
  }
}

typedef MockAuthRepositoryAlias = MockAuthRepository;

/// 沒有生物辨識的裝置：不會跳出任何生物辨識詢問。
class _NoBiometric implements BiometricAuthenticator {
  @override
  Future<BiometricKind?> availableKind() async => null;

  @override
  Future<BiometricOutcome> authenticate({required String reason}) =>
      Completer<BiometricOutcome>().future;
}

/// 永遠等待使用者操作的驗證器(Face ID 裝置)。
class _PendingBiometric implements BiometricAuthenticator {
  @override
  Future<BiometricKind?> availableKind() async => BiometricKind.faceId;

  @override
  Future<BiometricOutcome> authenticate({required String reason}) =>
      Completer<BiometricOutcome>().future;
}

/// 立刻回報成功的驗證器(登入後詢問、設定頁情境)。
class _OkBiometric extends _PendingBiometric {
  @override
  Future<BiometricOutcome> authenticate({required String reason}) async =>
      BiometricOutcome.success;
}

/// 以 MediaQuery 覆寫模擬系統設定：文字大小、提高對比。
class _TextScaled extends StatelessWidget {
  const _TextScaled({
    required this.scale,
    required this.child,
    this.highContrast = false,
  });

  final double scale;
  final bool highContrast;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      highContrast: highContrast,
    ),
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
    this.proof,
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

  /// 證明場景真的渲染出預期畫面（不是空白或錯誤頁）。截圖前會斷言它至少找到一個 widget。
  final Finder Function()? proof;
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
  HigCapture capture, {
  bool highContrast = false,
}) async {
  final f = HigFakes.create(mode: mode, loggedIn: scene.loggedIn);
  addTearDown(f.fixture.dispose);
  await scene.stub?.call(f);
  await tester.pumpWidget(
    f.buildApp(textScale: scene.textScale, highContrast: highContrast),
  );
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
  final proof = scene.proof;
  if (proof != null) {
    expect(proof(), findsWidgets, reason: '場景 ${scene.name} 沒有渲染出預期畫面');
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

/// 點第一個 key 字串以 [prefix] 開頭的 widget（key 帶動態 id 時用）。
Future<void> _tapKeyPrefix(WidgetTester tester, String prefix) async {
  final finder = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith(prefix),
  );
  expect(finder, findsWidgets, reason: 'key prefix $prefix');
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

void _entryDetailOk(HigFakes f) =>
    when(
      () => f.fixture.trips.watchEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer(
      // 編輯表單只採用比種子（version 0）新的詳情，所以版本要大於 0。
      (_) => Stream.value(
        const TimelineEntry(
          id: 11,
          sortOrder: 0,
          version: 1,
          startTime: '10:00',
          endTime: '11:00',
          title: '那霸機場',
        ),
      ),
    );

void _poiHealthOk(HigFakes f) =>
    when(() => f.fixture.trips.fetchPoiHealth(any())).thenAnswer(
      (_) async => const TripPoiHealthReport(version: 1, closed: 0, missing: 0),
    );

Future<void> _submitResetPassword(WidgetTester tester, HigFakes f) async {
  await tester.enterText(
    find.byKey(const ValueKey('reset-password-field')),
    'Passw0rd!x1',
  );
  await tester.enterText(
    find.byKey(const ValueKey('reset-password-confirm-field')),
    'Passw0rd!x1',
  );
  await tester.pump();
  await _tapKey(tester, 'reset-password-submit-button');
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
    stub: (f) => f.fixture.session.loginError = OAuthLoginException(
      'boom',
      userMessage: 'Tripline 登入失敗，請稍後再試',
    ),
    act: (tester, f) async => _tapKey(tester, 'login-browser-button'),
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

  HigScene(
    'auth-check-email',
    '#534',
    location: '/signup/check-email?email=demo@example.com',
    loggedIn: false,
    proof: () => find.byKey(const ValueKey('verify-pending-page')),
  ),
  HigScene(
    'auth-reset-password',
    '#534',
    location: '/auth/password/reset?token=demo-token',
    loggedIn: false,
    proof: () => find.byKey(const ValueKey('reset-password-field')),
  ),
  HigScene(
    'auth-reset-password-success',
    '#534',
    location: '/auth/password/reset?token=demo-token',
    loggedIn: false,
    stub: (f) => when(
      () => f.auth.resetPassword(
        token: any(named: 'token'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => null),
    act: _submitResetPassword,
    proof: () => find.byKey(const ValueKey('reset-password-success')),
  ),
  HigScene(
    'auth-reset-password-expired',
    '#534',
    location: '/auth/password/reset?token=demo-token',
    loggedIn: false,
    stub: (f) =>
        when(
          () => f.auth.resetPassword(
            token: any(named: 'token'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          ApiError(
            status: 400,
            code: 'RESET_TOKEN_INVALID',
            message: 'invalid',
          ),
        ),
    act: _submitResetPassword,
    // 要證明的是「連結過期」那一種錯誤，不是任何一種錯誤（code 對不上時畫面會顯示通用的「暫時無法處理」）。
    proof: () => find.descendant(
      of: find.byKey(const ValueKey('reset-password-error')),
      matching: find.textContaining('重設連結無效或已過期'),
    ),
  ),
  HigScene(
    'auth-verify-email',
    '#534',
    location: '/auth/verify-email?token=demo-token',
    loggedIn: false,
    proof: () => find.byKey(const ValueKey('verify-email-confirm-button')),
  ),
  HigScene(
    'auth-verify-email-success',
    '#534',
    location: '/auth/verify-email?token=demo-token',
    loggedIn: false,
    stub: (f) =>
        when(() => f.auth.verifyEmail(any())).thenAnswer((_) async => true),
    act: (tester, f) async => _tapKey(tester, 'verify-email-confirm-button'),
    proof: () => find.byKey(const ValueKey('verify-email-success')),
  ),
  HigScene(
    'auth-verify-email-incomplete',
    '#534',
    location: '/auth/verify-email',
    loggedIn: false,
    proof: () => find.byKey(const ValueKey('verify-email-error')),
  ),
  HigScene(
    'oauth-consent-invalid',
    '#534',
    location: '/oauth/consent',
    loggedIn: false,
    proof: () => find.text('請返回原本的瀏覽器，從該處重新完成授權。'),
  ),
  HigScene(
    'account-logout-confirm',
    '#534',
    location: '/trips?account=sessions',
    act: (tester, f) async => _tapKey(tester, 'account-sessions-logout'),
    proof: () => find.text('登出帳號'),
  ),
  HigScene(
    'account-connected-app-revoke-confirm',
    '#534',
    location: '/trips?account=connected-apps',
    act: (tester, f) async => _tapKeyPrefix(tester, 'connected-app-revoke-'),
    proof: () => find.byType(CupertinoAlertDialog),
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
    stub: (f) {
      // 預設 fixture 每天只有一個有座標的停留點，湊不出相鄰兩點，路線根本不會被抓取，
      // 失敗提示也就不會出現。這裡給第 1 天補第二個有座標的停留點，並讓路線抓取失敗。
      final day1 = releaseSmokeDays.first;
      final days = [
        TripDay(
          id: day1.id,
          dayNum: day1.dayNum,
          title: day1.title,
          version: day1.version,
          timeline: [
            ...day1.timeline,
            TimelineEntry(
              id: 12,
              sortOrder: 1,
              version: 0,
              startTime: '12:00',
              endTime: '13:00',
              title: '國際通',
              master: const EntryPoiInfo(
                poiId: 1003,
                name: '國際通',
                lat: 26.2142,
                lng: 127.6879,
                type: 'sight',
              ),
            ),
          ],
        ),
        ...releaseSmokeDays.skip(1),
      ];
      when(
        () => f.trips.watchDays('okinawa'),
      ).thenAnswer((_) => Stream.value(days));
      when(
        () => f.map.fetchRoute(
          fromLat: any(named: 'fromLat'),
          fromLng: any(named: 'fromLng'),
          toLat: any(named: 'toLat'),
          toLng: any(named: 'toLng'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => throw _failure);
    },
    proof: () => find.byKey(const ValueKey('trip-map-route-error')),
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

  // ── #536：協作、健檢、稽核、停留點路由 ──
  HigScene(
    'collab',
    '#536',
    location: '/collab/okinawa',
    proof: () => find.byKey(const ValueKey('collab-content')),
  ),
  HigScene(
    'collab-load-failed',
    '#536',
    location: '/collab/okinawa',
    stub: (f) => when(
      () => f.fixture.collab.fetchMembers(any()),
    ).thenAnswer((_) async => throw _failure),
    proof: () => find.byKey(const ValueKey('collab-page-error')),
  ),
  HigScene(
    'trip-health-not-run',
    '#536',
    location: '/trips/okinawa/health',
    stub: (f) {
      _poiHealthOk(f);
      when(
        () => f.fixture.trips.fetchHealthReport(any()),
      ).thenAnswer((_) async => null);
    },
    proof: () => find.byKey(const ValueKey('trip-health-content')),
  ),
  HigScene(
    'trip-health-findings',
    '#536',
    location: '/trips/okinawa/health',
    stub: (f) {
      _poiHealthOk(f);
      when(() => f.fixture.trips.fetchHealthReport(any())).thenAnswer(
        (_) async => const TripHealthReport(
          tripId: 'okinawa',
          userId: 'u-1',
          status: TripHealthStatus.completed,
          createdAt: '2026-10-10T00:00:00Z',
          completedAt: '2026-10-10T00:01:00Z',
          findings: [
            TripHealthFinding(
              severity: TripHealthSeverity.high,
              title: '第一天行程過滿',
              description: '10:00 到 21:00 之間沒有休息時間。',
              suggestion: '把其中一個景點移到第二天。',
            ),
            TripHealthFinding(
              severity: TripHealthSeverity.low,
              title: '午餐尚未安排',
              description: '第二天沒有用餐停留點。',
            ),
          ],
        ),
      );
    },
    proof: () => find.text('第一天行程過滿'),
  ),
  HigScene(
    'trip-health-load-failed',
    '#536',
    location: '/trips/okinawa/health',
    stub: (f) {
      _poiHealthOk(f);
      when(() => f.fixture.trips.fetchHealthReport(any())).thenThrow(_failure);
    },
    proof: () => find.byKey(const ValueKey('trip-health-load-error')),
  ),
  HigScene(
    'trip-audit',
    '#536',
    location: '/trips/okinawa/audit',
    stub: (f) =>
        when(
          () => f.fixture.trips.fetchAuditLog(
            any(),
            limit: any(named: 'limit'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => const [
            TripAuditRow(
              id: 1,
              tripId: 'okinawa',
              tableName: 'trip_entries',
              action: TripAuditAction.update,
              createdAt: '2026-10-10T00:00:00Z',
              recordId: 11,
              changedBy: 'ray@example.com',
            ),
            TripAuditRow(
              id: 2,
              tripId: 'okinawa',
              tableName: 'trip_entries',
              action: TripAuditAction.insert,
              createdAt: '2026-10-09T00:00:00Z',
              recordId: 12,
              changedBy: 'ray@example.com',
            ),
          ],
        ),
    proof: () => find.byKey(const ValueKey('trip-audit-row-1')),
  ),
  HigScene(
    'trip-audit-empty',
    '#536',
    location: '/trips/okinawa/audit',
    stub: (f) => when(
      () => f.fixture.trips.fetchAuditLog(
        any(),
        limit: any(named: 'limit'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => const <TripAuditRow>[]),
    proof: () => find.byKey(const ValueKey('trip-audit-empty')),
  ),
  HigScene(
    'trip-audit-load-failed',
    '#536',
    location: '/trips/okinawa/audit',
    stub: (f) => when(
      () => f.fixture.trips.fetchAuditLog(
        any(),
        limit: any(named: 'limit'),
        requestId: any(named: 'requestId'),
      ),
    ).thenThrow(_failure),
    proof: () => find.byKey(const ValueKey('trip-audit-error')),
  ),
  HigScene(
    'entry-add',
    '#536',
    location: '/trips/okinawa/entries/new?day=1',
    proof: () => find.text('新增停留點'),
  ),
  HigScene(
    'entry-edit',
    '#536',
    location: '/trips/okinawa/entries/11/edit',
    stub: _entryDetailOk,
    proof: () => find.text('管理地點'),
  ),
  HigScene(
    'entry-copy',
    '#536',
    location: '/trips/okinawa/entries/11/copy',
    proof: () => find.byKey(const ValueKey('entry-action-submit')),
  ),
  HigScene(
    'entry-move',
    '#536',
    location: '/trips/okinawa/entries/11/move',
    proof: () => find.byKey(const ValueKey('entry-action-submit')),
  ),
  HigScene(
    'entry-pois',
    '#536',
    location: '/trips/okinawa/entries/11/pois',
    stub: _entryDetailOk,
    proof: () => find.text('正選地點'),
  ),

  // ── #535：全域地圖、加入行程、確認對話框 ──
  HigScene(
    'global-map',
    '#535',
    location: '/map?tripId=okinawa',
    proof: () => find.byKey(const ValueKey('global-trip-map-okinawa')),
  ),
  HigScene(
    'global-map-empty',
    '#535',
    location: '/map',
    stub: (f) => when(
      f.trips.watchMyTrips,
    ).thenAnswer((_) => Stream.value(const <TripSummary>[])),
    proof: () => find.text('尚無行程'),
  ),
  HigScene(
    'global-map-load-failed',
    '#535',
    location: '/map',
    stub: (f) =>
        when(f.trips.watchMyTrips).thenAnswer((_) => Stream.error(_failure)),
    proof: () => find.text('載入失敗'),
  ),
  HigScene(
    'add-to-trip-direct',
    '#535',
    location:
        '/favorites/add-to-trip?place_id=p1&name=%E7%BE%8E%E9%BA%97%E6%B5%B7%E6%B0%B4%E6%97%8F%E9%A4%A8&lat=26.69&lng=127.88',
    proof: () => find.byKey(const ValueKey('add-to-trip-submit')),
  ),
  HigScene(
    'add-to-trip-missing-data',
    '#535',
    location: '/favorites/add-to-trip',
    proof: () => find.text('景點資料缺漏，請從探索頁重新進入'),
  ),
  HigScene(
    'add-to-trip-invalid-favorite',
    '#535',
    location: '/favorites/0/add-to-trip',
    proof: () => find.text('收藏 ID 無效'),
  ),
  HigScene(
    'trip-delete-confirm',
    '#535',
    location: '/trips',
    act: (tester, f) async {
      await _tapKey(tester, 'trip-card-more-okinawa');
      await _tapKey(tester, 'trip-menu-delete-okinawa');
    },
    proof: () => find.byType(CupertinoActionSheet),
  ),
  HigScene(
    'chat-voice-consent',
    '#535',
    location: '/chat',
    act: (tester, f) async => _tapKey(tester, 'chat-mic-button'),
    proof: () => find.text('使用語音輸入？'),
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

  // ── App 鎖 ──
  HigScene(
    'app-lock-locked',
    '#462',
    location: '/trips',
    stub: (f) {
      f.appLockEnabled = true;
      f.biometric = _PendingBiometric();
    },
    settle: false,
  ),
  HigScene(
    'app-lock-locked-ax-2x',
    '#462 #422',
    location: '/trips',
    stub: (f) {
      f.appLockEnabled = true;
      f.biometric = _PendingBiometric();
    },
    textScale: 2.0,
    settle: false,
  ),
  HigScene(
    'app-lock-enable-prompt',
    '#462',
    loggedIn: false,
    location: '/login',
    stub: (f) => f.biometric = _OkBiometric(),
    act: (tester, f) async => _tapKey(tester, 'login-browser-button'),
  ),
  HigScene(
    'account-home-security',
    '#462 #425',
    location: '/trips?account=home',
    act: (tester, f) async => _scrollDown(tester, -400),
  ),
  HigScene(
    'ax-account-home-2x-bottom',
    '#422 #462',
    location: '/trips?account=home',
    textScale: 2.0,
    act: (tester, f) async => _scrollDown(tester, -1200),
  ),

  // ── 更多大字級畫面 ──
  const HigScene(
    'ax-trip-map-2x',
    '#422',
    location: '/trips/okinawa/map',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-trip-notes-2x',
    '#422',
    location: '/trips/okinawa/notes',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-trip-print-2x',
    '#422',
    location: '/trips/okinawa/print',
    textScale: 2.0,
  ),
  HigScene(
    'ax-favorites-2x',
    '#422',
    location: '/favorites',
    textScale: 2.0,
    act: (tester, f) async {
      f.favoritesStream.add(releaseSmokeFavorites);
    },
    // 沒有資料流就只會拍到載入骨架；要確認真的渲染出收藏清單。
    proof: () => find.text('暖暮拉麵'),
  ),
  const HigScene(
    'ax-explore-2x',
    '#422',
    location: '/favorites/explore',
    textScale: 2.0,
  ),
  const HigScene('ax-chat-2x', '#422', location: '/chat', textScale: 2.0),
  const HigScene(
    'ax-public-share-2x',
    '#422',
    location: '/s/demo-token-0123456789',
    loggedIn: false,
    textScale: 2.0,
  ),
  const HigScene(
    'ax-trip-create-2x',
    '#422',
    location: '/new-trip',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-account-appearance-2x',
    '#422',
    location: '/trips?account=appearance',
    textScale: 2.0,
  ),
  const HigScene(
    'ax-account-notifications-2x',
    '#422',
    location: '/trips?account=notifications',
    textScale: 2.0,
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
