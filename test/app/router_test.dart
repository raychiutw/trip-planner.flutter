/// appRouterProvider redirect 行為測試：
/// 1. 未登入（AsyncData null）→ 任何受保護路徑 redirect 到 /login
/// 2. 已登入在 /login → redirect 到 /trips
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/account/account_settings_screens.dart';
import 'package:tripline/features/auth/email_verify_pending_screen.dart';
import 'package:tripline/features/auth/forgot_password_screen.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/auth/reset_password_screen.dart';
import 'package:tripline/features/auth/signup_screen.dart';
import 'package:tripline/features/auth/verify_email_screen.dart';
import 'package:tripline/features/chat/chat_screen.dart';
import 'package:tripline/features/collab/collab_screen.dart';
import 'package:tripline/features/favorites/add_poi_favorite_to_trip_screen.dart';
import 'package:tripline/features/favorites/explore_screen.dart';
import 'package:tripline/features/favorites/favorites_screen.dart';
import 'package:tripline/features/invite/invite_screen.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/features/trip_detail/add_entry_screen.dart';
import 'package:tripline/features/trip_detail/change_poi_screen.dart';
import 'package:tripline/features/trip_detail/edit_entry_screen.dart';
import 'package:tripline/features/trip_detail/entry_action_screen.dart';
import 'package:tripline/features/trip_detail/trip_health_screen.dart';
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trips/trip_form_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/chat.dart';
import 'package:tripline/models/collab.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/health.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/poi.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/user.dart';

/// 固定回傳指定使用者的假 AuthNotifier（不打 API）。
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixedUser);

  final UserInfo? _fixedUser;

  @override
  Future<UserInfo?> build() async => _fixedUser;
}

class _MockTripRepository extends Mock implements TripRepository {}

const _loggedInUser = UserInfo(
  id: 'user-1',
  email: 'traveler@example.com',
  emailVerified: true,
  displayName: 'Ray',
);

