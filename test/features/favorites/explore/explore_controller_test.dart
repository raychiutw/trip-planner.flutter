import 'dart:async';

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

ProviderContainer _container(
  _MockPoiRepository poi,
  _MockFavoritesRepository fav,
) {
  final container = ProviderContainer(
    overrides: [
      poiRepositoryProvider.overrideWithValue(poi),
      favoritesRepositoryProvider.overrideWithValue(fav),
    ],
  );
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
    when(() => fav.fetchFavorites()).thenAnswer((_) async => const []);
    when(
      () => poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => [_poi('p1', '首里城', 'tourist_attraction')]);

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
    when(() => fav.fetchFavorites()).thenAnswer((_) async => const []);
    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);

    await controller.search('a');
    expect(container.read(exploreControllerProvider).errorMessage, '至少輸入 2 個字');
    verifyNever(
      () => poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('fineCategories 聚合細類計數，filteredResults 精確篩選', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    when(() => fav.fetchFavorites()).thenAnswer((_) async => const []);
    when(
      () => poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => [
        _poi('p1', '拉麵店', 'ramen_restaurant'),
        _poi('p3', '第二間拉麵', 'ramen_restaurant'),
        _poi('p2', '城堡', 'tourist_attraction'),
      ],
    );
    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);
    await controller.search('沖繩');

    final categories = container.read(exploreControllerProvider).fineCategories;
    expect(categories.first, (label: '拉麵店', poiType: 'restaurant', count: 2));

    controller.setCategory('拉麵店');
    final state = container.read(exploreControllerProvider);
    expect(state.filteredResults.map((p) => p.name), ['拉麵店', '第二間拉麵']);

    controller.setCategory('all');
    expect(
      container.read(exploreControllerProvider).filteredResults,
      hasLength(3),
    );
  });

  test('新搜尋會重設先前的細分類', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    when(() => fav.fetchFavorites()).thenAnswer((_) async => const []);
    when(
      () => poi.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => [_poi('p1', '拉麵店', 'ramen_restaurant')]);
    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);
    await controller.search('東京');
    controller.setCategory('拉麵店');

    await controller.search('大阪');

    expect(container.read(exploreControllerProvider).category, 'all');
  });

  test('toggleFavorite：未收藏 → find-or-create + addFavorite + 重抓', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    var listCalls = 0;
    when(() => fav.fetchFavorites()).thenAnswer((_) async {
      listCalls++;
      return const [];
    });
    when(
      () => poi.findOrCreatePoi(
        name: any(named: 'name'),
        type: any(named: 'type'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        address: any(named: 'address'),
        category: any(named: 'category'),
        placeId: any(named: 'placeId'),
      ),
    ).thenAnswer((_) async => 501);
    when(() => fav.addFavorite(any())).thenAnswer((_) async {});

    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);
    await container
        .read(exploreControllerProvider.notifier)
        .ensureSavedLoaded();

    await controller.toggleFavorite(_poi('p1', '暖暮拉麵', 'ramen_restaurant'));

    verify(
      () => poi.findOrCreatePoi(
        name: '暖暮拉麵',
        type: 'restaurant',
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        address: any(named: 'address'),
        category: 'ramen_restaurant',
        placeId: 'p1',
      ),
    ).called(1);
    verify(() => fav.addFavorite(501)).called(1);
    expect(listCalls, greaterThanOrEqualTo(2)); // 初載 + toggle 後重抓
  });

  test('toggleFavorite：名稱相同但 poiType 不一致仍視為已收藏 → 取消(delete)而非重建', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    // favorite 以 server poiType 'attraction' 儲存；search 結果 category 'aquarium'
    // 經 mapGooglePrimaryTypeToPoiType 會映射成 'activity' → 舊版 key 不一致會誤判未收藏。
    when(() => fav.fetchFavorites()).thenAnswer(
      (_) async => const [
        PoiFavorite(
          id: 7,
          userId: 'u-1',
          poiId: 501,
          favoritedAt: '2026-06-01T00:00:00Z',
          poiName: '美麗海水族館',
          poiType: 'attraction',
        ),
      ],
    );
    when(() => fav.deleteFavorite(any())).thenAnswer((_) async {});

    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);
    await controller.ensureSavedLoaded();

    final result = _poi('p9', '美麗海水族館', 'aquarium');
    expect(container.read(exploreControllerProvider).isSaved(result), isTrue);

    await controller.toggleFavorite(result);

    verify(() => fav.deleteFavorite(7)).called(1);
    verifyNever(
      () => poi.findOrCreatePoi(
        name: any(named: 'name'),
        type: any(named: 'type'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        address: any(named: 'address'),
        category: any(named: 'category'),
        placeId: any(named: 'placeId'),
      ),
    );
  });

  test('search race:後發搜尋勝出,過期結果被丟棄（sequence guard）', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    when(() => fav.fetchFavorites()).thenAnswer((_) async => const []);
    final slow = Completer<List<PoiSearchResult>>();
    when(
      () => poi.searchPois(
        q: 'AAAA',
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => slow.future);
    when(
      () => poi.searchPois(
        q: 'BBBB',
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => [_poi('pb', 'B結果', 'x')]);

    final container = _container(poi, fav);
    final controller = container.read(exploreControllerProvider.notifier);

    final firstSearch = controller.search('AAAA'); // seq=1,卡在 slow.future
    await controller.search('BBBB'); // seq=2,先回 B
    expect(
      container.read(exploreControllerProvider).results.single.name,
      'B結果',
    );

    slow.complete([_poi('pa', 'A結果', 'x')]); // A 回來但 seq 過期 → 丟棄
    await firstSearch;
    expect(
      container.read(exploreControllerProvider).results.single.name,
      'B結果',
    );
  });

  test('toggleFavorite 後 invalidate favoritesProvider（收藏 tab 會刷新）', () async {
    final poi = _MockPoiRepository();
    final fav = _MockFavoritesRepository();
    when(() => fav.fetchFavorites()).thenAnswer((_) async => const []);
    // favoritesProvider 走 watchFavorites（SWR）；invalidate → 重新訂閱再呼叫一次。
    var watchCalls = 0;
    when(() => fav.watchFavorites()).thenAnswer((_) {
      watchCalls++;
      return Stream.value(const []);
    });
    when(
      () => poi.findOrCreatePoi(
        name: any(named: 'name'),
        type: any(named: 'type'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        address: any(named: 'address'),
        category: any(named: 'category'),
        placeId: any(named: 'placeId'),
      ),
    ).thenAnswer((_) async => 501);
    when(() => fav.addFavorite(any())).thenAnswer((_) async {});

    final container = _container(poi, fav);
    container.listen(favoritesProvider, (_, _) {}); // 模擬收藏 tab 正在顯示
    await container.read(favoritesProvider.future); // favoritesProvider 首抓
    final beforeToggle = watchCalls;

    await container
        .read(exploreControllerProvider.notifier)
        .toggleFavorite(_poi('p1', '店', 'ramen_restaurant'));
    await container.read(favoritesProvider.future); // 若有 invalidate → 重抓

    // favoritesProvider 因 invalidate 重抓（收藏 tab 刷新）→ watchFavorites 再被呼叫
    expect(watchCalls, greaterThan(beforeToggle));
  });
}
