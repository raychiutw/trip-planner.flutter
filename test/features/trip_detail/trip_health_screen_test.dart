import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_health_screen.dart';
import 'package:tripline/models/health.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

const _sampleTrip = Trip(
  id: 'trip-1',
  name: 'Okinawa',
  title: '沖繩家族旅行',
  published: true,
);

const _pendingReport = TripHealthReport(
  tripId: 'trip-1',
  userId: 'user-1',
  status: 'pending',
  requestId: 99,
  findings: [],
  createdAt: '2026-07-08T10:00:00Z',
);

const _completedReport = TripHealthReport(
  tripId: 'trip-1',
  userId: 'user-1',
  status: 'completed',
  requestId: 88,
  findings: [
    TripHealthFinding(
      severity: 'high',
      dimension: 'timing',
      title: 'Day 2 入住衝突',
      description: '末站後移動時間不足。',
      suggestion: '前移末站時間。',
      actionTarget: TripHealthActionTarget(day: 2, entryId: 42),
    ),
    TripHealthFinding(
      severity: 'low',
      dimension: 'sights',
      title: '可加水族館',
      description: '北上路線順路。',
      actionTarget: TripHealthActionTarget(day: 5),
    ),
  ],
  createdAt: '2026-07-08T10:00:00Z',
  completedAt: '2026-07-08T10:05:00Z',
);

Widget _buildScreen(_MockTripRepository repository) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TripHealthScreen(tripId: 'trip-1'),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) =>
            Text('timeline ${state.uri.queryParameters['day'] ?? ''}'),
      ),
      GoRoute(
        path: '/trips/:tripId/stop/:entryId/edit',
        builder: (context, state) =>
            Text('edit ${state.pathParameters['entryId']}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [tripRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  late _MockTripRepository repository;

  setUp(() {
    repository = _MockTripRepository();
    when(
      () => repository.fetchTrip('trip-1'),
    ).thenAnswer((_) async => _sampleTrip);
    when(
      () => repository.fetchTripHealthReport('trip-1'),
    ).thenAnswer((_) async => null);
  });

  testWidgets('未健檢過時顯示開始 CTA，點擊後觸發 POST 並顯示 pending', (tester) async {
    when(
      () => repository.startTripHealthCheck('trip-1'),
    ).thenAnswer((_) async => _pendingReport);

    await tester.pumpWidget(_buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.text('AI 健檢'), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('尚未健檢過此行程'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('health-start')));
    await tester.pump();

    expect(find.textContaining('AI 健檢進行中'), findsWidgets);
    verify(() => repository.startTripHealthCheck('trip-1')).called(1);
  });

  testWidgets('completed report 依 severity 分組，並可前往景點與 Day', (tester) async {
    when(
      () => repository.fetchTripHealthReport('trip-1'),
    ).thenAnswer((_) async => _completedReport);

    await tester.pumpWidget(_buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('health-count-high')), findsOneWidget);
    expect(find.byKey(const ValueKey('health-count-low')), findsOneWidget);
    expect(find.text('Day 2 入住衝突'), findsOneWidget);
    expect(find.text('時間'), findsOneWidget);
    expect(find.text('前移末站時間。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('health-goto-entry-0')));
    await tester.pumpAndSettle();
    expect(find.text('edit 42'), findsOneWidget);

    GoRouter.of(tester.element(find.text('edit 42'))).go('/');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('health-goto-day-1')),
      300,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('health-goto-day-1')));
    await tester.pumpAndSettle();
    expect(find.text('timeline 5'), findsOneWidget);
  });
}
