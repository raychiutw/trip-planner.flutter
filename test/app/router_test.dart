/// appRouterProvider redirect 行為測試：
/// 1. 未登入（AsyncData null）→ 任何受保護路徑 redirect 到 /login
/// 2. 已登入在 /login → redirect 到 /trips
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/favorites/add_poi_favorite_to_trip_screen.dart';
import 'package:tripline/features/favorites/explore_screen.dart';
import 'package:tripline/features/favorites/favorites_screen.dart';
import 'package:tripline/features/trip_detail/add_entry_screen.dart';
import 'package:tripline/features/trip_detail/change_poi_screen.dart';
import 'package:tripline/features/trip_detail/edit_entry_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
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
    () => mockTripRepository.fetchTrip(any()),
  ).thenAnswer((_) async => const Trip(id: 'trip-1', name: 'Trip 1'));
  when(() => mockTripRepository.fetchDays(any())).thenAnswer(
    (_) async => const [TripDay(id: 11, dayNum: 2, title: '那霸', version: 1)],
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
}
