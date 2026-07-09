/// appRouterProvider redirect 行為測試：
/// 1. 未登入（AsyncData null）→ 任何受保護路徑 redirect 到 /login
/// 2. 已登入在 /login → redirect 到 /trips
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/auth/oauth_consent_screen.dart';
import 'package:tripline/features/account/account_sessions_screen.dart';
import 'package:tripline/features/account/connected_apps_screen.dart';
import 'package:tripline/features/account/settings/appearance_screen.dart';
import 'package:tripline/features/account/settings/notifications_screen.dart';
import 'package:tripline/features/favorites/explore/explore_screen.dart';
import 'package:tripline/features/favorites/add_to_trip/add_to_trip_screen.dart';
import 'package:tripline/features/invite/invite_screen.dart';
import 'package:tripline/features/share/public_share_screen.dart';
import 'package:tripline/features/trip_detail/trip_print_screen.dart';
import 'package:tripline/features/trips/create/create_trip_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/share.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/models/user.dart';

/// 固定回傳指定使用者的假 AuthNotifier（不打 API）。
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixedUser);

  final UserInfo? _fixedUser;

  @override
  Future<UserInfo?> build() async => _fixedUser;
}

class _MockTripRepository extends Mock implements TripRepository {}

class _MockCollabRepository extends Mock implements CollabRepository {}

const _loggedInUser = UserInfo(
  id: 'user-1',
  email: 'traveler@example.com',
  emailVerified: true,
  displayName: 'Ray',
);

ProviderContainer _buildContainer({required UserInfo? currentUser}) {
  final mockTripRepository = _MockTripRepository();
  final mockCollabRepository = _MockCollabRepository();
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
  when(mockTripRepository.watchMyTrips).thenAnswer(
    (_) => Stream.value(const [TripSummary(tripId: 'trip-1', name: '沖繩')]),
  );
  when(() => mockTripRepository.watchDays(any())).thenAnswer(
    (_) => Stream.value(const [TripDay(id: 1, dayNum: 1, version: 0)]),
  );
  when(
    () => mockTripRepository.fetchNotes(any()),
  ).thenAnswer((_) async => const TripNotes());
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

  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(() => _FakeAuthNotifier(currentUser)),
      tripRepositoryProvider.overrideWithValue(mockTripRepository),
      collabRepositoryProvider.overrideWithValue(mockCollabRepository),
    ],
  );
  return container;
}

void main() {
  testWidgets('未登入時 redirect 到 /login', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TripsListScreen), findsNothing);
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

  testWidgets('已登入可進入通知設定 route 與 web alias', (tester) async {
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

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/account/notifications');
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
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

    container.read(appRouterProvider).go('/account/appearance');
    await tester.pumpAndSettle();

    expect(find.byType(AppearanceScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/account/sessions');
    await tester.pumpAndSettle();

    expect(find.byType(AccountSessionsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    container.read(appRouterProvider).go('/account/connected-apps');
    await tester.pumpAndSettle();

    expect(find.byType(ConnectedAppsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

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
