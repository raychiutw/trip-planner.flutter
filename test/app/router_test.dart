/// appRouterProvider redirect 行為測試：
/// 1. 未登入（AsyncData null）→ 任何受保護路徑 redirect 到 /welcome
/// 2. 已登入在 /login → redirect 到 /trips
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/ui/tp_segmented_control.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/dpop/proof_key.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/auth/account_flow_screens.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/account/account_sessions_screen.dart';
import 'package:tripline/features/account/account_screen.dart';
import 'package:tripline/features/account/connected_apps_screen.dart';
import 'package:tripline/features/account/developer_apps_screen.dart';
import 'package:tripline/features/account/settings/appearance_screen.dart';
import 'package:tripline/features/account/settings/notifications_screen.dart';
import 'package:tripline/features/account/settings/profile_edit_screen.dart';
import 'package:tripline/features/chat/chat_screen.dart';
import 'package:tripline/features/favorites/explore/explore_screen.dart';
import 'package:tripline/features/favorites/add_to_trip/add_to_trip_screen.dart';
import 'package:tripline/features/invite/invite_screen.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/features/share/public_share_screen.dart';
import 'package:tripline/features/shell/apple_root_tab_bar.dart';
import 'package:tripline/features/trip_detail/entry_action_route_screen.dart';
import 'package:tripline/features/trip_detail/entry_add_route_screen.dart';
import 'package:tripline/features/trip_detail/entry_edit_route_screen.dart';
import 'package:tripline/features/trip_detail/entry_poi_screen.dart';
import 'package:tripline/features/trip_detail/selected_day_provider.dart';
import 'package:tripline/features/trip_detail/trip_notes_screen.dart';
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_print_screen.dart';
import 'package:tripline/features/trip_detail/trip_pdf_service.dart';
import 'package:tripline/features/trip_detail/trip_print_data.dart';
import 'package:tripline/features/trip_detail/trip_timeline_screen.dart';
import 'package:tripline/features/trips/audit/trip_audit_screen.dart';
import 'package:tripline/features/trips/create/create_trip_screen.dart';
import 'package:tripline/features/trips/edit/edit_trip_screen.dart';
import 'package:tripline/features/trips/health/trip_health_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/share.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_audit.dart';
import 'package:tripline/models/trip_poi_health.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';

import '../helpers/fake_biometric.dart';
import '../helpers/fake_trip_map.dart';
import '../helpers/fake_oauth.dart';

/// 固定回傳指定使用者的假 AuthNotifier（不打 API）。
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixedUser);

  final UserInfo? _fixedUser;

  @override
  Future<UserInfo?> build() async => _fixedUser;
}

/// 記錄有沒有被要求走瀏覽器登入（不開真的瀏覽器）。
/// 受保護的憑證還沒解鎖（冷啟動時取消了生物辨識）。
class _LockedNotifier extends AuthLockedNotifier {
  @override
  bool build() => true;
}

class _BrowserLoginSpyNotifier extends AuthNotifier {
  _BrowserLoginSpyNotifier({this.failWith});

  final OAuthLoginException? failWith;
  int signInCount = 0;
  int unlockCount = 0;

  /// 非 null 時登入／解鎖會卡住直到完成（模擬進行中）。
  Completer<void>? gate;
  // 非 null 時 unlock() 成功並登入為此使用者；null 表示取消（維持未登入）。
  UserInfo? unlockAs;

  @override
  Future<UserInfo?> build() async => null;

  @override
  Future<InvalidReason?> unlock() async {
    unlockCount++;
    await gate?.future;
    state = AsyncData(unlockAs);
    return null;
  }

  @override
  Future<bool> signInWithBrowser({String? biometricHint}) async {
    signInCount++;
    await gate?.future;
    final error = failWith;
    // 與正式的 signInWithBrowser 一致：取消回到未登入、不算錯誤。
    if (error != null) {
      state = error.cancelled
          ? const AsyncData(null)
          : AsyncError(error, StackTrace.empty);
    }
    return false;
  }
}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// 瀏覽器登入以未預期的例外結束（不是 OAuthLoginException）。
class _ThrowingSignInNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => null;

  @override
  Future<bool> signInWithBrowser({String? biometricHint}) async =>
      throw StateError('boom');
}

/// 模擬受保護憑證：沒解開前每次讀取都算一次系統驗證（Face ID），
/// 依序消耗 [script]（false = 取消，丟鎖定例外）；解開後與正式 store 一樣走快取。
class _ScriptedStore extends InMemoryOAuthTokenStore {
  _ScriptedStore(this.script);

  final List<bool> script;
  int prompts = 0;
  bool _open = false;

  @override
  Future<OAuthTokens?> read() async {
    if (!_open) {
      prompts++;
      final ok = script.isEmpty || script.removeAt(0);
      if (!ok) throw const TokenStoreLockedException();
      _open = true;
    }
    return super.read();
  }

  @override
  Future<void> lock() async {
    _open = false;
    await super.lock();
  }
}

/// 不連網的 refresh：預設輪替成功；[rejectRefresh] 為 true 時模擬伺服器拒絕（撤銷、過期）。
class _RefreshingOAuthRepository extends RecordingOAuthRepository {
  bool rejectRefresh = false;
  int refreshes = 0;

  @override
  Future<OAuthTokens> refresh({
    required String refreshToken,
    required String clientId,
    ProofKey? proofKey,
  }) async {
    refreshes++;
    if (rejectRefresh) {
      throw const ApiError(status: 400, code: 'invalid_grant', message: 'x');
    }
    return OAuthTokens(
      accessToken: 'AT2',
      refreshToken: '${refreshToken}2',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }
}

class _MockTripRepository extends Mock implements TripRepository {}

class _MockAccountRepository extends Mock implements AccountRepository {}

class _MockCollabRepository extends Mock implements CollabRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

class _MockRequestsRepository extends Mock implements RequestsRepository {}

class _RecordingPrintActions implements TripPrintActions {
  final printed = <TripPrintData>[];

  @override
  Future<bool> print(TripPrintData data) async {
    printed.add(data);
    return true;
  }

