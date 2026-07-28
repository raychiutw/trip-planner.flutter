import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/health/trip_health_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_health.dart';
import 'package:tripline/models/trip_poi_health.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockRequestsRepository extends Mock implements RequestsRepository {}

void main() {
  late MockTripRepository repository;
  late MockRequestsRepository requestsRepo;

  const trip = Trip(id: 'trip-1', name: 'okinawa-trip', title: '沖繩家族旅行');
  const nonEmptyDays = [
    TripDay(
      id: 1,
      dayNum: 1,
      version: 0,
      timeline: [
        TimelineEntry(id: 101, sortOrder: 0, title: '首里城', version: 1),
      ],
    ),
  ];
  const noPoiIssues = TripPoiHealthReport(version: 1, closed: 0, missing: 0);

  Future<void> pumpScreen(
    WidgetTester tester, {
    String tripId = 'trip-1',
    ThemeData? theme,
    TextScaler textScaler = TextScaler.noScaling,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          requestsRepositoryProvider.overrideWithValue(requestsRepo),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: TripHealthScreen(
            key: const ValueKey('trip-health-screen'),
            tripId: tripId,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> pumpScreenWithRouter(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const TripHealthScreen(tripId: 'trip-1'),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) => Scaffold(
            body: Text(
              'trip ${state.pathParameters['tripId']} day ${state.uri.queryParameters['day']}',
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/entries/:entryId/edit',
          builder: (context, state) => Scaffold(
            body: Text(
              'edit ${state.pathParameters['tripId']} ${state.pathParameters['entryId']}',
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/entries/:entryId/pois',
          builder: (context, state) => Scaffold(
            body: Text(
              'pois ${state.pathParameters['tripId']} ${state.pathParameters['entryId']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
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
    requestsRepo = MockRequestsRepository();
    when(() => repository.fetchTrip('trip-1')).thenAnswer((_) async => trip);
    when(
      () => repository.fetchDays('trip-1'),
    ).thenAnswer((_) async => nonEmptyDays);
    when(
      () => repository.fetchHealthReport('trip-1'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.fetchPoiHealth('trip-1'),
    ).thenAnswer((_) async => noPoiIssues);
  });

  testWidgets('顯示 completed report findings 與 POI health 摘要', (tester) async {
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer(
      (_) async => const TripHealthReport(
        tripId: 'trip-1',
        userId: 'user-1',
        status: TripHealthStatus.completed,
        createdAt: '2026-07-09T10:00:00Z',
        findings: [
          TripHealthFinding(
            severity: TripHealthSeverity.high,
            title: 'Day 1 時間太滿',
            description: '上午行程間隔過短。',
            dimension: TripHealthDimension.timing,
            suggestion: '刪減一個停留點。',
            actionTarget: TripHealthActionTarget(day: 1, entryId: 101),
          ),
        ],
        completedAt: '2026-07-09T10:01:00Z',
      ),
    );
    when(() => repository.fetchPoiHealth('trip-1')).thenAnswer(
      (_) async => const TripPoiHealthReport(
        version: 2,
        closed: 1,
        missing: 0,
        items: [
          TripPoiHealthItem(
            poiId: 501,
            poiName: '已歇業餐廳',
            status: TripPoiHealthStatus.closed,
            reason: 'CLOSED_PERMANENTLY',
          ),
        ],
      ),
    );

    await pumpScreen(tester);

    expect(find.text('AI 健檢'), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-health-results')), findsOneWidget);
    expect(find.text('Day 1 時間太滿'), findsOneWidget);
    expect(find.textContaining('刪減一個停留點。'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-health-poi-card')), findsOneWidget);
    expect(find.text('已歇業餐廳'), findsOneWidget);
  });

  testWidgets('finding entry target 導向停留點編輯頁', (tester) async {
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer(
      (_) async => const TripHealthReport(
        tripId: 'trip-1',
        userId: 'user-1',
        status: TripHealthStatus.completed,
        createdAt: '2026-07-09T10:00:00Z',
        findings: [
          TripHealthFinding(
            severity: TripHealthSeverity.high,
            title: 'Day 1 時間太滿',
            description: '上午行程間隔過短。',
            actionTarget: TripHealthActionTarget(day: 1, entryId: 101),
          ),
        ],
      ),
    );

    await pumpScreenWithRouter(tester);
    await tester.tap(find.text('前往景點'));
    await tester.pumpAndSettle();

    expect(find.text('edit trip-1 101'), findsOneWidget);
    expect(find.text('pois trip-1 101'), findsNothing);
  });

  testWidgets('finding day target 保留 day query 導回行程', (tester) async {
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer(
      (_) async => const TripHealthReport(
        tripId: 'trip-1',
        userId: 'user-1',
        status: TripHealthStatus.completed,
        createdAt: '2026-07-09T10:00:00Z',
        findings: [
          TripHealthFinding(
            severity: TripHealthSeverity.medium,
            title: 'Day 2 午餐空窗',
            description: '中午沒有安排餐廳。',
            actionTarget: TripHealthActionTarget(day: 2),
          ),
        ],
      ),
    );

    await pumpScreenWithRouter(tester);
    await tester.tap(find.text('前往 Day 2'));
    await tester.pumpAndSettle();

    expect(find.text('trip trip-1 day 2'), findsOneWidget);
  });

  testWidgets('沒有既有 report 時可啟動 health check 並顯示 pending', (tester) async {
    when(() => repository.startHealthCheck('trip-1')).thenAnswer(
      (_) async => const TripHealthReport(
        tripId: 'trip-1',
        userId: 'user-1',
        status: TripHealthStatus.pending,
        requestId: 43,
        createdAt: '2026-07-09T10:02:00Z',
      ),
    );
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('trip-health-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trip-health-start-button')));
    await tester.pump();
    await tester.pump();

    verify(() => repository.startHealthCheck('trip-1')).called(1);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsOneWidget);
  });

  TripHealthReport pendingReport() => const TripHealthReport(
    tripId: 'trip-1',
    userId: 'user-1',
    status: TripHealthStatus.pending,
    requestId: 43,
    createdAt: '2026-07-09T10:02:00Z',
  );

  testWidgets('健檢進行中可以停止等待', (tester) async {
    when(
      () => repository.fetchHealthReport('trip-1'),
    ).thenAnswer((_) async => pendingReport());
    when(() => requestsRepo.stopWaiting(any())).thenAnswer((_) async {});
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('trip-health-stop')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-health-stop')));
    await tester.pump();
    await tester.pump();

    verify(() => requestsRepo.stopWaiting(43)).called(1);
  });

  testWidgets('請求已終結但報告仍 pending 時,說得出那是什麼狀況', (tester) async {
    when(
      () => repository.fetchHealthReport('trip-1'),
    ).thenAnswer((_) async => pendingReport());
    // 牆鐘直接 UPDATE 不經 PATCH,所以完成 hook 不跑、報告表停在 pending。
    when(() => requestsRepo.fetchRequest(43)).thenAnswer(
      (_) async => const TripRequest(
        id: 43,
        tripId: 'trip-1',
        message: '健檢',
        status: RequestStatus.failed,
        terminalReason: TerminalReason.timedOut,
      ),
    );
    await pumpScreen(tester);
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('trip-health-stalled')),
      findsOneWidget,
      reason: '請求終結但報告 pending —— 要說得出來,不能讓人一直重整',
    );
    expect(
      find.byKey(const ValueKey('trip-health-pending')),
      findsNothing,
      reason: '不能再顯示會讓人以為還在跑的提示',
    );
  });

  testWidgets('空行程顯示 guard 並停用開始健檢', (tester) async {
    when(
      () => repository.fetchDays('trip-1'),
    ).thenAnswer((_) async => const [TripDay(id: 1, dayNum: 1, version: 0)]);
    await pumpScreen(tester);

    expect(
      find.byKey(const ValueKey('trip-health-empty-trip')),
      findsOneWidget,
    );
    final startButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('trip-health-start-button')),
    );
    expect(startButton.onPressed, isNull);
    verifyNever(() => repository.startHealthCheck(any()));
  });

  testWidgets('載入錯誤持續顯示、live region 且可重試', (tester) async {
    var shouldFail = true;
    when(() => repository.fetchTrip('trip-1')).thenAnswer((_) async {
      if (shouldFail) throw Exception('offline');
      return trip;
    });

    await pumpScreen(tester);

    final error = tester.widget<Semantics>(
      find.byKey(const ValueKey('trip-health-load-error')),
    );
    expect(error.properties.liveRegion, isTrue);
    expect(find.text('重試'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-health-load-error')), findsNothing);
  });

  testWidgets('regular dark 與最大文字仍限制內容寬度並保留 Header actions', (tester) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      theme: AppTheme.dark(),
      textScaler: const TextScaler.linear(3),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('trip-health-content'))).width,
      lessThanOrEqualTo(720),
    );
    expect(find.byKey(const ValueKey('trip-health-refresh-button')), findsOne);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切換 tripId 後忽略前一個行程較晚完成的載入', (tester) async {
    final oldTrip = Completer<Trip>();
    when(
      () => repository.fetchTrip('trip-1'),
    ).thenAnswer((_) => oldTrip.future);
    when(() => repository.fetchTrip('trip-2')).thenAnswer(
      (_) async => const Trip(id: 'trip-2', name: 'tokyo-trip', title: '東京旅行'),
    );
    when(
      () => repository.fetchDays('trip-2'),
    ).thenAnswer((_) async => nonEmptyDays);
    when(
      () => repository.fetchHealthReport('trip-2'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.fetchPoiHealth('trip-2'),
    ).thenAnswer((_) async => noPoiIssues);

    await pumpScreen(tester, settle: false);
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('trip-health-loading-live')),
          )
          .properties
          .liveRegion,
      isTrue,
    );
    await pumpScreen(tester, tripId: 'trip-2');
    expect(find.text('東京旅行'), findsOneWidget);

    oldTrip.complete(trip);
    await tester.pumpAndSettle();

    expect(find.text('東京旅行'), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsNothing);
  });
}
