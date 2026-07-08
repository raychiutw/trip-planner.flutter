import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/favorites_screen.dart';
import 'package:tripline/models/poi.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const fakeFavorites = [
    PoiFavorite(
      id: 77,
      userId: 'user-1',
      poiId: 501,
      favoritedAt: '2026-07-08T10:00:00Z',
      note: '黃昏時段去',
      poiName: '首里城公園',
      poiAddress: '沖繩縣那霸市',
      poiLat: 26.217,
      poiLng: 127.719,
      poiType: 'attraction',
      poiRating: 4.4,
      usages: [
        PoiFavoriteUsage(
          tripId: 'okinawa-trip-2026',
          tripName: 'Okinawa',
          dayNum: 2,
          dayDate: '2026-04-24',
          entryId: 101,
        ),
      ],
    ),
    PoiFavorite(
      id: 78,
      userId: 'user-1',
      poiId: 502,
      favoritedAt: '2026-07-08T11:00:00Z',
      poiName: '國際通',
      poiType: 'shopping',
      usages: [],
    ),
  ];

  Widget buildRouterApp() {
    final fakeRouter = GoRouter(
      initialLocation: '/favorites',
      routes: [
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
          routes: [
            GoRoute(
              path: ':favoriteId/add-to-trip',
              builder: (context, state) => Scaffold(
                body: Text(
                  'add-favorite:${state.pathParameters['favoriteId']}',
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) =>
              const Scaffold(body: Text('explore-page')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: fakeRouter,
    );
  }

  group('FavoritesScreen 清單渲染', () {
    testWidgets('顯示收藏卡、類型、評分、usage badge 與探索入口', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiFavoritesProvider.overrideWith((ref) async => fakeFavorites),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('首里城公園'), findsOneWidget);
      expect(find.text('國際通'), findsOneWidget);
      expect(find.text('景點'), findsOneWidget);
      expect(find.text('4.4'), findsOneWidget);
      expect(find.text('已排入 1 個行程'), findsOneWidget);
      expect(find.byTooltip('探索景點'), findsOneWidget);
    });

    testWidgets('empty state 顯示探索 CTA', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiFavoritesProvider.overrideWith(
              (ref) async => const <PoiFavorite>[],
            ),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.text('還沒有收藏'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '探索景點'), findsOneWidget);
    });

    testWidgets('error state 點重試後重新載入成功', (tester) async {
      var fetchAttempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [
            poiFavoritesProvider.overrideWith((ref) async {
              fetchAttempts++;
              if (fetchAttempts == 1) {
                throw Exception('network down');
              }
              return fakeFavorites;
            }),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('載入收藏失敗'), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump();

      expect(find.text('首里城公園'), findsOneWidget);
    });
  });

  group('FavoritesScreen 互動', () {
    testWidgets('點 AppBar 探索 icon 導航到 /explore', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiFavoritesProvider.overrideWith((ref) async => fakeFavorites),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('探索景點'));
      await tester.pumpAndSettle();

      expect(find.text('explore-page'), findsOneWidget);
    });

    testWidgets('點加入行程導向 /favorites/:id/add-to-trip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiFavoritesProvider.overrideWith((ref) async => fakeFavorites),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '加入行程').first);
      await tester.pumpAndSettle();

      expect(find.text('add-favorite:77'), findsOneWidget);
    });

    testWidgets('點取消收藏呼叫 deletePoiFavorite 並刷新清單', (tester) async {
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.fetchPoiFavorites(),
      ).thenAnswer((_) async => fakeFavorites);
      when(
        () => mockTripRepository.deletePoiFavorite(any()),
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

      await tester.tap(find.byTooltip('取消收藏').first);
      await tester.pump();

      verify(() => mockTripRepository.deletePoiFavorite(77)).called(1);
      verify(
        () => mockTripRepository.fetchPoiFavorites(),
      ).called(greaterThan(1));
    });
  });
}
