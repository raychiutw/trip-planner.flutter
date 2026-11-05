import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/requests/request_lifecycle.dart';
import 'package:tripline/features/trips/health/trip_health_screen.dart';
import 'package:tripline/models/ai_data_consent.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/user.dart';
import '../../../helpers/ai_data_consent_fixtures.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_health.dart';
import 'package:tripline/models/trip_poi_health.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_chip.dart';
import 'package:tripline/ui/tp_tag.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockRequestsRepository extends Mock implements RequestsRepository {}

class _StubAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'u1', email: 'a@b.c', emailVerified: true);
}

void main() {
  late MockTripRepository repository;
  late MockRequestsRepository requestsRepo;
  late StreamController<TripRequestEvent> sseEvents;

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
    MockAiDataConsentRepo? consent,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          requestsRepositoryProvider.overrideWithValue(requestsRepo),
          if (consent != null) ...[
            authStateProvider.overrideWith(_StubAuth.new),
            aiDataConsentRepositoryProvider.overrideWithValue(consent),
          ],
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
    when(() => requestsRepo.fetchRequest(any())).thenAnswer(
      (_) async => const TripRequest(
        id: 43,
        tripId: 'trip-1',
        message: '健檢',
        status: RequestStatus.processing,
      ),
    );
    sseEvents = StreamController<TripRequestEvent>.broadcast();
    when(
      () => requestsRepo.watchRequestEvents(any()),
    ).thenAnswer((_) => sseEvents.stream);
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

  tearDown(() => sseEvents.close());

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
    // 狀態、數量、嚴重度、面向都是唯讀資訊,不得用按鈕語意的 TpChip。
    expect(find.byType(TpChip), findsNothing);
    expect(find.byType(TpTag), findsAtLeastNWidgets(4));
  });

  testWidgets('建議卡一律撐滿內容寬，不隨內容長短縮成不同寬度（#544 A7）', (tester) async {
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer(
      (_) async => const TripHealthReport(
        tripId: 'trip-1',
        userId: 'user-1',
        status: TripHealthStatus.completed,
        createdAt: '2026-07-09T10:00:00Z',
        findings: [
          // 第一張有建議區塊（寬度撐滿），第二張只有短文字：舊行為下第二張會縮成一半寬。
          TripHealthFinding(
            severity: TripHealthSeverity.high,
            title: '第一天行程過滿',
            description: '10:00 到 21:00 之間沒有休息時間。',
            suggestion: '把其中一個景點移到第二天。',
          ),
          TripHealthFinding(
            severity: TripHealthSeverity.low,
            title: '午餐尚未安排',
            description: '第二天沒有用餐停留點。',
          ),
        ],
        completedAt: '2026-07-09T10:01:00Z',
      ),
    );

    await pumpScreen(tester);

    final cards = find.descendant(
      of: find.byKey(const ValueKey('trip-health-results')),
      matching: find.byType(Card),
    );
    expect(cards, findsNWidgets(2));
    expect(
      tester.getSize(cards.at(1)).width,
      tester.getSize(cards.at(0)).width,
      reason: '兩張建議卡寬度要一致',
    );
  });

  testWidgets('用詞人話化:不外洩 POI／Day／原始代碼', (tester) async {
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer(
      (_) async => const TripHealthReport(
        tripId: 'trip-1',
        userId: 'user-1',
        status: TripHealthStatus.completed,
        createdAt: '2026-07-09T10:00:00Z',
        findings: [
          TripHealthFinding(
            severity: TripHealthSeverity.medium,
            title: '午餐空窗',
            description: '中午沒有安排餐廳。',
            actionTarget: TripHealthActionTarget(day: 2),
          ),
        ],
      ),
    );
    when(() => repository.fetchPoiHealth('trip-1')).thenAnswer(
      (_) async => const TripPoiHealthReport(
        version: 2,
        closed: 1,
        missing: 1,
        items: [
          TripPoiHealthItem(
            poiId: 501,
            poiName: '已歇業餐廳',
            status: TripPoiHealthStatus.closed,
            reason: 'CLOSED_PERMANENTLY',
          ),
          TripPoiHealthItem(
            poiId: 502,
            poiName: '缺資料景點',
            status: TripPoiHealthStatus.missing,
            reason: 'NO_HOURS_DATA',
          ),
        ],
      ),
    );

    await pumpScreen(tester);

    expect(find.text('景點狀態'), findsOneWidget);
    expect(find.text('前往第 2 天'), findsOneWidget);
    expect(find.text('已永久歇業'), findsOneWidget);
    expect(find.text('缺少營業資料'), findsOneWidget);
    for (final leak in ['POI', 'Day ', 'CLOSED_', 'NO_HOURS', '#', 'system']) {
      expect(find.textContaining(leak), findsNothing, reason: leak);
    }
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
    await tester.tap(find.text('前往停留點'));
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
    await tester.tap(find.text('前往第 2 天'));
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

  testWidgets('app 回前景時補讀工單，已終結的 pending 報告顯示停滯', (tester) async {
    var terminal = false;
    when(
      () => repository.fetchHealthReport('trip-1'),
    ).thenAnswer((_) async => pendingReport());
    when(() => requestsRepo.fetchRequest(43)).thenAnswer(
      (_) async => TripRequest(
        id: 43,
        tripId: 'trip-1',
        message: '健檢',
        status: terminal ? RequestStatus.failed : RequestStatus.processing,
        terminalReason: terminal ? TerminalReason.timedOut : null,
      ),
    );
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsOneWidget);

    terminal = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsNothing);
  });

  testWidgets('終態重讀尚未完成時重新整理，同一張 pending 工單仍顯示停滯', (tester) async {
    final terminalRead = Completer<TripHealthReport?>();
    final refreshRead = Completer<TripHealthReport?>();
    var reads = 0;
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer((_) {
      reads++;
      return switch (reads) {
        1 => Future.value(pendingReport()),
        2 => terminalRead.future,
        _ => refreshRead.future,
      };
    });
    when(() => requestsRepo.fetchRequest(43)).thenAnswer(
      (_) async => const TripRequest(
        id: 43,
        tripId: 'trip-1',
        message: '健檢',
        status: RequestStatus.processing,
      ),
    );
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsOneWidget);

    sseEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await tester.pump();
    expect(reads, 2, reason: '終態已開始重讀報告，回應尚未放行');
    await tester.tap(find.byKey(const ValueKey('trip-health-refresh-button')));
    await tester.pump();
    refreshRead.complete(pendingReport());
    await tester.pump();
    await tester.pump();
    terminalRead.complete(pendingReport());
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsNothing);
  });

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

  testWidgets('工單終結 → 重讀報告表 → 完成報告取代 pending', (tester) async {
    var reads = 0;
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer((_) async {
      reads++;
      return reads == 1
          ? pendingReport()
          : const TripHealthReport(
              tripId: 'trip-1',
              userId: 'user-1',
              status: TripHealthStatus.completed,
              requestId: 43,
              createdAt: '2026-07-09T10:02:00Z',
            );
    });
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsOneWidget);

    sseEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-pending')), findsNothing);
    expect(find.byKey(const ValueKey('trip-health-stalled')), findsNothing);
    expect(reads, 2, reason: '終結後只重讀一次,不是輪詢');
  });

  testWidgets('SSE 終態補齊原因時，同一張工單的報告只重讀一次', (tester) async {
    var reportReads = 0;
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer((_) async {
      reportReads++;
      return pendingReport();
    });
    var requestReads = 0;
    when(() => requestsRepo.fetchRequest(43)).thenAnswer((_) async {
      requestReads++;
      return TripRequest(
        id: 43,
        tripId: 'trip-1',
        message: '健檢',
        status: requestReads == 1
            ? RequestStatus.processing
            : RequestStatus.failed,
        terminalReason: requestReads == 1 ? null : TerminalReason.timedOut,
      );
    });
    await pumpScreen(tester);
    sseEvents.add(const TripRequestEvent(status: RequestStatus.failed));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);
    expect(reportReads, 2, reason: '進頁讀取一次，工單終結後只重讀一次');
  });

  testWidgets('工單終結但報告表讀不到 → 維持現況並標成停滯', (tester) async {
    var reads = 0;
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer((_) async {
      reads++;
      if (reads > 1) throw Exception('offline');
      return pendingReport();
    });
    await pumpScreen(tester);
    sseEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);
  });

  testWidgets('停止等待:伺服器沒確認 → 仍換成停滯態,且誠實提示', (tester) async {
    when(
      () => repository.fetchHealthReport('trip-1'),
    ).thenAnswer((_) async => pendingReport());
    when(() => requestsRepo.stopWaiting(any())).thenThrow(Exception('offline'));
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('trip-health-stop')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);
    expect(find.text(kStopWaitingUnconfirmedMessage), findsOneWidget);
  });

  testWidgets('工單終結後讀到另一張新工單的 pending → 不標停滯,改訂閱新工單', (tester) async {
    var reads = 0;
    when(() => repository.fetchHealthReport('trip-1')).thenAnswer((_) async {
      reads++;
      return reads == 1
          ? pendingReport()
          : const TripHealthReport(
              tripId: 'trip-1',
              userId: 'user-1',
              status: TripHealthStatus.pending,
              requestId: 44,
              createdAt: '2026-07-09T10:03:00Z',
            );
    });
    await pumpScreen(tester);
    sseEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-stalled')), findsNothing);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsOneWidget);
    verify(() => requestsRepo.watchRequestEvents(44)).called(1);
  });

  testWidgets('停止等待鈕在 PATCH 回來前停用,連點只送一次', (tester) async {
    when(
      () => repository.fetchHealthReport('trip-1'),
    ).thenAnswer((_) async => pendingReport());
    final stop = Completer<void>();
    when(() => requestsRepo.stopWaiting(any())).thenAnswer((_) => stop.future);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('trip-health-stop')));
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-stop')), findsNothing);
    verify(() => requestsRepo.stopWaiting(43)).called(1);
    stop.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text(kStopWaitingUnconfirmedMessage), findsNothing);
    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);
  });

  testWidgets('停止等待後重新整理:報告仍是同一張 pending → 停滯態保留', (tester) async {
    when(
      () => repository.fetchHealthReport('trip-1'),
    ).thenAnswer((_) async => pendingReport());
    when(() => requestsRepo.stopWaiting(any())).thenAnswer((_) async {});
    await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('trip-health-stop')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);

    when(
      () => requestsRepo.fetchRequest(any()),
    ).thenThrow(Exception('offline'));
    await tester.tap(find.byKey(const ValueKey('trip-health-refresh-button')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('trip-health-stalled')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-health-pending')), findsNothing);
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

  group('AI 資料同意', () {
    const started = TripHealthReport(
      tripId: 'trip-1',
      userId: 'user-1',
      status: TripHealthStatus.pending,
      requestId: 43,
      createdAt: '2026-07-09T10:02:00Z',
    );

    // 啟動中按鈕有永不停止的 spinner，不能 pumpAndSettle。
    Future<void> settleFixed(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tapStart(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('trip-health-start-button')));
      await settleFixed(tester);
    }

    testWidgets('旗標關閉：不跳資料同意，直接啟動健檢', (tester) async {
      final consent = MockAiDataConsentRepo();
      when(consent.fetch).thenAnswer(
        (_) async =>
            aiConsentFixture(AiDataConsentStatus.none, enforced: false),
      );
      when(
        () => repository.startHealthCheck('trip-1'),
      ).thenAnswer((_) async => started);
      await pumpScreen(tester, consent: consent);
      await tapStart(tester);

      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
      verify(() => repository.startHealthCheck('trip-1')).called(1);
    });

    testWidgets('未同意：先跳資料同意，同意前不發 AI mutation；取消後不啟動', (tester) async {
      final consent = MockAiDataConsentRepo();
      when(consent.fetch).thenAnswer(
        (_) async => aiConsentFixture(AiDataConsentStatus.withdrawn),
      );
      await pumpScreen(tester, consent: consent);
      await tapStart(tester);

      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsOneWidget,
      );
      verifyNever(() => repository.startHealthCheck(any()));

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-cancel')));
      await settleFixed(tester);
      verifyNever(() => repository.startHealthCheck(any()));
      verifyNever(() => consent.accept(any()));
      expect(find.byKey(const ValueKey('trip-health-empty')), findsOneWidget);
    });

    testWidgets('同意 → 接續啟動健檢恰好一次', (tester) async {
      final consent = MockAiDataConsentRepo();
      when(
        consent.fetch,
      ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.none));
      when(
        () => consent.accept('ai-data-v1'),
      ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
      when(
        () => repository.startHealthCheck('trip-1'),
      ).thenAnswer((_) async => started);
      await pumpScreen(tester, consent: consent);
      await tapStart(tester);
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await settleFixed(tester);

      verify(() => repository.startHealthCheck('trip-1')).called(1);
      expect(find.byKey(const ValueKey('trip-health-pending')), findsOneWidget);
    });

    testWidgets('server 403 送出者缺同意：就地同意後只重啟一次', (tester) async {
      final consent = MockAiDataConsentRepo();
      var reads = 0;
      when(consent.fetch).thenAnswer(
        (_) async => reads++ == 0
            ? aiConsentFixture(AiDataConsentStatus.valid, enforced: false)
            : aiConsentFixture(AiDataConsentStatus.none),
      );
      when(
        () => consent.accept('ai-data-v1'),
      ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
      var attempt = 0;
      when(() => repository.startHealthCheck('trip-1')).thenAnswer((_) async {
        if (attempt++ == 0) throw submitterGate;
        return started;
      });
      await pumpScreen(tester, consent: consent);
      await tapStart(tester);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await settleFixed(tester);

      verify(() => repository.startHealthCheck('trip-1')).called(2);
      expect(find.byKey(const ValueKey('trip-health-pending')), findsOneWidget);
    });

    testWidgets('旅伴被 owner 擋下：顯示 owner 尚未同意，不顯示失敗、不排隊', (tester) async {
      final consent = MockAiDataConsentRepo();
      when(
        consent.fetch,
      ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
      when(() => repository.startHealthCheck('trip-1')).thenThrow(ownerGate);
      await pumpScreen(tester, consent: consent);
      await tapStart(tester);

      expect(find.textContaining('行程擁有者尚未同意 AI 資料處理'), findsWidgets);
      expect(find.byKey(const ValueKey('trip-health-pending')), findsNothing);
      expect(find.textContaining('觸發健檢失敗'), findsNothing);
      verify(() => repository.startHealthCheck('trip-1')).called(1);
    });
  });
}