  @override
  Future<bool> sharePdf(TripPrintData data) async => true;
}

const _loggedInUser = UserInfo(
  id: 'user-1',
  email: 'traveler@example.com',
  emailVerified: true,
  displayName: 'Ray',
);

const _entry = TimelineEntry(id: 11, sortOrder: 0, title: '首里城', version: 2);

ProviderContainer _buildContainer({
  required UserInfo? currentUser,
  List<TripSummary>? trips,
  List<TripDay>? days,
  AuthRepository? authRepository,
  RequestsRepository? requestsRepository,
  TripPrintActions? printActions,
  bool resolveAuthFromRepository = false,
  bool disableAutomaticRetry = false,
  List<dynamic> extraOverrides = const [],
  AuthNotifier Function()? authNotifier,
}) {
  final mockTripRepository = _MockTripRepository();
  final mockAccountRepository = _MockAccountRepository();
  final mockCollabRepository = _MockCollabRepository();
  final mockFavoritesRepository = _MockFavoritesRepository();
  when(mockTripRepository.fetchMyTrips).thenAnswer((_) async => []);
  when(
    () => mockTripRepository.fetchPublicTripShare(any()),
  ).thenAnswer((_) async => const PublicTripShare(name: 'public-trip'));
  when(
    () => mockTripRepository.fetchTrip(any()),
  ).thenAnswer((_) async => const Trip(id: 'trip-1', name: 'print-trip'));
  when(
    () => mockTripRepository.fetchDays(any()),
  ).thenAnswer((_) async => <TripDay>[]);
  when(
    () => mockTripRepository.fetchDaySummaries(any()),
  ).thenAnswer((_) async => <TripDay>[]);
  when(mockTripRepository.watchMyTrips).thenAnswer(
    (_) => Stream.value(
      trips ?? const [TripSummary(tripId: 'trip-1', name: '沖繩')],
    ),
  );
  when(() => mockTripRepository.watchDays(any())).thenAnswer(
    (_) => Stream.value(days ?? const [TripDay(id: 1, dayNum: 1, version: 0)]),
  );
  when(
    () => mockTripRepository.watchEntry(
      tripId: any(named: 'tripId'),
      entryId: any(named: 'entryId'),
    ),
  ).thenAnswer((_) => Stream.value(_entry));
  when(
    () => mockTripRepository.fetchNotes(any()),
  ).thenAnswer((_) async => const TripNotes());
  when(
    () => mockTripRepository.watchNotes(any()),
  ).thenAnswer((_) => Stream.value(const TripNotes()));
  when(
    () => mockTripRepository.fetchHealthReport(any()),
  ).thenAnswer((_) async => null);
  when(
    () => mockTripRepository.fetchAuditLog(
      any(),
      limit: any(named: 'limit'),
      requestId: any(named: 'requestId'),
    ),
  ).thenAnswer((_) async => const <TripAuditRow>[]);
  when(() => mockTripRepository.fetchPoiHealth(any())).thenAnswer(
    (_) async => const TripPoiHealthReport(version: 1, closed: 0, missing: 0),
  );
  when(() => mockCollabRepository.fetchInvitation(any())).thenAnswer(
    (_) async => const InvitationDetails(
      tripId: 'trip-1',
      tripTitle: '沖繩家庭旅行',
      invitedEmail: 'traveler@example.com',
      inviterDisplayName: 'Ray',
      inviterEmail: 'ray@example.com',
      expiresAt: '2026-07-16T00:00:00.000Z',
    ),
  );
  when(
    () => mockCollabRepository.fetchMembers(any()),
  ).thenAnswer((_) async => []);
  when(
    () => mockCollabRepository.fetchInvites(any()),
  ).thenAnswer((_) async => []);
  when(
    mockFavoritesRepository.fetchFavorites,
  ).thenAnswer((_) async => const []);

  final container = ProviderContainer(
    retry: disableAutomaticRetry ? (_, _) => null : null,
    overrides: [
      // Account sheet 掛載時會取 hasPassword（決定是否顯示「變更密碼」）；路由測試與它無關，預設隔離掉。
      accountHasPasswordProvider.overrideWith((ref) async => false),
      ...extraOverrides,
      if (authRepository != null)
        authRepositoryProvider.overrideWithValue(authRepository),
      if (!resolveAuthFromRepository)
        authStateProvider.overrideWith(
          authNotifier ?? () => _FakeAuthNotifier(currentUser),
        ),
      if (requestsRepository != null)
        requestsRepositoryProvider.overrideWithValue(requestsRepository),
      if (printActions != null)
        tripPrintActionsProvider.overrideWithValue(printActions),
      tripRepositoryProvider.overrideWithValue(mockTripRepository),
      accountRepositoryProvider.overrideWithValue(mockAccountRepository),
      collabRepositoryProvider.overrideWithValue(mockCollabRepository),
      favoritesRepositoryProvider.overrideWithValue(mockFavoritesRepository),
      tripMapCanvasBuilderProvider.overrideWithValue(fakeTripMapBuilder),
      appNetworkAvailabilityProvider.overrideWithValue(const Stream.empty()),
    ],
  );
  return container;
}

// 歡迎頁介紹內容「露出」＝標題在樹上且沒有被登入進度畫面蓋住。
bool welcomeExposed(WidgetTester tester) =>
    find.byKey(const ValueKey('welcome-headline')).evaluate().isNotEmpty &&
    find.byKey(const ValueKey('welcome-login-progress')).evaluate().isEmpty;

void main() {
  testWidgets('舊路徑經 GoRouter 到達行程與停留點畫面', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);

    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.byType(TripsListScreen), findsOneWidget);

