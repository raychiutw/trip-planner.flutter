import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/trip_card.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const fakeTrips = [
    TripSummary(
      tripId: 'okinawa-trip-2026',
      name: 'okinawa-trip-2026',
      title: '沖繩家族之旅',
      totalDays: 5,
    ),
    TripSummary(
      tripId: 'kyoto-trip-2025',
      name: 'kyoto-trip-2025',
      // title 為 null → 卡片應退回顯示 name
      totalDays: 4,
    ),
    TripSummary(
      tripId: 'busan-trip-2024',
      name: 'busan-trip-2024',
      title: '釜山美食團',
      // totalDays 為 null → 不顯示 eyebrow
    ),
  ];

  const filterTrips = [
    TripSummary(
      tripId: 'okinawa-trip-2026',
      name: 'okinawa-trip-2026',
      title: '沖繩家族之旅',
      totalDays: 5,
      owner: 'ray@example.com',
      ownerDisplayName: 'Ray',
      role: 'owner',
      countries: 'JP',
      startDate: '2026-10-01',
      updatedAt: '2026-07-08T10:00:00Z',
      memberCount: 1,
    ),
    TripSummary(
      tripId: 'busan-trip-2024',
      name: 'busan-trip-2024',
      title: '釜山美食團',
      totalDays: 3,
      owner: 'friend@example.com',
      ownerDisplayName: 'Friend',
      role: 'member',
      countries: 'KR',
      startDate: '2024-12-05',
      updatedAt: '2026-07-05T10:00:00Z',
      memberCount: 2,
    ),
    TripSummary(
      tripId: 'kyoto-trip-2025',
      name: 'kyoto-trip-2025',
      title: '京都紅葉',
      totalDays: 4,
      owner: 'friend@example.com',
      ownerDisplayName: 'Friend',
      role: 'viewer',
      countries: 'JP',
      startDate: '2025-11-10',
      updatedAt: '2026-07-01T10:00:00Z',
      memberCount: 3,
    ),
    TripSummary(
      tripId: 'archived-trip-2023',
      name: 'archived-trip-2023',
      title: '舊金山會議',
      totalDays: 2,
      owner: 'ray@example.com',
      role: 'owner',
      countries: 'US',
      startDate: '2023-05-01',
      updatedAt: '2023-05-05T10:00:00Z',
      archivedAt: '2024-01-01T00:00:00Z',
    ),
  ];

  /// 把畫面包進假 GoRouter：/trips 是清單頁、/trips/:tripId 是導航目的地探針。
  /// （flutter_riverpod 3.x 未匯出 Override 型別，overrides 由各測試
  /// 直接在 ProviderScope 建構處以 list literal 傳入。）
  Widget buildRouterApp() {
    final fakeRouter = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => const TripsListScreen(),
        ),
        GoRoute(
          path: '/trips/new',
          builder: (context, state) =>
              const Scaffold(body: Text('new-trip-probe')),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['tripId']}')),
        ),
        GoRoute(
          path: '/trips/:tripId/edit',
          builder: (context, state) =>
              Scaffold(body: Text('edit:${state.pathParameters['tripId']}')),
        ),
        GoRoute(
          path: '/trips/:tripId/collab',
          builder: (context, state) =>
              Scaffold(body: Text('collab:${state.pathParameters['tripId']}')),
        ),
        GoRoute(
          path: '/trips/:tripId/health',
          builder: (context, state) =>
              Scaffold(body: Text('health:${state.pathParameters['tripId']}')),
        ),
        GoRoute(
          path: '/trips/:tripId/notes',
          builder: (context, state) =>
              Scaffold(body: Text('notes:${state.pathParameters['tripId']}')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: fakeRouter,
    );
  }

  group('TripsListScreen 清單渲染', () {
    testWidgets('渲染 N 張卡：標題、eyebrow、tone 輪替', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => fakeTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.text('我的行程'), findsOneWidget);
      expect(find.byType(TripCard), findsNWidgets(3));

      // title 優先顯示，無 title 退回 name
      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.text('kyoto-trip-2025'), findsOneWidget);
      expect(find.text('釜山美食團'), findsOneWidget);

      // eyebrow：totalDays 天；null 則不顯示
      expect(find.text('5 天'), findsOneWidget);
      expect(find.text('4 天'), findsOneWidget);

      // tone 依 index 輪替 accent → sage → pink
      final renderedCards = tester
          .widgetList<TripCard>(find.byType(TripCard))
          .toList();
      expect(renderedCards.map((card) => card.tone).toList(), [
        TripCardTone.accent,
        TripCardTone.sage,
        TripCardTone.pink,
      ]);
    });

    testWidgets('empty state：顯示「還沒有行程」hero 文案', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) async => const <TripSummary>[]),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(TripCard), findsNothing);
      expect(find.text('還沒有行程'), findsOneWidget);
    });

    testWidgets('error state：顯示重試按鈕，點擊後重新載入成功', (tester) async {
      var fetchAttempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          // 關閉 riverpod 3.x 自動 retry，讓 error state 可被穩定斷言
          retry: (retryCount, error) => null,
          overrides: [
            myTripsProvider.overrideWith((ref) async {
              fetchAttempts++;
              if (fetchAttempts == 1) {
                throw Exception('network down');
              }
              return fakeTrips;
            }),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('重試'), findsOneWidget);
      expect(find.byType(TripCard), findsNothing);

      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TripCard), findsNWidgets(3));
    });

    testWidgets('分類 tabs：全部排除 archived，mine/collab/archived 分別過濾', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => filterTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('trips-list-toolbar')), findsOneWidget);
      expect(find.byType(TripCard), findsNWidgets(3));
      expect(find.text('舊金山會議'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('trips-list-tab-mine')));
      await tester.pump();
      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('沖繩家族之旅'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('trips-list-tab-collab')));
      await tester.pump();
      expect(find.byType(TripCard), findsNWidgets(2));
      expect(find.text('釜山美食團'), findsOneWidget);
      expect(find.text('京都紅葉'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('trips-list-tab-archived')));
      await tester.pump();
      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('舊金山會議'), findsOneWidget);
    });

    testWidgets('搜尋行程名稱或國家，無結果時顯示 filtered empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => filterTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('trips-list-search-input')),
        'KR',
      );
      await tester.pump();

      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('釜山美食團'), findsOneWidget);
      expect(find.text('沖繩家族之旅'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('trips-list-search-input')),
        '不存在',
      );
      await tester.pump();

      expect(find.byType(TripCard), findsNothing);
      expect(find.text('沒有符合條件的行程。試著切換分類或調整搜尋字。'), findsOneWidget);
    });

    testWidgets('排序選出發日近時依 startDate 升冪排列', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => filterTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('trips-list-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('出發日近').last);
      await tester.pumpAndSettle();

      final renderedCards = tester
          .widgetList<TripCard>(find.byType(TripCard))
          .toList();
      expect(renderedCards.map((card) => card.trip.tripId), [
        'busan-trip-2024',
        'kyoto-trip-2025',
        'okinawa-trip-2026',
      ]);
    });

    testWidgets('尾端新增卡 → 導航到 /trips/new', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => fakeTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      final newTripCard = find.byKey(
        const ValueKey('trips-list-new-trip-card'),
      );
      await tester.scrollUntilVisible(
        newTripCard,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(newTripCard);
      await tester.pumpAndSettle();

      expect(find.text('new-trip-probe'), findsOneWidget);
    });
  });

  group('TripsListScreen 互動', () {
    testWidgets('AppBar 新增按鈕 → 導航到 /trips/new', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => fakeTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('trips-list-add-trip')));
      await tester.pumpAndSettle();

      expect(find.text('new-trip-probe'), findsOneWidget);
    });

    testWidgets('點卡片 → 導航到 /trips/:tripId', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => fakeTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();

      expect(find.text('detail:okinawa-trip-2026'), findsOneWidget);
    });

    testWidgets('卡片 action menu：edit/collab/health/notes 導向對應頁', (
      tester,
    ) async {
      Future<void> pumpTrips() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [myTripsProvider.overrideWith((ref) async => fakeTrips)],
            child: buildRouterApp(),
          ),
        );
        await tester.pump();
      }

      final scenarios = [
        (
          key: 'trip-card-menu-edit-okinawa-trip-2026',
          probe: 'edit:okinawa-trip-2026',
        ),
        (
          key: 'trip-card-menu-collab-okinawa-trip-2026',
          probe: 'collab:okinawa-trip-2026',
        ),
        (
          key: 'trip-card-menu-health-okinawa-trip-2026',
          probe: 'health:okinawa-trip-2026',
        ),
        (
          key: 'trip-card-menu-notes-okinawa-trip-2026',
          probe: 'notes:okinawa-trip-2026',
        ),
      ];

      for (final scenario in scenarios) {
        await pumpTrips();
        await tester.tap(
          find.byKey(
            const ValueKey('trip-card-menu-trigger-okinawa-trip-2026'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('刪除行程'), findsOneWidget);

        await tester.tap(find.byKey(ValueKey(scenario.key)));
        await tester.pumpAndSettle();

        expect(find.text(scenario.probe), findsOneWidget);
      }
    });

    testWidgets('長按 → bottom sheet → 編輯行程', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myTripsProvider.overrideWith((ref) async => fakeTrips)],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('編輯行程'));
      await tester.pumpAndSettle();

      expect(find.text('edit:okinawa-trip-2026'), findsOneWidget);
    });

    testWidgets(
      '長按 → bottom sheet → AlertDialog 確認 → 呼叫 deleteTrip 並 refresh',
      (tester) async {
        final mockTripRepository = MockTripRepository();
        when(
          () => mockTripRepository.fetchMyTrips(),
        ).thenAnswer((_) async => fakeTrips);
        when(
          () => mockTripRepository.deleteTrip(any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripRepositoryProvider.overrideWithValue(mockTripRepository),
            ],
            child: buildRouterApp(),
          ),
        );
        await tester.pump();
        expect(find.byType(TripCard), findsNWidgets(3));

        // 長按第一張卡 → bottom sheet
        await tester.longPress(find.text('沖繩家族之旅'));
        await tester.pumpAndSettle();
        expect(find.text('刪除行程'), findsOneWidget);

        // 點「刪除行程」→ AlertDialog 確認
        await tester.tap(find.text('刪除行程'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        // 確認刪除 → 呼叫 repository.deleteTrip + 清單 refresh
        await tester.tap(find.text('刪除'));
        await tester.pumpAndSettle();

        verify(
          () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
        ).called(1);
        // 初載 + 刪除後 invalidate refresh = 2 次
        verify(() => mockTripRepository.fetchMyTrips()).called(2);
      },
    );

    testWidgets('刪除確認對話框按「取消」→ 不呼叫 deleteTrip', (tester) async {
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.fetchMyTrips(),
      ).thenAnswer((_) async => fakeTrips);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除行程'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => mockTripRepository.deleteTrip(any()));
    });
  });
}
