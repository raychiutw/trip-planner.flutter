import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart';
import 'package:tripline/features/favorites/explore/explore_screen.dart';
import 'package:tripline/features/favorites/explore/poi_search_card.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockPoiRepository extends Mock implements PoiRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

PoiSearchResult _poi(String id, String name, String category) =>
    PoiSearchResult(placeId: id, name: name, category: category);

void main() {
  late _MockPoiRepository poi;
  late _MockFavoritesRepository fav;

  setUp(() {
    poi = _MockPoiRepository();
    fav = _MockFavoritesRepository();
    when(() => fav.fetchFavorites()).thenAnswer((_) async => const []);
    when(() => poi.searchPois(
          q: any(named: 'q'),
          limit: any(named: 'limit'),
          region: any(named: 'region'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => [
          _poi('p1', '拉麵店', 'ramen_restaurant'),
          _poi('p2', '首里城', 'tourist_attraction'),
        ]);
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          poiRepositoryProvider.overrideWithValue(poi),
          favoritesRepositoryProvider.overrideWithValue(fav),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ExploreScreen()),
      );

  testWidgets('進頁 auto-search seed → 顯示結果卡', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('探索'), findsOneWidget); // AppBar
    expect(find.byType(PoiSearchCard), findsNWidgets(2));
    verify(() => poi.searchPois(
        q: '東京',
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'))).called(1);
  });

  testWidgets('分類 chip「美食」→ 只剩拉麵店', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('美食'));
    await tester.pumpAndSettle();

    expect(find.byType(PoiSearchCard), findsOneWidget);
    expect(find.text('拉麵店'), findsOneWidget);
    expect(find.text('首里城'), findsNothing);
  });

  testWidgets('手動搜尋 <2 字 → SnackBar 提示', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('explore-search-field')), 'a');
    await tester.tap(find.byKey(const ValueKey('explore-search-button')));
    await tester.pump();

    expect(find.text('至少輸入 2 個字'), findsOneWidget);
  });

  testWidgets('點 heart → 觸發 find-or-create + addFavorite', (tester) async {
    when(() => poi.findOrCreatePoi(
          name: any(named: 'name'),
          type: any(named: 'type'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          address: any(named: 'address'),
          category: any(named: 'category'),
          placeId: any(named: 'placeId'),
        )).thenAnswer((_) async => 501);
    when(() => fav.addFavorite(any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('poi-heart-p1')));
    await tester.pumpAndSettle();

    verify(() => fav.addFavorite(501)).called(1);
  });

  testWidgets('搜尋無結果（query ≥2）→ 顯示「沒有找到」空狀態', (tester) async {
    when(() => poi.searchPois(
          q: any(named: 'q'),
          limit: any(named: 'limit'),
          region: any(named: 'region'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => const []);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(PoiSearchCard), findsNothing);
    expect(find.textContaining('沒有找到'), findsOneWidget);
  });
}