    router.go('/trip/trip-1/stop/11/map');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TripMapScreen>(find.byType(TripMapScreen)).initialEntryId,
      11,
    );

    router.go('/trip/trip-1/stop/11/edit');
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditRouteScreen), findsOneWidget);
  });

  testWidgets('無效停留點 deep link 顯示可返回畫面且不讀取停留點', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = container.read(tripRepositoryProvider);
    for (final id in [
      'nope',
      '',
      '0',
      '-1',
      '9223372036854775808',
      '0x10',
      '%20',
      '1.5',
    ]) {
      for (final paths in [
        ['/trips/trip-1/entries/$id/edit', '/trip/trip-1/stop/$id/edit'],
        ['/trips/trip-1/entries/$id/copy', '/trip/trip-1/stop/$id/copy'],
        ['/trips/trip-1/entries/$id/move', '/trip/trip-1/stop/$id/move'],
        ['/trips/trip-1/entries/$id/pois', '/trip/trip-1/stop/$id/change-poi'],
      ]) {
        for (final path in paths) {
          container.read(appRouterProvider).go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
          expect(find.text('無法開啟連結'), findsOneWidget, reason: path);
          verifyNever(
            () => repository.watchEntry(
              tripId: any(named: 'tripId'),
              entryId: any(named: 'entryId'),
            ),
          );
        }
      }
    }
    await tester.tap(find.text('返回行程列表'));
    await tester.pumpAndSettle();
    expect(find.byType(TripsListScreen), findsOneWidget);
  });

  testWidgets('有效停留點 ID 原值傳入 canonical 與 alias 畫面', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    for (final prefix in ['/trips/trip-1/entries', '/trip/trip-1/stop']) {
      for (final action in ['edit', 'copy', 'move', 'pois']) {
        final suffix = prefix.startsWith('/trip/') && action == 'pois'
            ? 'change-poi'
            : action;
        router.go('$prefix/11/$suffix');
        await tester.pumpAndSettle();
        final int entryId;
        if (action == 'edit') {
          entryId = tester
              .widget<EntryEditRouteScreen>(find.byType(EntryEditRouteScreen))
              .entryId;
        } else if (action == 'pois') {
          entryId = tester
              .widget<EntryPoiScreen>(find.byType(EntryPoiScreen))
              .entryId;
        } else {
          entryId = tester
              .widget<EntryActionRouteScreen>(
                find.byType(EntryActionRouteScreen),
              )
              .entryId;
        }
        expect(entryId, 11);
        expect(find.text('無法開啟連結'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
    router.go('/trips/trip-1/entries/9223372036854775807/edit');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EntryEditRouteScreen>(find.byType(EntryEditRouteScreen))
          .entryId,
      9223372036854775807,
    );
  });

  testWidgets('停留點新增／編輯／複製／移動是 shell 外整頁 modal,沒有分頁列', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/trips/trip-1');
    await tester.pumpAndSettle();
    expect(find.byType(AppleRootTabBar), findsOneWidget, reason: '對照:行程頁有分頁列');
    for (final entry in {
      '/trips/trip-1/entries/new?day=1&mode=search': EntryAddRouteScreen,
      '/trip/trip-1/add-stop': EntryAddRouteScreen,
      '/trips/trip-1/entries/11/edit': EntryEditRouteScreen,
      '/trip/trip-1/stop/11/edit': EntryEditRouteScreen,
      '/trips/trip-1/entries/11/copy': EntryActionRouteScreen,
      '/trip/trip-1/stop/11/copy': EntryActionRouteScreen,
      '/trips/trip-1/entries/11/move': EntryActionRouteScreen,
      '/trip/trip-1/stop/11/move': EntryActionRouteScreen,
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
      expect(find.byType(AppleRootTabBar), findsNothing, reason: entry.key);
    }
    // 返回堆疊:push 進來,pop 回到進入前的行程頁(分頁列回來)。
    router.go('/trips/trip-1');
    await tester.pumpAndSettle();
    unawaited(router.push('/trips/trip-1/entries/11/edit'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditRouteScreen), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditRouteScreen), findsNothing);
    expect(find.byType(AppleRootTabBar), findsOneWidget);
  });

  testWidgets('重設新 token 隔離舊請求與成功狀態', (tester) async {
    final auth = _MockAuthRepository();
    final pending = Completer<String?>();
    when(
      () => auth.resetPassword(token: 'old-token', password: 'password123'),
    ).thenAnswer((_) => pending.future);
    when(
      () => auth.resetPassword(token: 'new-token', password: 'new-password'),
    ).thenAnswer((_) async => null);
    final container = _buildContainer(currentUser: null, authRepository: auth);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/auth/password/reset?token=old-token');
    await tester.pumpAndSettle();
    for (final key in [
      'reset-password-field',
      'reset-password-confirm-field',
    ]) {
      await tester.enterText(find.byKey(ValueKey(key)), 'password123');
    }
    final submit = find.byKey(const ValueKey('reset-password-submit-button'));
    await tester.tap(submit);
    await tester.pump();
    verify(
      () => auth.resetPassword(token: 'old-token', password: 'password123'),
    ).called(1);
    router.go('/auth/password/reset?token=new-token');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('更新中…'), findsNothing);
    final field = find.byKey(const ValueKey('reset-password-field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'new-password');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    tester.testTextInput.log.clear();

    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-password-success')), findsNothing);
    expect(find.text('new-password'), findsOneWidget);
    expect(
      tester.testTextInput.log.where(
        (call) =>
            call.method == 'TextInput.finishAutofillContext' &&
            call.arguments == true,
      ),
      isEmpty,
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password-confirm-field')),
      'new-password',
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reset-password-success')),
      findsOneWidget,
    );
    verify(
      () => auth.resetPassword(token: 'new-token', password: 'new-password'),
    ).called(1);
    router.go('/auth/password/reset?token=third-token');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-password-success')), findsNothing);
    expect(field, findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('驗證中的舊 token 回應不污染新連結', (tester) async {
    final auth = _MockAuthRepository();
    final pending = Completer<bool>();
    when(() => auth.verifyEmail('old-token')).thenAnswer((_) => pending.future);
    when(() => auth.verifyEmail('new-token')).thenAnswer((_) async => true);
    final container = _buildContainer(currentUser: null, authRepository: auth);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/auth/verify-email?token=old-token');
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('verify-email-confirm-button'));
    await tester.tap(submit);
    await tester.pump();
    verify(() => auth.verifyEmail('old-token')).called(1);
    router.go('/auth/verify-email?token=new-token');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('確認信箱驗證'), findsOneWidget);
    expect(find.text('驗證中…'), findsNothing);
    expect(submit, findsOneWidget);

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('verify-email-success')), findsNothing);
    expect(find.byKey(const ValueKey('verify-email-error')), findsNothing);
    expect(submit, findsOneWidget);
    verifyNever(() => auth.verifyEmail('new-token'));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    verify(() => auth.verifyEmail('new-token')).called(1);
    expect(find.byKey(const ValueKey('verify-email-success')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新的重設連結不保留舊 token 錯誤與密碼', (tester) async {
    final auth = _MockAuthRepository();
    when(
      () => auth.resetPassword(token: 'old-token', password: 'password123'),
    ).thenThrow(
      const ApiError(
        status: 400,
        code: 'RESET_TOKEN_INVALID',
        message: 'invalid',
      ),
    );
    final container = _buildContainer(currentUser: null, authRepository: auth);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/auth/password/reset?token=old-token');
    await tester.pumpAndSettle();
    for (final key in [
      'reset-password-field',
      'reset-password-confirm-field',
    ]) {
      await tester.enterText(find.byKey(ValueKey(key)), 'password123');
    }
    await tester.tap(
      find.byKey(const ValueKey('reset-password-submit-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('重設連結無效或已過期'), findsOneWidget);
    expect(find.text('重新申請'), findsOneWidget);

    router.go('/auth/password/reset?token=new-token');
    await tester.pumpAndSettle();
    expect(find.text('重設連結無效或已過期'), findsNothing);
    expect(find.text('重新申請'), findsNothing);
    for (final key in [
      'reset-password-field',
      'reset-password-confirm-field',
    ]) {
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        isEmpty,
      );
    }
    verify(
      () => auth.resetPassword(token: 'old-token', password: 'password123'),
    ).called(1);
    verifyNever(
      () => auth.resetPassword(
        token: 'new-token',
        password: any(named: 'password'),
      ),
    );
  });

  for (final user in [null, _loggedInUser]) {
    testWidgets('驗證重新開始依登入狀態前往有效目的地：${user?.id ?? "未登入"}', (tester) async {
      final container = _buildContainer(currentUser: user);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      router.go('/auth/verify-email');
      await tester.pumpAndSettle();
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      await tester.tap(find.text('重新開始'));
      await tester.pumpAndSettle();
      expect(find.byType(VerifyEmailScreen), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.path,
        user == null ? '/welcome' : '/trips',
      );
      expect(
        find.byType(user == null ? WelcomeScreen : TripsListScreen),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('開啟新的驗證連結會離開舊 token 的失效狀態', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/auth/verify-email');
    await tester.pumpAndSettle();
    expect(find.text('重新開始'), findsOneWidget);
    router.go('/auth/verify-email?token=new-token');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('verify-email-confirm-button')),
      findsOneWidget,
    );
    expect(find.text('重新開始'), findsNothing);
  });

  testWidgets('未登入時 redirect 到 /welcome', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(TripsListScreen), findsNothing);
  });

  testWidgets('Welcome 登入鈕直接開瀏覽器登入，不再多繞一頁登入畫面', (tester) async {
    final spy = _BrowserLoginSpyNotifier();
    final container = _buildContainer(
      currentUser: null,
      authNotifier: () => spy,
      extraOverrides: [
        // 登入入口會先問生物辨識種類；真平台通道在 pump 內不會完成。
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(kind: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
    await tester.pumpAndSettle();

    expect(spy.signInCount, 1);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('未登入 deep link 經 Welcome 直接登入後回到原目的地', (tester) async {
    final auth = _MockAuthRepository();
    var signedIn = false;
    when(
      auth.currentUser,
    ).thenAnswer((_) async => signedIn ? _loggedInUser : null);
    final container = _buildContainer(
      currentUser: null,
      authRepository: auth,
      resolveAuthFromRepository: true,
      extraOverrides: fakeBrowserLoginOverrides(onLogin: () => signedIn = true),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/chat?tripId=trip-1');
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/chat?tripId=trip-1',
    );
  });

  // 憑證被鎖（已開啟生物辨識登入、冷啟動取消驗證）：歡迎頁登入鈕直接解鎖，不開瀏覽器。
  for (final key in ['welcome-login-top', 'welcome-login-hero']) {
    Future<_BrowserLoginSpyNotifier> pumpLocked(
      WidgetTester tester, {
      BiometricKind kind = BiometricKind.faceId,
      void Function(_BrowserLoginSpyNotifier)? configure,
    }) async {
      final spy = _BrowserLoginSpyNotifier();
      configure?.call(spy);
      final container = _buildContainer(
        currentUser: null,
        authNotifier: () => spy,
        extraOverrides: [
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(kind: null),
          ),
          authLockedProvider.overrideWith(_LockedNotifier.new),
          biometricLoginKindProvider.overrideWith((ref) async => kind),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      return spy;
    }

    testWidgets('Welcome 憑證被鎖且支援生物辨識（$key）：直接解鎖並進入 App，不經登入畫面', (tester) async {
      final spy = await pumpLocked(
        tester,
        configure: (s) => s.unlockAs = _loggedInUser,
      );

      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();

      expect(spy.unlockCount, 1);
      expect(spy.signInCount, 0, reason: '不得開瀏覽器');
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('Welcome 解鎖取消或失敗（$key）：同一次按下開 web 登入頁、不顯示錯誤（ADR-0020）', (
      tester,
    ) async {
      final spy = await pumpLocked(tester);

      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();

      expect(spy.unlockCount, 1);
      expect(spy.signInCount, 1, reason: '生物辨識取消或失敗就開 web 登入頁');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(welcomeExposed(tester), isTrue, reason: 'web 也沒登入：進度畫面要撤掉');
      expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);

      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(spy.unlockCount, 2, reason: '憑證還被鎖：再按一次仍先解鎖');
    });

    testWidgets('Welcome 憑證被鎖但只有裝置密碼（$key）：照舊直接開瀏覽器', (tester) async {
      final spy = await pumpLocked(tester, kind: BiometricKind.passcode);

      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();

      expect(spy.unlockCount, 0);
      expect(spy.signInCount, 1);
    });
  }

  testWidgets('Welcome 直接登入失敗：留在歡迎頁顯示錯誤，可重試', (tester) async {
    final spy = _BrowserLoginSpyNotifier(failWith: OAuthLoginException('boom'));
    final container = _buildContainer(
      currentUser: null,
      authNotifier: () => spy,
      extraOverrides: [
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(kind: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(
      container.read(appRouterProvider).state.uri.path,
      '/welcome',
      reason: '不得再導向 /login',
    );
    expect(find.text('Tripline 登入失敗，請稍後再試'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
    await tester.pumpAndSettle();
    expect(spy.signInCount, 2);
  });

  testWidgets('Welcome 瀏覽器登入使用者取消：不顯示錯誤', (tester) async {
    final container = _buildContainer(
      currentUser: null,
      authNotifier: () => _BrowserLoginSpyNotifier(
        failWith: OAuthLoginException(
          '使用者取消登入',
          userMessage: '已取消登入',
          cancelled: true,
        ),
      ),
      extraOverrides: [
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(kind: null),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('已取消登入'), findsNothing);
    expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
  });

  testWidgets('Welcome 的「建立帳號」入口導向 /signup', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-signup')));
    await tester.pumpAndSettle();

    expect(container.read(appRouterProvider).state.uri.path, '/signup');
    expect(find.byType(SignupScreen), findsOneWidget);
  });

  for (final locked in [false, true]) {
    testWidgets('登入進行中禁止重複觸發（${locked ? "解鎖" : "瀏覽器登入"}只啟動一次）', (tester) async {
      final gate = Completer<void>();
      // 解鎖成功（取消會接著開 web 登入頁，這裡只看重複觸發）。
      final spy = _BrowserLoginSpyNotifier()
        ..gate = gate
        ..unlockAs = locked ? _loggedInUser : null;
      final container = _buildContainer(
        currentUser: null,
        authNotifier: () => spy,
        extraOverrides: [
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(kind: null),
          ),
          if (locked) ...[
            authLockedProvider.overrideWith(_LockedNotifier.new),
            biometricLoginKindProvider.overrideWith(
              (ref) async => BiometricKind.faceId,
            ),
          ],
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();
      // 進度畫面會蓋住按鈕，連點只能直接呼叫 onPressed（等同兩次點擊事件連發）。
      final onLogin = tester
          .widget<TextButton>(find.byKey(const ValueKey('welcome-login-top')))
          .onPressed!;

      onLogin();
      onLogin();
      await tester.pump();
      onLogin();
      await tester.pump(const Duration(milliseconds: 50));
      gate.complete();
      await tester.pumpAndSettle();

      expect(locked ? spy.unlockCount : spy.signInCount, 1);
      expect(locked ? spy.signInCount : spy.unlockCount, 0);
    });
  }

  group('/login 轉址到 /welcome', () {
    for (final entry in {
      '/login': '/welcome',
      '/login?redirect_after=%2Fmap': '/welcome?redirect_after=%2Fmap',
      '/login?verified=1': '/welcome?verified=1',
      '/login?redirect_after=https%3A%2F%2Fevil.example': '/welcome',
    }.entries) {
      testWidgets('未登入 ${entry.key} → ${entry.value}', (tester) async {
        final container = _buildContainer(currentUser: null);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TriplineApp(),
          ),
        );
        await tester.pumpAndSettle();
        final router = container.read(appRouterProvider);

        router.go(entry.key);
        await tester.pumpAndSettle();

        expect(router.state.uri.toString(), entry.value);
        expect(find.byType(WelcomeScreen), findsOneWidget);
      });
    }

    testWidgets('verified=1 的歡迎頁顯示信箱已驗證提示', (tester) async {
      final container = _buildContainer(currentUser: null);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();

      container.read(appRouterProvider).go('/login?verified=1');
      await tester.pumpAndSettle();

      expect(find.text('信箱已驗證，請登入繼續。'), findsOneWidget);
    });

    testWidgets('一般歡迎頁不顯示信箱已驗證提示', (tester) async {
      final container = _buildContainer(currentUser: null);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('信箱已驗證，請登入繼續。'), findsNothing);
    });
  });

  /// 逐格推進並確認每一格都沒有露出歡迎頁，回傳檢查過的格數。
  Future<int> pumpFramesNeverExposingWelcome(WidgetTester tester) async {
    var frames = 0;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
      expect(welcomeExposed(tester), isFalse, reason: '第 $i 格露出歡迎頁');
    }
    return frames;
  }

  testWidgets('瀏覽器登入成功：從按下到落在 /trips 的每一格都不露出歡迎頁', (tester) async {
    final auth = _MockAuthRepository();
    var signedIn = false;
    when(
      auth.currentUser,
    ).thenAnswer((_) async => signedIn ? _loggedInUser : null);
    final container = _buildContainer(
      currentUser: null,
      authRepository: auth,
      resolveAuthFromRepository: true,
      extraOverrides: fakeBrowserLoginOverrides(onLogin: () => signedIn = true),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(welcomeExposed(tester), isTrue, reason: '按之前歡迎頁正常顯示');

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pump();
    expect(welcomeExposed(tester), isFalse, reason: '按下的下一格就要蓋住');
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('welcome-login-progress')),
          )
          .properties
          .label,
      '登入中',
    );
    final frames = await pumpFramesNeverExposingWelcome(tester);

    expect(frames, 80);
    expect(find.byType(TripsListScreen), findsOneWidget);
    expect(container.read(appRouterProvider).state.uri.path, '/trips');
  });

  testWidgets('瀏覽器登入被取消或失敗：進度畫面消失，回到歡迎頁', (tester) async {
    for (final cancelled in [true, false]) {
      final container = _buildContainer(
        currentUser: null,
        authNotifier: () => _BrowserLoginSpyNotifier(
          failWith: OAuthLoginException('boom', cancelled: cancelled),
        ),
        extraOverrides: [
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(kind: null),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
      await tester.pumpAndSettle();

      expect(
        welcomeExposed(tester),
        isTrue,
        reason: 'cancelled=$cancelled：要回到歡迎頁內容',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('登入流程以例外結束也會復原，不卡在進度畫面', (tester) async {
    final container = _buildContainer(
      currentUser: null,
      authNotifier: () => _ThrowingSignInNotifier(),
      extraOverrides: [
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(kind: null),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(welcomeExposed(tester), isTrue);
  });

  group('冷啟動與解鎖流程（真實 AuthNotifier + 受保護憑證）', () {
    const user = UserInfo(id: 'u1', email: 'ray@example.com');

    Future<
      ({
        ProviderContainer container,
        _ScriptedStore store,
        FakeBiometricAuthenticator bio,
        _RefreshingOAuthRepository oauth,
        int Function() browserLogins,
      })
    >
    coldStart(
      WidgetTester tester, {
      required List<bool> prompts,
      bool appLock = false,
      bool legacyKept = false,
      bool rejectRefresh = false,
      bool settle = true,
      Object? loginError,
    }) async {
      final store = _ScriptedStore(prompts);
      await store.write(
        OAuthTokens(
          accessToken: 'AT',
          refreshToken: 'RT',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
      );
      await store.setProtection(TokenProtection.biometric);
      if (legacyKept) {
        store.legacyKeptMarker = true;
        await store.lock();
      }
      final bio = FakeBiometricAuthenticator();
      final oauth = _RefreshingOAuthRepository()..rejectRefresh = rejectRefresh;
      final auth = _MockAuthRepository();
      when(auth.currentUser).thenAnswer((_) async => user);
      FakeOAuthLoginService? login;
      final container = _buildContainer(
        currentUser: null,
        authRepository: auth,
        resolveAuthFromRepository: true,
        extraOverrides: [
          oauthTokenStoreProvider.overrideWithValue(store),
          oauthRepositoryProvider.overrideWithValue(oauth),
          proofKeyStoreProvider.overrideWithValue(InMemoryProofKeyStore()),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          if (appLock)
            appLockProvider.overrideWith(
              () => AppLockController(initialEnabled: true),
            ),
          ...fakeBrowserLoginOverrides(
            stubBiometric: false,
            error: loginError,
            created: (s) => login = s,
          ),
          biometricAuthenticatorProvider.overrideWithValue(bio),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      if (settle) await tester.pumpAndSettle();
      return (
        container: container,
        store: store,
        bio: bio,
        oauth: oauth,
        browserLogins: () => login?.calls ?? 0,
      );
    }

    final lockScreen = find.byKey(const ValueKey('app-lock-screen'));

    testWidgets('憑證被鎖只是還沒解開，不是登出：App 鎖設定不被清掉，解鎖後也只驗一次', (tester) async {
      final r = await coldStart(tester, prompts: [false, true], appLock: true);
      expect(r.container.read(appLockProvider).enabled, isTrue);

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(find.byType(TripsListScreen), findsOneWidget);
      expect(lockScreen, findsNothing);
      expect(r.container.read(appLockProvider).enabled, isTrue);
      expect(r.bio.authenticateCalls, 0);
    });

    testWidgets('兩套鎖都開、冷啟動憑證解鎖通過：不出現 App 鎖畫面，Face ID 總共一次', (tester) async {
      final r = await coldStart(tester, prompts: [true], appLock: true);

      expect(find.byType(TripsListScreen), findsOneWidget);
      expect(lockScreen, findsNothing);
      expect(r.store.prompts + r.bio.authenticateCalls, 1);
    });

    testWidgets('只開 App 鎖（憑證不受生物辨識保護）：App 鎖照常出現', (tester) async {
      final store = InMemoryOAuthTokenStore();
      await store.write(
        OAuthTokens(
          accessToken: 'AT',
          refreshToken: 'RT',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
      );
      final auth = _MockAuthRepository();
      when(auth.currentUser).thenAnswer((_) async => user);
      final bio = FakeBiometricAuthenticator(
        outcomes: [BiometricOutcome.cancelled],
      );
      final container = _buildContainer(
        currentUser: null,
        authRepository: auth,
        resolveAuthFromRepository: true,
        extraOverrides: [
          oauthTokenStoreProvider.overrideWithValue(store),
          proofKeyStoreProvider.overrideWithValue(InMemoryProofKeyStore()),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          appLockProvider.overrideWith(
            () => AppLockController(initialEnabled: true),
          ),
          biometricAuthenticatorProvider.overrideWithValue(bio),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(lockScreen, findsOneWidget);
    });

    testWidgets('冷啟動 Face ID 被取消：停在歡迎頁，不會自動再跳第二次；按登入鈕才再解鎖', (tester) async {
      final r = await coldStart(tester, prompts: [false, true]);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(welcomeExposed(tester), isTrue, reason: '不蓋進度畫面，等使用者按');
      expect(r.store.prompts, 1, reason: '只有啟動讀取的那一次');
      expect(r.bio.authenticateCalls, 0);
      expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(r.store.prompts, 2);
      expect(r.browserLogins(), 0, reason: '憑證被鎖時按登入是解鎖，不是開瀏覽器');
      expect(find.byType(TripsListScreen), findsOneWidget);
    });

    testWidgets('冷啟動 Face ID 通過即 refresh 並進「我的行程」，不經歡迎頁', (tester) async {
      final r = await coldStart(tester, prompts: [true]);

      expect(find.byType(TripsListScreen), findsOneWidget);
      expect(r.oauth.refreshes, 1);
      expect(r.browserLogins(), 0);
    });

    testWidgets('冷啟動 Face ID 通過但 refresh 被拒：清除憑證停在歡迎頁；按登入開 web 登入頁', (
      tester,
    ) async {
      final r = await coldStart(tester, prompts: [true], rejectRefresh: true);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(await r.store.read(), isNull);
      expect(r.browserLogins(), 0, reason: '不自動開瀏覽器，等使用者按登入');

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(r.browserLogins(), 1);
    });

    testWidgets('取消後按登入：解鎖通過但 refresh 被拒 → 清除憑證並直接開 web 登入頁', (tester) async {
      final r = await coldStart(tester, prompts: [false, true]);
      r.oauth.rejectRefresh = true;

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(r.store.prompts, 2, reason: '按登入先再讀一次受保護憑證');
      expect(r.browserLogins(), 1, reason: '憑證失效：同一次按下直接開 web 登入頁');
      expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
    });

    testWidgets('解鎖成功：從按下到落在 /trips 每一格都不露出歡迎頁', (tester) async {
      await coldStart(tester, prompts: [false, true]);

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pump();
      expect(welcomeExposed(tester), isFalse);
      await pumpFramesNeverExposingWelcome(tester);

      expect(find.byType(TripsListScreen), findsOneWidget);
    });

    testWidgets('冷啟動憑證被鎖但只有裝置密碼：不自動解鎖，登入鈕走瀏覽器', (tester) async {
      final store = _ScriptedStore([false]);
      await store.write(
        OAuthTokens(
          accessToken: 'AT',
          refreshToken: 'RT',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
      );
      final auth = _MockAuthRepository();
      when(auth.currentUser).thenAnswer((_) async => null);
      FakeOAuthLoginService? login;
      final container = _buildContainer(
        currentUser: null,
        authRepository: auth,
        resolveAuthFromRepository: true,
        extraOverrides: [
          oauthTokenStoreProvider.overrideWithValue(store),
          proofKeyStoreProvider.overrideWithValue(InMemoryProofKeyStore()),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(kind: BiometricKind.passcode),
          ),
          oauthLoginServiceProvider.overrideWith(
            (ref) => login = FakeOAuthLoginService(
              ref.watch(bearerTokenSourceProvider),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TriplineApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.prompts, 1);

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(login?.calls, 1, reason: '只有裝置密碼：登入鈕走瀏覽器，不是解鎖');
    });

    testWidgets('開啟者登出後按登入：生物辨識讀取 → refresh → 進「我的行程」，不開瀏覽器', (tester) async {
      final r = await coldStart(tester, prompts: [true, true], appLock: true);
      expect(find.byType(TripsListScreen), findsOneWidget);
      final refreshesBefore = r.oauth.refreshes;

      await r.container.read(authStateProvider.notifier).logout();
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(r.store.prompts, 1, reason: '登出本身不跳驗證');
      expect(
        r.container.read(appLockProvider).enabled,
        isFalse,
        reason: '登出照舊關掉 App 鎖',
      );

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(r.store.prompts, 2, reason: '按登入直接跳生物辨識');
      expect(r.oauth.refreshes, refreshesBefore + 1, reason: '通過即 refresh');
      expect(r.browserLogins(), 0, reason: '不開 web 登入頁');
      expect(find.byType(TripsListScreen), findsOneWidget);
      expect(r.bio.authenticateCalls, 0, reason: '不重複驗證');
    });

    testWidgets('開啟者登出後按登入：解鎖通過但 refresh 被拒 → 清除保留的憑證並直接開 web 登入頁', (
      tester,
    ) async {
      final r = await coldStart(
        tester,
        prompts: [true, true],
        loginError: OAuthLoginException(
          '使用者取消登入',
          userMessage: '已取消登入',
          cancelled: true,
        ),
      );
      await r.container.read(authStateProvider.notifier).logout();
      await tester.pumpAndSettle();
      r.oauth.rejectRefresh = true;

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(r.browserLogins(), 1, reason: '憑證失效：同一次按下開 web 登入頁');
      expect(await r.store.hasLogoutKeep(), isFalse);
      expect(await r.store.read(), isNull, reason: '保留的憑證已清除');
      expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
    });

    testWidgets('開啟者登出後按登入、生物辨識取消：開 web 登入頁，保留的憑證仍在', (tester) async {
      final r = await coldStart(
        tester,
        prompts: [true, false],
        loginError: OAuthLoginException(
          '使用者取消登入',
          userMessage: '已取消登入',
          cancelled: true,
        ),
      );
      await r.container.read(authStateProvider.notifier).logout();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
      await tester.pumpAndSettle();

      expect(r.store.prompts, 2, reason: '先跳生物辨識');
      expect(r.browserLogins(), 1, reason: '取消就開 web 登入頁');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
      expect(await r.store.hasLogoutKeep(), isTrue, reason: '保留的憑證先不刪');
      expect((await r.store.read())?.refreshToken, isNotNull);
    });

    testWidgets('舊版登出後保留憑證的冷啟動：刪掉憑證、不跳驗證，停在歡迎頁', (tester) async {
      final r = await coldStart(tester, prompts: [true], legacyKept: true);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(r.store.prompts, 0);
      expect(r.bio.authenticateCalls, 0);
      expect(r.store.legacyKeptMarker, isFalse);
    });

    testWidgets('解鎖成功後落點是 /trips（沒有 redirect_after）', (tester) async {
      final r = await coldStart(tester, prompts: [false, true]);

      await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
      await tester.pumpAndSettle();

      expect(r.container.read(appRouterProvider).state.uri.path, '/trips');
    });

    testWidgets('解鎖成功後尊重站內 redirect_after', (tester) async {
      final r = await coldStart(tester, prompts: [false, true]);
      r.container.read(appRouterProvider).go('/map');
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('welcome-login-top')));
      await tester.pumpAndSettle();

      expect(r.container.read(appRouterProvider).state.uri.path, '/map');
    });
  });

  testWidgets('已登入導向 /welcome 會回 /trips', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/welcome');
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('已登入時進入 /trips（不停留 /login）', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
  });

  testWidgets('已登入導向 /login 會被 redirect 回 /trips', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/login');
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
  });

  testWidgets('已登入導向 /login?redirect_after 會回到安全站內路徑', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(appRouterProvider)
        .go('/login?redirect_after=%2Fs%2Fpublic-token');
    await tester.pumpAndSettle();

    expect(find.byType(PublicShareScreen), findsOneWidget);
  });

  testWidgets('已登入導向 /login 會忽略外部 redirect_after', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(appRouterProvider)
        .go('/login?redirect_after=https%3A%2F%2Fevil.example');
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
  });

  testWidgets('未登入可進入公開分享頁 /s/:token', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/s/public-token');
    await tester.pumpAndSettle();

    expect(find.byType(PublicShareScreen), findsOneWidget);
  });

  testWidgets('公開分享可列印，登入後返回同一連結並複製行程', (tester) async {
    final auth = _MockAuthRepository();
    final printActions = _RecordingPrintActions();
    var signedIn = false;
    when(
      auth.currentUser,
    ).thenAnswer((_) async => signedIn ? _loggedInUser : null);
    final container = _buildContainer(
      currentUser: null,
      authRepository: auth,
      resolveAuthFromRepository: true,
      extraOverrides: fakeBrowserLoginOverrides(onLogin: () => signedIn = true),
      printActions: printActions,
    );
    addTearDown(container.dispose);
    final repository = container.read(accountRepositoryProvider);
    when(
      () => repository.clonePublicTripShare('public-token'),
    ).thenAnswer((_) async => 'copied-trip');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/s/public-token');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('public-share-print')));
    await tester.pumpAndSettle();
    expect(printActions.printed, hasLength(1));
    expect(printActions.printed.single.displayTitle, 'public-trip');

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(
      router.state.uri.queryParameters['redirect_after'],
      '/s/public-token',
    );
    verifyNever(() => repository.clonePublicTripShare(any()));

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/s/public-token');
    expect(find.byType(PublicShareScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();
    verify(() => repository.clonePublicTripShare('public-token')).called(1);
    expect(router.state.uri.path, '/trips/copied-trip');
  });

  testWidgets('公開分享登入複製後，在複製出的行程列印並保留登入身分（#387 流程4）', (tester) async {
    final auth = _MockAuthRepository();
    final printActions = _RecordingPrintActions();
    var signedIn = false;
    when(
      auth.currentUser,
    ).thenAnswer((_) async => signedIn ? _loggedInUser : null);
    final container = _buildContainer(
      currentUser: null,
      authRepository: auth,
      resolveAuthFromRepository: true,
      extraOverrides: fakeBrowserLoginOverrides(onLogin: () => signedIn = true),
      printActions: printActions,
    );
    addTearDown(container.dispose);
    final repository = container.read(accountRepositoryProvider);
    when(
      () => repository.clonePublicTripShare('public-token'),
    ).thenAnswer((_) async => 'copied-trip');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/s/public-token');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/s/public-token');

    // 登入後回到同一個公開分享頁，列印仍可用，且不會因此離開分享頁。
    await tester.tap(find.byKey(const ValueKey('public-share-print')));
    await tester.pumpAndSettle();
    expect(printActions.printed, hasLength(1));
    expect(printActions.printed.single.displayTitle, 'public-trip');
    expect(router.state.uri.path, '/s/public-token');

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();
    verify(() => repository.clonePublicTripShare('public-token')).called(1);
    expect(router.state.uri.path, '/trips/copied-trip');

    // 複製出的行程：從功能選單進列印頁並列印，不再被導去登入。
    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-action-print')));
    await tester.pumpAndSettle();
    expect(find.byType(TripPrintScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-print-do')));
    await tester.pumpAndSettle();
    expect(printActions.printed, hasLength(2));
    expect(printActions.printed.last.displayTitle, 'print-trip');
  });

  testWidgets('未登入可進入邀請確認頁 /invite?token', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/invite?token=raw-token');
    await tester.pumpAndSettle();

    expect(find.byType(InviteScreen), findsOneWidget);
  });

  testWidgets('邀請登入後接受並從 Account 返回受邀行程', (tester) async {
    final auth = _MockAuthRepository();
    var signedIn = false;
    when(
      auth.currentUser,
    ).thenAnswer((_) async => signedIn ? _loggedInUser : null);
    final container = _buildContainer(
      currentUser: null,
      authRepository: auth,
      resolveAuthFromRepository: true,
      extraOverrides: fakeBrowserLoginOverrides(onLogin: () => signedIn = true),
    );
    addTearDown(container.dispose);
    final collab = container.read(collabRepositoryProvider);
    when(() => collab.acceptInvitation('raw-token')).thenAnswer(
      (_) async =>
          const InvitationAcceptResult(tripId: 'trip-1', tripTitle: '沖繩家庭旅行'),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/invite?token=raw-token');
    await tester.pumpAndSettle();
    expect(find.byType(InviteScreen), findsOneWidget);
    verify(() => collab.fetchInvitation('raw-token')).called(1);

    await tester.tap(find.byKey(const ValueKey('invite-login')));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(
      router.state.uri.queryParameters['redirect_after'],
      '/invite?token=raw-token',
    );
    verifyNever(() => collab.acceptInvitation(any()));

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/invite?token=raw-token');
    expect(find.byKey(const ValueKey('invite-accept')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invite-accept')));
    await tester.pumpAndSettle();
    verify(() => collab.acceptInvitation('raw-token')).called(1);
    expect(router.state.uri.path, '/trips/trip-1');
    expect(find.byType(TripTimelineScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsNothing);
    expect(router.state.uri.path, '/trips/trip-1');
    expect(find.byType(TripTimelineScreen), findsOneWidget);
  });

  testWidgets('cold-start public deep links do not show a fake Back', (
    tester,
  ) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    for (final location in ['/invite?token=abc', '/s/public-token']) {
      container.read(appRouterProvider).go(location);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    }
  });

  testWidgets('未登入可進入 signup、忘記密碼與 email 驗證 routes', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/signup?invitation=raw-token');
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);

    container
        .read(appRouterProvider)
        .go('/signup/check-email?email=traveler%40example.com');
    await tester.pumpAndSettle();

    expect(find.byType(EmailVerifyPendingScreen), findsOneWidget);

    container.read(appRouterProvider).go('/login/forgot');
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    container
        .read(appRouterProvider)
        .go('/auth/password/reset?token=reset-token');
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);

    container
        .read(appRouterProvider)
        .go('/auth/verify-email?token=verify-token');
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailScreen), findsOneWidget);
  });

  testWidgets('OAuth 同意連結只提示回原瀏覽器，不顯示授權參數', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(appRouterProvider)
        .go(
          '/oauth/consent?client_id=tp_alpha'
          '&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback'
          '&scope=openid%20email'
          '&state=secret-state'
          '&response_type=code',
        );
    await tester.pumpAndSettle();

    expect(find.text('請返回原本的瀏覽器，從該處重新完成授權。'), findsOneWidget);
    expect(find.text('返回行程列表'), findsOneWidget);
    expect(find.textContaining('secret-state'), findsNothing);
    expect(find.textContaining('app.example.com'), findsNothing);
  });

  testWidgets('已登入可進入 /trips/:tripId/print', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/print');
    await tester.pumpAndSettle();

    expect(find.byType(TripPrintScreen), findsOneWidget);
  });

  testWidgets('/chat query 會傳給 ChatScreen', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(appRouterProvider)
        .go('/chat?tripId=trip-1&prefill=%E5%AE%89%E6%8E%92%E6%99%9A%E9%A4%90');
    await tester.pump();

    final screen = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(screen.initialTripId, 'trip-1');
    expect(screen.initialPrefill, '安排晚餐');

    container
        .read(appRouterProvider)
        .go('/chat?tripId=trip-2&prefill=%E6%94%B9%E8%A1%8C%E7%A8%8B');
    await tester.pump();

    final updated = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(updated.initialTripId, 'trip-2');
    expect(updated.initialPrefill, '改行程');
    expect(updated.key, screen.key);

    container.read(appRouterProvider).go('/trips');
    await tester.pumpAndSettle();
  });

  testWidgets('已登入可進入 /trips/:tripId/notes 與 web alias', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/notes');
    await tester.pumpAndSettle();

    expect(find.byType(TripNotesScreen), findsOneWidget);
    expect(find.text('行程筆記'), findsOneWidget);

    container.read(appRouterProvider).go('/trip/trip-1/notes');
    await tester.pumpAndSettle();

    expect(find.byType(TripNotesScreen), findsOneWidget);
    expect(find.text('行程筆記'), findsOneWidget);
  });

  testWidgets('已登入可進入 /trips/:tripId/health 與 web alias', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/health');
    await tester.pumpAndSettle();

    expect(find.byType(TripHealthScreen), findsOneWidget);
    expect(find.byType(AppleRootTabBar), findsOneWidget);

    container.read(appRouterProvider).go('/trip/trip-1/health');
    await tester.pumpAndSettle();

    expect(find.byType(TripHealthScreen), findsOneWidget);
    expect(find.byType(AppleRootTabBar), findsOneWidget);
  });

  testWidgets('已登入可進入 /trips/:tripId/audit 與 web alias', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/audit');
    await tester.pumpAndSettle();

    expect(find.byType(TripAuditScreen), findsOneWidget);

    container.read(appRouterProvider).go('/trip/trip-1/audit');
    await tester.pumpAndSettle();

    expect(find.byType(TripAuditScreen), findsOneWidget);
  });

  testWidgets('舊行程 map alias 保留行程與 Day 及停留點並選中 root 地圖', (tester) async {
    final container = _buildContainer(
      currentUser: _loggedInUser,
      days: const [
        TripDay(id: 1, dayNum: 1, version: 0),
        TripDay(id: 2, dayNum: 2, version: 0),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/trip/trip-1/map?day=2&entry=11');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/map?day=2&entry=11&tripId=trip-1',
    );
    final screen = tester.widget<GlobalMapScreen>(find.byType(GlobalMapScreen));
    expect(screen.initialTripId, 'trip-1');
    expect(screen.initialDayNum, 2);
    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-map-day-selector')),
          )
          .value,
      2,
    );
    expect(screen.initialEntryId, 11);
    expect(
      tester
          .widget<AppleRootTabBar>(find.byType(AppleRootTabBar))
          .selectedIndex,
      2,
    );
  });

  testWidgets('已登入可使用 /trips selected/focus query deep link', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips?selected=trip-1');
    await tester.pumpAndSettle();

    expect(find.byType(TripTimelineScreen), findsOneWidget);

    container.read(appRouterProvider).go('/trips?selected=trip-1&focus=11');
    await tester.pumpAndSettle();

    final screen = tester.widget<TripTimelineScreen>(
      find.byType(TripTimelineScreen),
    );
    expect(screen.initialEntryId, 11);
  });

  testWidgets('已登入可進入 add-custom-stop web alias', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trip/trip-1/add-custom-stop?day=1');
    await tester.pumpAndSettle();

    expect(find.byType(EntryAddRouteScreen), findsOneWidget);
    expect(find.text('新增停留點'), findsWidgets);
    expect(find.byType(AppleRootTabBar), findsNothing);
  });

  testWidgets('已登入可進入 add-entry/add-stop web aliases', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trip/trip-1/add-entry?day=1');
    await tester.pumpAndSettle();

    expect(find.byType(EntryAddRouteScreen), findsOneWidget);
    expect(find.text('搜尋'), findsOneWidget);

    container.read(appRouterProvider).go('/trip/trip-1/add-stop?day=1');
    await tester.pumpAndSettle();

    expect(find.byType(EntryAddRouteScreen), findsOneWidget);
    expect(find.text('搜尋'), findsOneWidget);

    container
        .read(appRouterProvider)
        .go('/trip/trip-1/add-stop?day=1&region=%E6%B2%96%E7%B9%A9');
    await tester.pumpAndSettle();

    final regionalAddStop = tester.widget<EntryAddRouteScreen>(
      find.byType(EntryAddRouteScreen),
    );
    expect(regionalAddStop.initialRegion, '沖繩');

    container
        .read(appRouterProvider)
        .go('/trip/trip-1/add-stop?tab=favorites&day=1');
    await tester.pumpAndSettle();

    expect(find.byType(EntryAddRouteScreen), findsOneWidget);
    expect(find.text('收藏'), findsWidgets);
  });

  testWidgets('已登入的通知設定 route 與 web alias 進入 Account sheet', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/settings/notifications');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString(),
      '/trips',
    );

    container.read(appRouterProvider).go('/account/notifications');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('舊版個人資料與開發者 routes 進入 Account sheet 對應頁', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    for (final target in <(String, Type)>[
      ('/settings/profile', ProfileEditScreen),
      ('/settings/developer-apps', DeveloperAppsScreen),
      ('/settings/developer-apps/new', DeveloperAppNewScreen),
      ('/developer/apps/new', DeveloperAppNewScreen),
    ]) {
      router.go(target.$1);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
      expect(find.byType(target.$2), findsOneWidget);

      if (find
          .byKey(const ValueKey('app-large-sheet-close'))
          .evaluate()
          .isEmpty) {
        await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Account 儲存後認證刷新失敗仍保留新草稿，重試與關閉返回原聊天', (tester) async {
    final auth = _MockAuthRepository();
    final requests = _MockRequestsRepository();
    when(auth.currentUser).thenAnswer((_) async => _loggedInUser);
    when(auth.fetchAiAuthorization).thenAnswer((_) async => true);
    when(
      () => requests.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));
    final container = _buildContainer(
      currentUser: _loggedInUser,
      authRepository: auth,
      requestsRepository: requests,
      resolveAuthFromRepository: true,
      extraOverrides: signedInOverrides(),
      // 此測試驗證最終 error 的導航與草稿；自動 retry 不屬於此 seam。
      disableAutomaticRetry: true,
    );
    addTearDown(container.dispose);
    final pending = Completer<UserInfo>();
    final repository = container.read(accountRepositoryProvider);
    when(
      () => repository.updateProfile(displayName: 'A'),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/chat');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '原聊天草稿');
    router.go('/settings/profile?account_origin=%2Fchat');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/chat?account=profile&account_origin=%2Fchat',
    );
    final field = find.byKey(const ValueKey('profile-display-name'));
    await tester.enterText(field, 'A');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pump();
    await tester.enterText(field, 'B');
    when(auth.currentUser).thenThrow(Exception('refresh offline'));
    pending.complete(
      const UserInfo(
        id: 'user-1',
        email: 'traveler@example.com',
        displayName: 'A',
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.text('無法載入個人資料'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/chat?account=profile&account_origin=%2Fchat',
    );
    verify(() => repository.updateProfile(displayName: 'A')).called(1);
    verify(auth.currentUser).called(2);
    when(auth.currentUser).thenAnswer(
      (_) async => const UserInfo(
        id: 'user-1',
        email: 'traveler@example.com',
        displayName: 'A',
      ),
    );
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    verify(auth.currentUser).called(1);
    expect(find.text('無法載入個人資料'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tp-app-bar-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    await tester.tap(find.text('捨棄'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsNothing);
    expect(find.byType(AccountScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.toString(), '/chat');
    expect(find.text('原聊天草稿'), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('帳號安全與開發者 deep link 依序返回 Account 再關閉至原 branch', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('/favorites');
    await tester.pumpAndSettle();

    for (final target in <(String, Type)>[
      ('/account/sessions', AccountSessionsScreen),
      ('/account/connected-apps', ConnectedAppsScreen),
      ('/settings/developer-apps', DeveloperAppsScreen),
    ]) {
      router.go('${target.$1}?account_origin=%2Ffavorites');
      await tester.pumpAndSettle();

      expect(find.byType(target.$2), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byType(target.$2), findsNothing);
      await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/favorites');
    }
  });

  testWidgets('新增開發者應用 deep link 的 Back 先回應用清單再回 Account', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('/favorites');
    await tester.pumpAndSettle();
    router.go('/settings/developer-apps/new?account_origin=%2Ffavorites');
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperAppNewScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tp-app-bar-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DeveloperAppsScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AccountScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/favorites');
  });

  testWidgets('帳號 deep link 在四個 root tabs 上開啟並返回原 branch', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    for (final origin in ['/chat', '/trips', '/map', '/favorites']) {
      router.go(origin);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      if (origin == '/chat') {
        await tester.enterText(
          find.byKey(const ValueKey('chat-input')),
          '保留中的聊天草稿',
        );
      }
      router.go('/account?account_origin=${Uri.encodeComponent(origin)}');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
      expect(find.byType(AppleRootTabBar), findsOneWidget);
      expect(find.byKey(const ValueKey('root-tab-帳號')), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '$origin?account=root&account_origin=${Uri.encodeComponent(origin)}',
      );

      tester
          .widget<TpToolbarGlassButton>(
            find.byKey(const ValueKey('app-sheet-close')),
          )
          .onPressed!
          .call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('app-large-sheet')), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), origin);
      if (origin == '/chat') {
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat-input')))
              .controller!
              .text,
          '保留中的聊天草稿',
        );
      }
    }
  });

  testWidgets('行程搜尋、篩選與捲動位置通過 root tab 及詳情往返後仍保留', (tester) async {
    final trips = [
      for (var index = 0; index < 24; index++)
        TripSummary(
          tripId: 'trip-$index',
          name: 'trip-$index',
          title: '行程 $index',
          ownerUserId: _loggedInUser.id,
        ),
    ];
    final container = _buildContainer(currentUser: _loggedInUser, trips: trips);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('/trips');
    await tester.pumpAndSettle();

    final searchField = find.byKey(const ValueKey('trips-search-field'));
    await tester.enterText(searchField, '行程');
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const ValueKey('tp-root-scroll-view')),
      const Offset(0, -900),
      1600,
    );
    await tester.pumpAndSettle();

    final listScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('tp-root-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final listOffset = listScroll.position.pixels;
    expect(listOffset, greaterThan(0));

    tester.widget<AppleRootTabBar>(find.byType(AppleRootTabBar)).onSelected(3);
    await tester.pumpAndSettle();
    tester.widget<AppleRootTabBar>(find.byType(AppleRootTabBar)).onSelected(1);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/trips');
    final retainedSearchField = find.byKey(
      const ValueKey('trips-search-field'),
      skipOffstage: false,
    );
    expect(retainedSearchField, findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: retainedSearchField,
              matching: find.byType(EditableText, skipOffstage: false),
            ),
          )
          .controller
          .text,
      '行程',
    );
    expect(
      tester
          .widget<TpSegmentedControl<TripFilter>>(
            find.byType(TpSegmentedControl<TripFilter>, skipOffstage: false),
          )
          .value,
      TripFilter.mine,
    );
    expect(listScroll.position.pixels, closeTo(listOffset, 0.5));

    router.go('/trips/trip-1');
    await tester.pumpAndSettle();
    expect(find.byType(TripTimelineScreen), findsOneWidget);

    router.go('/trips');
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: retainedSearchField,
              matching: find.byType(EditableText, skipOffstage: false),
            ),
          )
          .controller
          .text,
      '行程',
    );
    expect(
      tester
          .widget<TpSegmentedControl<TripFilter>>(
            find.byType(TpSegmentedControl<TripFilter>, skipOffstage: false),
          )
          .value,
      TripFilter.mine,
    );
    expect(listScroll.position.pixels, closeTo(listOffset, 0.5));
  });

  testWidgets('1024pt regular width 下行程清單與時間軸關鍵控制維持可用', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = _buildContainer(
      currentUser: _loggedInUser,
      trips: const [
        TripSummary(
          tripId: 'trip-1',
          name: 'okinawa',
          title: '沖繩家庭旅行',
          ownerUserId: 'user-1',
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('/trips');
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-root-glass-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('trips-search-field')), findsOneWidget);
    expect(find.byType(TpSegmentedControl<TripFilter>), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('trips-search-field')),
      '沖繩',
    );
    await tester.pumpAndSettle();
    expect(find.text('沖繩家庭旅行'), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go('/trips/trip-1');
    await tester.pumpAndSettle();

    expect(find.byType(TripTimelineScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-root-glass-header')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('day-pill-1')), findsOneWidget);
    // 與 root tab「地圖」重複的 bar button 已移除。
    expect(find.byKey(const ValueKey('trip-timeline-map')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('day-pill-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell 外內容頁的帳號按鈕可開啟 Account sheet', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/collab/trip-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
  });

  testWidgets('關閉 Account sheet 保留目前 branch stack 與 DAY', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('/trips/trip-1?day=1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    expect(find.byType(TripTimelineScreen), findsOneWidget);
    expect(
      tester
          .widget<TripTimelineScreen>(find.byType(TripTimelineScreen))
          .initialDayNum,
      1,
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/trips/trip-1?day=1',
    );
  });

  testWidgets('root tab 切到地圖分支並沿用共用選取日，反向亦然', (tester) async {
    final container = _buildContainer(
      currentUser: _loggedInUser,
      days: const [
        TripDay(id: 1, dayNum: 1, version: 0),
        TripDay(id: 2, dayNum: 2, version: 0),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.bySemanticsLabel('地圖')));
    await tester.pumpAndSettle();

    expect(find.byType(GlobalMapScreen), findsOneWidget);
    final rootTab = tester.widget<AppleRootTabBar>(
      find.byType(AppleRootTabBar),
    );
    expect(rootTab.selectedIndex, 2);
    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-map-day-selector')),
          )
          .value,
      2,
    );

    await tester.tap(find.byKey(const ValueKey('trip-map-day-1')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider).dayNumFor('trip-1'), 1);
    await tester.tapAt(tester.getCenter(find.bySemanticsLabel('行程')));
    await tester.pumpAndSettle();

    expect(find.byType(TripTimelineScreen), findsOneWidget);
    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-timeline-view-day-selector')),
          )
          .value,
      1,
    );
  });

  testWidgets('地圖選「全部」後切回時間軸不會被打回第 1 天', (tester) async {
    final container = _buildContainer(
      currentUser: _loggedInUser,
      days: const [
        TripDay(id: 1, dayNum: 1, version: 0),
        TripDay(id: 2, dayNum: 2, version: 0),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.bySemanticsLabel('地圖')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('trip-map-day-selector')),
        matching: find.text('全部'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.bySemanticsLabel('行程')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-timeline-view-day-selector')),
          )
          .value,
      2,
    );
  });

  testWidgets('深連結指定的 day 優先於共用選取日', (tester) async {
    final container = _buildContainer(
      currentUser: _loggedInUser,
      days: const [
        TripDay(id: 1, dayNum: 1, version: 0),
        TripDay(id: 2, dayNum: 2, version: 0),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('/trips/trip-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-pill-2')));
    await tester.pumpAndSettle();

    router.go('/map?tripId=trip-1&day=1');
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TpHorizontalSelector<int>>(
            find.byKey(const ValueKey('trip-map-day-selector')),
          )
          .value,
      1,
    );
  });

  testWidgets('已登入的外觀 aliases 直接開啟同一外觀頁並保留返回與關閉行為', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);

    for (final alias in ['/account/appearance', '/settings/appearance']) {
      router.go('/trips');
      await tester.pumpAndSettle();
      router.go('$alias?account_origin=%2Ftrips');
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/trips?account=appearance&account_origin=%2Ftrips',
      );
      expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
      expect(find.byType(AppearanceScreen), findsOneWidget);

      if (alias == '/account/appearance') {
        await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
        await tester.pumpAndSettle();
        expect(find.byType(AccountScreen), findsOneWidget);
        expect(find.byType(AppearanceScreen), findsNothing);
      }

      final closeButtonKey = alias == '/account/appearance'
          ? const ValueKey('app-sheet-close')
          : const ValueKey('app-large-sheet-close');
      final closeButton = find.byKey(closeButtonKey).hitTestable();
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/trips',
      );
      expect(find.byKey(const ValueKey('app-large-sheet')), findsNothing);
    }
  });

  testWidgets('未登入的外觀 aliases 仍由既有認證規則導向 Welcome', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);

    for (final alias in ['/account/appearance', '/settings/appearance']) {
      router.go(alias);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(AppearanceScreen), findsNothing);
    }
  });

  testWidgets('已登入可使用 web route aliases', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/new');
    await tester.pumpAndSettle();

    expect(find.byType(CreateTripScreen), findsOneWidget);
    final createPage = ModalRoute.of(
      tester.element(find.byType(CreateTripScreen)),
    )!.settings;
    expect(createPage, isA<MaterialPage<void>>());
    expect((createPage as MaterialPage<void>).fullscreenDialog, isTrue);

    container.read(appRouterProvider).go('/edit-trip/trip-1');
    await tester.pumpAndSettle();

    expect(find.byType(EditTripScreen), findsOneWidget);
    final editPage = ModalRoute.of(
      tester.element(find.byType(EditTripScreen)),
    )!.settings;
    expect(editPage, isA<MaterialPage<void>>());
    expect((editPage as MaterialPage<void>).fullscreenDialog, isTrue);

    container.read(appRouterProvider).go('/account/sessions');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.byType(AccountSessionsScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/account/connected-apps');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.byType(ConnectedAppsScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/explore');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.byType(AppleRootTabBar), findsOneWidget);

    container
        .read(appRouterProvider)
        .go('/add-to-trip?place_id=p1&name=美麗海水族館&lat=26.69&lng=127.87');
    await tester.pumpAndSettle();

    expect(find.byType(AddToTripScreen), findsOneWidget);
    expect(find.byType(AppleRootTabBar), findsOneWidget);
    expect(find.text('加入行程：美麗海水族館'), findsOneWidget);

    container.read(appRouterProvider).go('/trip/trip-1/print');
    await tester.pumpAndSettle();

    expect(find.byType(TripPrintScreen), findsOneWidget);
  });
}
