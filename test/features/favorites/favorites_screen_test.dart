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
    poiAddress: '沖繩縣國頭郡本部町石川424',
    poiType: 'attraction',
    note: '雨天備案',
    poiRating: 4.6,
  ),
  PoiFavorite(
    id: 8,
    userId: 'u-1',
    poiId: 502,
    favoritedAt: '2026-06-02T10:00:00Z',
    poiName: '暖暮拉麵',
    poiAddress: '那霸市牧志2-16-10',
    poiType: 'restaurant',
    note: '晚餐候補',
  ),
];

List<PoiFavorite> _manyFavorites() => [
  for (var i = 1; i <= 200; i++)
    PoiFavorite(
      id: i,
      userId: 'u-1',
      poiId: 1000 + i,
      favoritedAt: '2026-06-${(i % 28) + 1}T10:00:00Z',
      poiName: '收藏地點 $i',
      poiAddress: i.isEven ? '東京千代田區' : '沖繩縣那霸市',
      poiType: i.isEven ? 'restaurant' : 'attraction',
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

      expect(
        find.byKey(const ValueKey('tp-root-glass-header')),
        findsOneWidget,
      );
      expect(find.text('收藏'), findsOneWidget);
      expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
      expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(
        find.byKey(const ValueKey('favorites-filter-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('account-avatar-button')),
        findsOneWidget,
      );
    });

    testWidgets('搜尋收藏會比對名稱、地址與備註', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      final searchInput = find.byKey(const ValueKey('favorites-search-input'));
      expect(searchInput, findsOneWidget);

      await tester.enterText(searchInput, '牧志');
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsNothing);

      await tester.enterText(searchInput, '雨天');
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsNothing);
    });

    testWidgets('類型篩選只保留指定類型並可切回全部', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorites-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-type-restaurant')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('favorites-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-type-all')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
    });

    testWidgets('地區篩選只保留指定地區並可切回全部', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorites-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-region-沖繩')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('favorites-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-region-all')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
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

    testWidgets('heart → 確認對話框 → deleteFavorite + refresh', (tester) async {
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

      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      expect(fetchCount, 2); // 初載 + 刪除後 invalidate refresh
    });

    testWidgets('heart → 對話框「保留」→ 不刪除', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => mockRepo.deleteFavorite(any()));
    });

    testWidgets('選取多個收藏 → 確認批次刪除 → 逐筆 deleteFavorite + refresh', (
      tester,
    ) async {
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

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選取'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorite-select-8')));
      await tester.pump();

      expect(find.byKey(const ValueKey('favorites-toolbar')), findsOneWidget);
      expect(find.text('已選 2 個'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('favorites-delete-selected')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('確定刪除收藏？'), findsOneWidget);
      expect(find.text('即將刪除 2 個收藏景點，此操作無法復原。'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      verify(() => mockRepo.deleteFavorite(8)).called(1);
      expect(fetchCount, 2); // 初載 + 批次刪除後 invalidate refresh
    });

    testWidgets('收藏達 200 筆時分頁，每頁 24 筆且篩選重置頁碼', (tester) async {
      final favorites = _manyFavorites();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      expect(find.text('收藏地點 1'), findsOneWidget);
      expect(find.text('收藏地點 25'), findsNothing);

      final pagination = find.byKey(const ValueKey('favorites-pagination'));
      final scrollView = find.byType(CustomScrollView);
      for (var i = 0; i < 8 && pagination.evaluate().isEmpty; i++) {
        await tester.drag(scrollView, const Offset(0, -500));
        await tester.pump();
      }
      expect(pagination, findsOneWidget);
      expect(find.text('1-24 / 200'), findsOneWidget);
      expect(find.text('第 1 / 9 頁'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('favorites-page-next')));
      await tester.pump();

      expect(find.text('25-48 / 200'), findsOneWidget);
      expect(find.text('第 2 / 9 頁'), findsOneWidget);

      await tester.fling(scrollView, const Offset(0, 5000), 10000);
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const ValueKey('favorites-search-input'));
      await tester.enterText(searchInput, '收藏地點 1');
      await tester.pump();

      expect(find.text('收藏地點 1', skipOffstage: false), findsWidgets);
      for (var i = 0; i < 8 && pagination.evaluate().isEmpty; i++) {
        await tester.drag(scrollView, const Offset(0, -500));
        await tester.pump();
      }
      expect(find.text('第 1 / 5 頁'), findsOneWidget);
      expect(find.byType(PoiFavoriteCard), findsWidgets);
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
