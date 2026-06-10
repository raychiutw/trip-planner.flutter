import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/poi_search_result.dart';

class _MockPoiRepository extends Mock implements PoiRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

PoiSearchResult _poi(String placeId, String name, String category) =>
    PoiSearchResult(placeId: placeId, name: name, category: category);

ProviderContainer _container(_MockPoiRepository poi, _MockFavoritesRepository fav) {
  final container = ProviderContainer(overrides: [
    poiRepositoryProvider.overrideWithValue(poi),
    favoritesRepositoryProvider.overrideWithValue(fav),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('search：成功更新 results + searching=false', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    when(() => fav.listFavorites()).thenAnswer((_) async => const []);
    when(() => poi.searchPois(
            q: any(named: 'q'),
            limit: any(named: 'limit'),
            region: any(named: 'region'),
            cancelToken: any(named: 'cancelToken')))
        .thenAnswer((_) async => [_poi('p1', '首里城', 'tourist_attraction')]);

    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);

    await controller.search('首里城');
    final state = container.read(exploreControllerProvider);
    expect(state.results.single.name, '首里城');
    expect(state.searching, isFalse);
  });

  test('search：q < 2 字 → 不呼叫 repo,設 error 訊息', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    when(() => fav.listFavorites()).thenAnswer((_) async => const []);
    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);

    await controller.search('a');
    expect(container.read(exploreControllerProvider).errorMessage, '至少輸入 2 個字');
    verifyNever(() => poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken')));
  });

  test('filteredResults：分類 client-side filter（美食）', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    when(() => fav.listFavorites()).thenAnswer((_) async => const []);
    when(() => poi.searchPois(
            q: any(named: 'q'),
            limit: any(named: 'limit'),
            region: any(named: 'region'),
            cancelToken: any(named: 'cancelToken')))
        .thenAnswer((_) async => [
              _poi('p1', '拉麵店', 'ramen_restaurant'),
              _poi('p2', '城堡', 'tourist_attraction'),
            ]);
    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);
    await controller.search('沖繩');

    controller.setCategory('food');
    final state = container.read(exploreControllerProvider);
    expect(state.filteredResults.map((p) => p.name), ['拉麵店']);

    controller.setCategory('all');
    expect(container.read(exploreControllerProvider).filteredResults, hasLength(2));
  });

  test('toggleFavorite：未收藏 → find-or-create + addFavorite + 重抓', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    var listCalls = 0;
    when(() => fav.listFavorites()).thenAnswer((_) async {
      listCalls++;
      return const [];
    });
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

    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);
    await container.read(exploreControllerProvider.notifier).ensureSavedLoaded();

    await controller.toggleFavorite(_poi('p1', '暖暮拉麵', 'ramen_restaurant'));

    verify(() => poi.findOrCreatePoi(
        name: '暖暮拉麵',
        type: 'restaurant',
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        address: any(named: 'address'),
        category: 'ramen_restaurant',
        placeId: 'p1')).called(1);
    verify(() => fav.addFavorite(501)).called(1);
    expect(listCalls, greaterThanOrEqualTo(2)); // 初載 + toggle 後重抓
  });
}
