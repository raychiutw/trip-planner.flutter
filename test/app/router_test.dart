/// appRouterProvider redirect 行為測試：
/// 1. 未登入（AsyncData null）→ 任何受保護路徑 redirect 到 /welcome
/// 2. 已登入在 /login → redirect 到 /trips
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/auth/account_flow_screens.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/auth/oauth_consent_screen.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/account/account_sessions_screen.dart';
import 'package:tripline/features/account/account_screen.dart';
import 'package:tripline/features/account/connected_apps_screen.dart';
import 'package:tripline/features/account/developer_apps_screen.dart';
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
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_print_screen.dart';
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
import 'package:tripline/models/user.dart';
import 'package:tripline/ui/tp_app_bar.dart';

import '../helpers/fake_trip_map.dart';

/// 固定回傳指定使用者的假 AuthNotifier（不打 API）。
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixedUser);

  final UserInfo? _fixedUser;

  @override
  Future<UserInfo?> build() async => _fixedUser;
}

class _MockTripRepository extends Mock implements TripRepository {}

class _MockCollabRepository extends Mock implements CollabRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

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
}) {
  final mockTripRepository = _MockTripRepository();
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
    (_) => Stream.value(const [TripDay(id: 1, dayNum: 1, version: 0)]),
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
    overrides: [
      authStateProvider.overrideWith(() => _FakeAuthNotifier(currentUser)),
      tripRepositoryProvider.overrideWithValue(mockTripRepository),
      collabRepositoryProvider.overrideWithValue(mockCollabRepository),
      favoritesRepositoryProvider.overrideWithValue(mockFavoritesRepository),
      tripMapCanvasBuilderProvider.overrideWithValue(fakeTripMapBuilder),
      appNetworkAvailabilityProvider.overrideWithValue(const Stream.empty()),
    ],
  );
  return container;
}

void main() {
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
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(TripsListScreen), findsNothing);
  });

  testWidgets('Welcome CTA 前往登入', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('未登入 deep link 經 Welcome 保留安全站內目的地', (tester) async {
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
    router.go('/chat?tripId=trip-1');
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['redirect_after'],
      '/chat?tripId=trip-1',
    );
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
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);

    container
        .read(appRouterProvider)
        .go('/signup/check-email?email=traveler%40example.com');
    await tester.pumpAndSettle();

    expect(find.byType(EmailVerifyPendingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/login/forgot');
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container
        .read(appRouterProvider)
        .go('/auth/password/reset?token=reset-token');
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container
        .read(appRouterProvider)
        .go('/auth/verify-email?token=verify-token');
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('未登入可進入 OAuth consent shell route', (tester) async {
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
          '&state=abc123'
          '&response_type=code',
        );
    await tester.pumpAndSettle();

    expect(find.byType(OAuthConsentScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    final first = tester.widget<OAuthConsentScreen>(
      find.byType(OAuthConsentScreen),
    );
    container
        .read(appRouterProvider)
        .go(
          '/oauth/consent?client_id=tp_beta'
          '&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback'
          '&scope=openid'
          '&state=next'
          '&response_type=code',
        );
    await tester.pumpAndSettle();

    final second = tester.widget<OAuthConsentScreen>(
      find.byType(OAuthConsentScreen),
    );
    expect(second.request.clientId, 'tp_beta');
    expect(second.key, isNot(first.key));
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
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入可使用 admin/manage legacy redirects', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/admin');
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);

    container.read(appRouterProvider).go('/admin/');
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);

    container.read(appRouterProvider).go('/manage');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/manage/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/trip/trip-1/health');
    await tester.pumpAndSettle();

    expect(find.byType(TripHealthScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/trip/trip-1/audit');
    await tester.pumpAndSettle();

    expect(find.byType(TripAuditScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入可從 stop map web alias 聚焦地圖 entry', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trip/trip-1/stop/11/map');
    await tester.pumpAndSettle();

    final screen = tester.widget<TripMapScreen>(find.byType(TripMapScreen));
    expect(screen.initialEntryId, 11);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入可從 stop web alias 聚焦 timeline entry', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trip/trip-1/stop/11');
    await tester.pumpAndSettle();

    final screen = tester.widget<TripTimelineScreen>(
      find.byType(TripTimelineScreen),
    );
    expect(screen.initialEntryId, 11);
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入可進入 entry edit/change-poi web aliases', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trip/trip-1/stop/11/edit');
    await tester.pumpAndSettle();

    expect(find.byType(EntryEditRouteScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/trip/trip-1/stop/11/change-poi');
    await tester.pumpAndSettle();

    expect(find.byType(EntryPoiScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.text('收藏'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入可進入 entry copy/move web aliases', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trip/trip-1/stop/11/copy');
    await tester.pumpAndSettle();

    expect(find.byType(EntryActionRouteScreen), findsOneWidget);
    expect(find.text('複製停留點'), findsOneWidget);

    container.read(appRouterProvider).go('/trip/trip-1/stop/11/move');
    await tester.pumpAndSettle();

    expect(find.byType(EntryActionRouteScreen), findsOneWidget);
    expect(find.text('移到其他 Day'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
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
    expect(find.byType(LoginScreen), findsNothing);

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
    expect(find.byType(LoginScreen), findsNothing);
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
      expect(find.byType(LoginScreen), findsNothing);

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
      router.go(target.$1);
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
    router.go('/settings/developer-apps/new');
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
      router.go('/account');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
      expect(find.byType(AppleRootTabBar), findsOneWidget);
      expect(find.byKey(const ValueKey('root-tab-帳號')), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '$origin?account=root',
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
          .widget<SegmentedButton<TripFilter>>(
            find.byType(SegmentedButton<TripFilter>, skipOffstage: false),
          )
          .selected,
      {TripFilter.mine},
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
          .widget<SegmentedButton<TripFilter>>(
            find.byType(SegmentedButton<TripFilter>, skipOffstage: false),
          )
          .selected,
      {TripFilter.mine},
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
    expect(find.byType(SegmentedButton<TripFilter>), findsOneWidget);
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
    expect(find.byKey(const ValueKey('trip-timeline-map')), findsOneWidget);
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

  testWidgets('行程工具列切到地圖 root branch 並保留 DAY', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1?day=1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-timeline-map')));
    await tester.pumpAndSettle();

    expect(find.byType(GlobalMapScreen), findsOneWidget);
    final rootTab = tester.widget<AppleRootTabBar>(
      find.byType(AppleRootTabBar),
    );
    expect(rootTab.selectedIndex, 2);
    expect(find.byKey(const ValueKey('trip-map-day-1')), findsOneWidget);
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
    expect(find.byType(LoginScreen), findsNothing);
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

    container.read(appRouterProvider).go('/account/appearance');
    await tester.pumpAndSettle();

    expect(
      container
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString(),
      '/trips?account=root',
    );
    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-appearance')), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/account/sessions');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.byType(AccountSessionsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/account/connected-apps');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.byType(ConnectedAppsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/explore');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container
        .read(appRouterProvider)
        .go('/add-to-trip?place_id=p1&name=美麗海水族館&lat=26.69&lng=127.87');
    await tester.pumpAndSettle();

    expect(find.byType(AddToTripScreen), findsOneWidget);
    expect(find.text('加入行程：美麗海水族館'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/trip/trip-1/print');
    await tester.pumpAndSettle();

    expect(find.byType(TripPrintScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
