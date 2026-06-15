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
          path: '/trips/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['tripId']}')),
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
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
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
            myTripsProvider.overrideWith(
              (ref) => Stream.value(const <TripSummary>[]),
            ),
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
            myTripsProvider.overrideWith((ref) {
              fetchAttempts++;
              if (fetchAttempts == 1) {
                return Stream.error(Exception('network down'));
              }
              return Stream.value(fakeTrips);
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
  });

  group('TripsListScreen 搜尋', () {
    testWidgets('輸入關鍵字 → 只顯示符合的卡片', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
      // 初始：3 張卡全部顯示
      expect(find.byType(TripCard), findsNWidgets(3));

      // 在搜尋框輸入「沖繩」
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        '沖繩',
      );
      await tester.pump();

      // 只剩符合的卡片
      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.text('kyoto-trip-2025'), findsNothing);
      expect(find.text('釜山美食團'), findsNothing);
    });

    testWidgets('清空搜尋框 → 全部卡片還原', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      final searchField = find.byKey(const ValueKey('trips-search-field'));
      await tester.enterText(searchField, '釜山');
      await tester.pump();
      expect(find.byType(TripCard), findsOneWidget);

      // 清空搜尋框
      await tester.enterText(searchField, '');
      await tester.pump();

      // 全部卡片還原
      expect(find.byType(TripCard), findsNWidgets(3));
    });

    testWidgets('無相符結果 → 顯示空狀態文字', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        '找不到我',
      );
      await tester.pump();

      expect(find.byType(TripCard), findsNothing);
      expect(find.text('找不到符合的行程'), findsOneWidget);
    });

    testWidgets('搜尋匹配 name 欄位（無 title 的行程）', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // kyoto-trip-2025 的 title 為 null，顯示 name；搜尋 name 應能命中
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        'kyoto',
      );
      await tester.pump();

      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('kyoto-trip-2025'), findsOneWidget);
    });

    testWidgets('filtered 後 tone 輪替依新 index 計算', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // 搜尋「busan」→ 只剩第三張（原 index=2），但 filtered index=0 → accent tone
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        'busan',
      );
      await tester.pump();

      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 1);
      expect(cards.first.tone, TripCardTone.accent); // filtered index 0 → accent
    });
  });

  group('TripsListScreen 互動', () {
    testWidgets('點卡片 → 導航到 /trips/:tripId', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();

      expect(find.text('detail:okinawa-trip-2026'), findsOneWidget);
    });

    testWidgets(
      '長按 → bottom sheet → AlertDialog 確認 → 呼叫 deleteTrip 並 refresh',
      (tester) async {
        final mockTripRepository = MockTripRepository();
        when(
          () => mockTripRepository.watchMyTrips(),
        ).thenAnswer((_) => Stream.value(fakeTrips));
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
        verify(() => mockTripRepository.watchMyTrips()).called(2);
      },
    );

    testWidgets('刪除確認對話框按「取消」→ 不呼叫 deleteTrip', (tester) async {
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));

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
