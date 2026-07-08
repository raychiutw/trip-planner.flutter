import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/share/public_share_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/share.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this.user);

  final UserInfo? user;

  @override
  Future<UserInfo?> build() async => user;
}

void main() {
  late MockTripRepository repository;

  const sharedTrip = PublicTripShare(
    name: 'okinawa-trip-2026',
    title: '沖繩家族旅行',
    sharedBy: 'Ray',
    destinations: ['那霸'],
    days: [
      TripDay(
        id: 10,
        dayNum: 1,
        date: '2026-10-01',
        label: '抵達日',
        version: 1,
        timeline: [
          TimelineEntry(
            id: 101,
            sortOrder: 0,
            title: '首里城公園',
            version: 1,
            startTime: '09:00',
            endTime: '10:30',
            travel: Travel(type: 'walking', min: 18, distanceM: 950),
          ),
        ],
      ),
    ],
    notes: TripNotes(
      flights: [TripFlight(id: 1, sortOrder: 0, version: 1, flightNo: 'BR112')],
    ),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    UserInfo? user,
    String token = 's1',
  }) async {
    final router = GoRouter(
      initialLocation: '/s/$token',
      routes: [
        GoRoute(
          path: '/s/:token',
          builder: (context, state) =>
              PublicShareScreen(token: state.pathParameters['token']!),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('trip ${state.pathParameters['tripId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(() => FakeAuthNotifier(user)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = MockTripRepository();
    when(
      () => repository.fetchPublicTripShare(any()),
    ).thenAnswer((_) async => sharedTrip);
    when(
      () => repository.clonePublicTripShare(any()),
    ).thenAnswer((_) async => 'cln-trip-1');
  });

  testWidgets('顯示公開分享 hero、日程與允許公開的 notes', (tester) async {
    await pumpScreen(tester);

    expect(find.text('由 Ray 分享給你'), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('2026-10-01 · 那霸 · 1 天'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('09:00-10:30'), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('航班'), findsOneWidget);
    expect(find.text('BR112'), findsOneWidget);
  });

  testWidgets('未登入點複製會前往 login', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    verifyNever(() => repository.clonePublicTripShare(any()));
  });

  testWidgets('已登入點複製會 clone 並導向新行程', (tester) async {
    const user = UserInfo(id: 'user-1', email: 'ray@example.com');
    await pumpScreen(tester, user: user);

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();

    verify(() => repository.clonePublicTripShare('s1')).called(1);
    expect(find.text('trip cln-trip-1'), findsOneWidget);
  });

  testWidgets('分享連結失效時顯示 notfound 狀態', (tester) async {
    when(
      () => repository.fetchPublicTripShare(any()),
    ).thenThrow(Exception('404'));

    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('public-share-notfound')), findsOneWidget);
    expect(find.text('連結已失效'), findsOneWidget);
  });
}
