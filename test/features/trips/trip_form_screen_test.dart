import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/trip_form_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  late MockTripRepository mockTripRepository;

  setUpAll(() {
    registerFallbackValue(const <TripDestinationInput>[]);
  });

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.createTrip(
        id: any(named: 'id'),
        name: any(named: 'name'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) async => 'trip-generated');
    when(() => mockTripRepository.fetchTrip(any())).thenAnswer(
      (_) async => const Trip(
        id: 'okinawa-trip-2026',
        name: '沖繩',
        title: '沖繩家族旅行',
        description: '想放慢步調',
        published: false,
        lang: 'zh-TW',
        startDate: '2026-10-01',
        endDate: '2026-10-03',
        destinations: [
          TripDestination(name: '那霸', lat: 26.2145, lng: 127.6812),
        ],
      ),
    );
    when(
      () => mockTripRepository.updateTrip(
        id: any(named: 'id'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        published: any(named: 'published'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildRouterApp({required String initialLocation}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) =>
              const Scaffold(body: Text('trips-list-probe')),
        ),
        GoRoute(
          path: '/trips/new',
          builder: (context, state) => const TripFormScreen.create(),
        ),
        GoRoute(
          path: '/trips/:tripId/edit',
          builder: (context, state) =>
              TripFormScreen.edit(tripId: state.pathParameters['tripId']!),
        ),
      ],
    );
    return ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(mockTripRepository)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('新增行程表單送出 createTrip 並回到 trips list', (tester) async {
    await tester.pumpWidget(buildRouterApp(initialLocation: '/trips/new'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('trip-form-destination-0')),
      '那霸',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-title')),
      '沖繩家族旅行',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-start-date')),
      '2026-10-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-end-date')),
      '2026-10-03',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-description')),
      '想放慢步調',
    );
    await tester.tap(find.byKey(const ValueKey('trip-form-submit')));
    await tester.pumpAndSettle();

    final captured = verify(
      () => mockTripRepository.createTrip(
        id: captureAny(named: 'id'),
        name: '那霸',
        title: '沖繩家族旅行',
        description: '想放慢步調',
        startDate: '2026-10-01',
        endDate: '2026-10-03',
        countries: 'JP',
        published: true,
        lang: 'zh-TW',
        destinations: captureAny(named: 'destinations'),
      ),
    ).captured;
    expect(captured.first as String, startsWith('trip-'));
    final destinations = captured.last as List<TripDestinationInput>;
    expect(destinations.single.name, '那霸');
    expect(find.text('trips-list-probe'), findsOneWidget);
  });

  testWidgets('編輯行程表單載入既有資料並送出 updateTrip', (tester) async {
    await tester.pumpWidget(
      buildRouterApp(initialLocation: '/trips/okinawa-trip-2026/edit'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('編輯行程'), findsOneWidget);
    expect(find.text('2026-10-01 - 2026-10-03'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('trip-form-title')),
      '沖繩慢旅行',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-form-description')),
      '',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('trip-form-submit')));
    await tester.tap(find.byKey(const ValueKey('trip-form-published')));
    await tester.tap(find.byKey(const ValueKey('trip-form-submit')));
    await tester.pumpAndSettle();

    final captured = verify(
      () => mockTripRepository.updateTrip(
        id: 'okinawa-trip-2026',
        title: '沖繩慢旅行',
        description: null,
        published: true,
        lang: 'zh-TW',
        destinations: captureAny(named: 'destinations'),
      ),
    ).captured;
    final destinations = captured.single as List<TripDestinationInput>;
    expect(destinations.single.name, '那霸');
    expect(find.text('trips-list-probe'), findsOneWidget);
  });
}
