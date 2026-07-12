import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/favorites/favorites_screen.dart';
import 'package:tripline/features/favorites/poi_favorite_card.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/theme/app_theme.dart';

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

const _favorites = [
  PoiFavorite(
    id: 7,
    userId: 'u-1',
    poiId: 501,
    favoritedAt: '2026-06-01T10:00:00Z',
    poiName: '美麗海水族館',
    poiType: 'attraction',
    poiRating: 4.6,
  ),
  PoiFavorite(
    id: 8,
    userId: 'u-1',
    poiId: 502,
    favoritedAt: '2026-06-02T10:00:00Z',
    poiName: '暖暮拉麵',
    poiType: 'restaurant',
  ),
];

Widget buildApp() =>
    MaterialApp(theme: AppTheme.light(), home: const FavoritesScreen());

void main() {
  group('FavoritesScreen', () {
    testWidgets('渲染收藏清單 N 卡', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      // SliverAppBar.large 會同時渲染展開大標題與收合小標題兩份,故 findsWidgets。
      expect(find.text('收藏'), findsWidgets);
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
    });

    testWidgets('empty → 還沒有收藏 hero', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith(
              (ref) => Stream.value(const <PoiFavorite>[]),
            ),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsNothing);
      expect(find.text('還沒有收藏的地點'), findsOneWidget);
      expect(find.text('去探索'), findsOneWidget); // 引導去已上線的探索
      expect(find.textContaining('即將推出'), findsNothing); // 過時文案已移除
    });

    testWidgets('error → 重試後成功', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [
            favoritesProvider.overrideWith((ref) {
              attempts++;
              if (attempts == 1) return Stream.error(Exception('network'));
              return Stream.value(_favorites);
            }),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('重試'), findsOneWidget);
      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
    });

    testWidgets('左滑 → 確認對話框 → deleteFavorite + refresh', (tester) async {
      final mockRepo = MockFavoritesRepository();
      var fetchCount = 0;
      when(mockRepo.watchFavorites).thenAnswer((_) {
        fetchCount++;
        return Stream.value(_favorites);
      });
      when(() => mockRepo.deleteFavorite(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));

      await tester.drag(
        find.byKey(const ValueKey('favorite-swipe-7')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      expect(fetchCount, 2); // 初載 + 刪除後 invalidate refresh
    });

    testWidgets('左滑 → 對話框「保留」→ 不刪除', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('favorite-swipe-7')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => mockRepo.deleteFavorite(any()));
    });

    testWidgets('點整張收藏列開啟地點詳情，列尾只保留加入行程', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();

      expect(find.text('地點詳情'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsWidgets);
      expect(find.text('取消收藏'), findsOneWidget);
      expect(find.byKey(const ValueKey('favorite-remove-7')), findsNothing);
    });

    testWidgets('AppBar 探索 action → 導到 /favorites/explore', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(const []));

      final router = GoRouter(
        initialLocation: '/favorites',
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
            routes: [
              GoRoute(
                path: 'explore',
                builder: (context, state) =>
                    const Scaffold(body: Text('EXPLORE-PROBE')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorites-explore-action')));
      await tester.pumpAndSettle();
      expect(find.text('EXPLORE-PROBE'), findsOneWidget);
    });

    testWidgets('empty「去探索」→ 導到 /favorites/explore', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(const []));

      final router = GoRouter(
        initialLocation: '/favorites',
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
            routes: [
              GoRoute(
                path: 'explore',
                builder: (context, state) =>
                    const Scaffold(body: Text('EXPLORE-PROBE')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorites-empty-explore')));
      await tester.pumpAndSettle();
      expect(find.text('EXPLORE-PROBE'), findsOneWidget);
    });
  });
}