ProviderContainer _buildContainer({required UserInfo? currentUser}) {
  final mockTripRepository = _MockTripRepository();
  when(mockTripRepository.fetchMyTrips).thenAnswer((_) async => []);
  when(
    () => mockTripRepository.fetchTripRequests(
      tripId: any(named: 'tripId'),
      limit: any(named: 'limit'),
      sort: any(named: 'sort'),
    ),
  ).thenAnswer((_) async => const TripRequestPage(items: [], hasMore: false));
  when(
    () => mockTripRepository.fetchTripPermissions(any()),
  ).thenAnswer((_) async => const <TripPermission>[]);
  when(
    () => mockTripRepository.fetchPendingInvitations(any()),
  ).thenAnswer((_) async => const PendingInvitationPage(items: []));
  when(() => mockTripRepository.fetchInvitation(any())).thenAnswer(
    (_) async => const InvitationPreview(
      tripId: 'trip-1',
      tripTitle: '沖繩家族之旅',
      invitedEmail: 'traveler@example.com',
      inviterDisplayName: 'Ray',
      inviterEmail: 'ray@example.com',
      expiresAt: '2026-07-15T00:00:00Z',
    ),
  );
  when(() => mockTripRepository.fetchTrip(any())).thenAnswer(
    (_) async => const Trip(
      id: 'trip-1',
      name: 'Trip 1',
      title: '沖繩家族之旅',
      description: '放慢步調',
      published: true,
      lang: 'zh-TW',
      startDate: '2026-10-01',
      endDate: '2026-10-03',
      destinations: [TripDestination(name: '那霸', lat: 26.2145, lng: 127.6812)],
    ),
  );
  when(() => mockTripRepository.fetchDays(any())).thenAnswer(
    (_) async => const [
      TripDay(
        id: 10,
        dayNum: 1,
        title: '北部',
        version: 1,
        timeline: [
          TimelineEntry(
            id: 51,
            sortOrder: 0,
            title: '美麗海水族館',
            version: 1,
            startTime: '10:00',
            master: EntryPoiInfo(
              poiId: 501,
              name: '美麗海水族館',
              lat: 26.694,
              lng: 127.878,
            ),
          ),
        ],
      ),
      TripDay(
        id: 11,
        dayNum: 2,
        title: '那霸',
        version: 1,
        timeline: [
          TimelineEntry(
            id: 101,
            sortOrder: 0,
            title: '首里城公園',
            version: 1,
            startTime: '09:00',
            master: EntryPoiInfo(
              poiId: 601,
              name: '首里城公園',
              lat: 26.217,
              lng: 127.719,
            ),
          ),
        ],
      ),
    ],
  );
  when(
    () => mockTripRepository.fetchTripHealthReport(any()),
  ).thenAnswer((_) async => null);
  when(() => mockTripRepository.startTripHealthCheck(any())).thenAnswer(
    (_) async => const TripHealthReport(
      tripId: 'trip-1',
      userId: 'user-1',
      status: 'pending',
      requestId: 99,
      findings: [],
      createdAt: '2026-07-08T10:00:00Z',
    ),
  );
  when(() => mockTripRepository.fetchEntry(any(), any())).thenAnswer(
    (_) async => const TimelineEntry(
      id: 101,
      dayId: 11,
      sortOrder: 0,
      title: '首里城公園',
      description: '世界遺產',
      version: 7,
      master: EntryPoiInfo(poiId: 501, name: '首里城公園', type: 'attraction'),
    ),
  );
  when(
    mockTripRepository.fetchPoiFavorites,
  ).thenAnswer((_) async => const <PoiFavorite>[]);

  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(() => _FakeAuthNotifier(currentUser)),
      tripRepositoryProvider.overrideWithValue(mockTripRepository),
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

  testWidgets('已登入時 /chat 進入 ChatScreen', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/chat');
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /map 進入 GlobalMapScreen', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/map');
    await tester.pumpAndSettle();

    expect(find.byType(GlobalMapScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/new 進入新增行程表單', (tester) async {
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

    expect(find.byType(TripFormScreen), findsOneWidget);
    expect(find.text('新增行程'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-form-destination-0')),
      findsOneWidget,
    );
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/edit 進入編輯行程表單', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/edit');
    await tester.pumpAndSettle();

    expect(find.byType(TripFormScreen), findsOneWidget);
    expect(find.text('編輯行程'), findsOneWidget);
    expect(find.text('沖繩家族之旅'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/collab 進入共編設定頁', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/collab');
    await tester.pumpAndSettle();

    expect(find.byType(CollabScreen), findsOneWidget);
    expect(find.text('共編設定'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/health 進入 AI 健檢頁', (tester) async {
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
    expect(find.text('AI 健檢'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/stop/:entryId/map 進入行程地圖', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/stop/101/map');
    await tester.pumpAndSettle();

    expect(find.byType(TripMapScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('未登入時 /invite?token 可進入 InviteScreen', (tester) async {
    final container = _buildContainer(currentUser: null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/invite?token=invite-token');
    await tester.pumpAndSettle();

    expect(find.byType(InviteScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('未登入時 auth supplement routes 可公開進入', (tester) async {
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

    router.go('/signup?invitation=invite-token');
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    router.go('/signup/check-email?email=ray%40example.com');
    await tester.pumpAndSettle();
    expect(find.byType(EmailVerifyPendingScreen), findsOneWidget);
    expect(find.text('ray@example.com'), findsOneWidget);

    router.go('/login/forgot');
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    router.go('/auth/password/reset?token=reset-token');
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsOneWidget);

    router.go('/auth/verify-email?token=verify-token');
    await tester.pumpAndSettle();
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
  });

  testWidgets('已登入時 /favorites 進入 FavoritesScreen', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/favorites');
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 account/settings 子路由進入設定頁', (tester) async {
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

    router.go('/account/appearance');
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
    expect(find.text('外觀'), findsOneWidget);

    router.go('/account/notifications');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);

    router.go('/settings/appearance');
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceSettingsScreen), findsOneWidget);

    router.go('/settings/notifications');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });

  testWidgets('已登入時 /explore 進入 ExploreScreen', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/explore');
    await tester.pumpAndSettle();

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /add-to-trip query 進入加入行程表單', (tester) async {
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
        .go(
          '/add-to-trip?place_id=ChIJ-shuri&name=%E9%A6%96%E9%87%8C%E5%9F%8E&lat=26.217&lng=127.719&category=tourist_attraction',
        );
    await tester.pumpAndSettle();

    expect(find.byType(AddPoiFavoriteToTripScreen), findsOneWidget);
    expect(find.text('還沒有可加入的行程'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/add-entry query 進入新增景點表單', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/add-entry?day=2');
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryScreen), findsOneWidget);
    expect(find.text('Day 2 · 那霸'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/add-custom-stop 進入自訂景點表單', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/add-custom-stop?day=2');
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryScreen), findsOneWidget);
    expect(find.text('Day 2 · 那霸'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-entry-custom-title')),
      findsOneWidget,
    );
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/stop/:entryId/edit 進入編輯景點表單', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/stop/101/edit');
    await tester.pumpAndSettle();

    expect(find.byType(EditEntryScreen), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/stop/:entryId/change-poi 進入置換景點表單', (
    tester,
  ) async {
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
        .go('/trips/trip-1/stop/101/change-poi?mode=alternate');
    await tester.pumpAndSettle();

    expect(find.byType(ChangePoiScreen), findsOneWidget);
    expect(find.text('加入備選景點'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/stop/:entryId/copy 進入複製景點表單', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/stop/101/copy');
    await tester.pumpAndSettle();

    expect(find.byType(EntryActionScreen), findsOneWidget);
    expect(find.text('複製到哪一天'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('已登入時 /trips/:id/stop/:entryId/move 進入移動景點表單', (tester) async {
    final container = _buildContainer(currentUser: _loggedInUser);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/trips/trip-1/stop/101/move');
    await tester.pumpAndSettle();

    expect(find.byType(EntryActionScreen), findsOneWidget);
    expect(find.text('移動到哪一天'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
