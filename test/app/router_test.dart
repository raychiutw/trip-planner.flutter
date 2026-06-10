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
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/main.dart';
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
}
