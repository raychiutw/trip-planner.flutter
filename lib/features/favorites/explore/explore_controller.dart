/// 探索畫面狀態機（query/region/category/results/savedMap）。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/favorites_repository.dart';
import '../../../api/poi_repository.dart';
import '../../../api/providers.dart';
import '../../../models/poi_favorite.dart';
import '../../../models/poi_search_result.dart';
import '../../../models/poi_type.dart';
import '../favorites_providers.dart';

final poiRepositoryProvider = Provider<PoiRepository>(
  (ref) => PoiRepository(client: ref.watch(apiClientProvider)),
);

typedef ExploreCategory = ({String label, String poiType, int count});

/// 探索畫面不可變狀態。
class ExploreState {
  const ExploreState({
    this.query = '',
    this.region = '全部地區',
    this.category = 'all',
    this.results = const [],
    this.savedMap = const {},
    this.searching = false,
    this.savingPlaceIds = const {},
    this.errorMessage,
    this.hasSearched = false,
  });

  final String query;
  final String region;
  final String category;
  final List<PoiSearchResult> results;
  final Map<String, int> savedMap; // poiName(trim) → favoriteId
  final bool searching;
  final Set<String> savingPlaceIds;
  final String? errorMessage;
  final bool hasSearched;

  /// 依搜尋結果動態聚合 Google primaryType 細分類。
  List<ExploreCategory> get fineCategories {
    final categories = <String, ({String poiType, int count, int order})>{};
    for (final poi in results) {
      final label = poiCategoryLabel(poi.category) ?? '其他';
      final existing = categories[label];
      categories[label] = (
        poiType:
            existing?.poiType ?? mapGooglePrimaryTypeToPoiType(poi.category),
        count: (existing?.count ?? 0) + 1,
        order: existing?.order ?? categories.length,
      );
    }
    final sorted = [
      for (final entry in categories.entries)
        (
          label: entry.key,
          poiType: entry.value.poiType,
          count: entry.value.count,
        ),
    ];
    sorted.sort((a, b) {
      final countOrder = b.count.compareTo(a.count);
      return countOrder != 0
          ? countOrder
          : categories[a.label]!.order.compareTo(categories[b.label]!.order);
    });
    return sorted;
  }

  String get activeCategoryLabel => category == 'all' ? '為你推薦' : category;

  /// category client-side filter（精確比對顯示中的 Google 細分類）。
  List<PoiSearchResult> get filteredResults {
    if (category == 'all') return results;
    return results
        .where((poi) => (poiCategoryLabel(poi.category) ?? '其他') == category)
        .toList();
  }

  bool isSaved(PoiSearchResult poi) => savedMap.containsKey(_savedKey(poi));

  ExploreState copyWith({
    String? query,
    String? region,
    String? category,
    List<PoiSearchResult>? results,
    Map<String, int>? savedMap,
    bool? searching,
    Set<String>? savingPlaceIds,
    Object? errorMessage = _sentinel,
    bool? hasSearched,
  }) {
    return ExploreState(
      query: query ?? this.query,
      region: region ?? this.region,
      category: category ?? this.category,
      results: results ?? this.results,
      savedMap: savedMap ?? this.savedMap,
      searching: searching ?? this.searching,
      savingPlaceIds: savingPlaceIds ?? this.savingPlaceIds,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }

  static const _sentinel = Object();
}

// 收藏比對只用「名稱」作 key:search result 帶 Google category、favorite 帶
// server 正規化後的 poiType,兩者經 mapGooglePrimaryTypeToPoiType 後可能不一致
//（find-or-create 命中既有 POI 時 type 不重算）→ 用名稱單一來源避免取消收藏失效。
String _savedKey(PoiSearchResult poi) => poi.name.trim();

class ExploreController extends Notifier<ExploreState> {
  int _requestSeq = 0;
  CancelToken? _cancelToken;

  @override
  ExploreState build() => const ExploreState();

  PoiRepository get _poi => ref.read(poiRepositoryProvider);
  FavoritesRepository get _fav => ref.read(favoritesRepositoryProvider);

  /// 載入已收藏 map（進頁呼叫一次）。
  Future<void> ensureSavedLoaded() async {
    try {
      final favorites = await _fav.fetchFavorites();
      state = state.copyWith(savedMap: _buildSavedMap(favorites));
    } on Exception {
      // 收藏 map 載入失敗不阻擋搜尋
    }
  }

  void setRegion(String region) => state = state.copyWith(region: region);
  void setCategory(String category) =>
      state = state.copyWith(category: category);

  /// submit 搜尋（最少 2 字;sequence guard + CancelToken 防 race）。
  Future<void> search(String rawQuery) async {
    final q = rawQuery.trim();
    state = state.copyWith(query: q, errorMessage: null);
    if (q.length < 2) {
      ++_requestSeq;
      _cancelToken?.cancel('query too short');
      state = state.copyWith(
        category: 'all',
        results: const [],
        searching: false,
        errorMessage: null,
      );
      return;
    }
    final seq = ++_requestSeq;
    _cancelToken?.cancel('superseded');
    final cancelToken = _cancelToken = CancelToken();
    state = state.copyWith(searching: true, errorMessage: null);
    try {
      final results = await _poi.searchPois(
        q: q,
        region: state.region,
        cancelToken: cancelToken,
      );
      if (seq != _requestSeq) return; // 過期結果丟棄
      state = state.copyWith(
        category: 'all',
        results: results,
        searching: false,
        hasSearched: true,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || seq != _requestSeq) return;
      state = state.copyWith(
        searching: false,
        hasSearched: true,
        errorMessage: '搜尋失敗,請稍後再試',
      );
    } on Exception {
      if (seq != _requestSeq) return;
      state = state.copyWith(
        searching: false,
        hasSearched: true,
        errorMessage: '搜尋失敗,請稍後再試',
      );
    }
  }

  /// heart toggle:未收藏→find-or-create+addFavorite;已收藏→removeFavorite。
  Future<void> toggleFavorite(PoiSearchResult poi) async {
    if (state.savingPlaceIds.contains(poi.placeId)) return;
    state = state.copyWith(
      savingPlaceIds: {...state.savingPlaceIds, poi.placeId},
    );
    try {
      final key = _savedKey(poi);
      final existingId = state.savedMap[key];
      if (existingId != null) {
        await _fav.deleteFavorite(existingId);
      } else {
        final poiId = await _poi.findOrCreatePoi(
          name: poi.name,
          type: mapGooglePrimaryTypeToPoiType(poi.category),
          lat: poi.lat,
          lng: poi.lng,
          address: poi.address,
          category: poi.category,
          placeId: poi.placeId,
        );
        await _fav.addFavorite(poiId);
      }
      final favorites = await _fav.fetchFavorites();
      state = state.copyWith(savedMap: _buildSavedMap(favorites));
      ref.invalidate(favoritesProvider);
    } on Exception {
      state = state.copyWith(errorMessage: '收藏操作失敗,請稍後再試');
    } finally {
      state = state.copyWith(
        savingPlaceIds: {...state.savingPlaceIds}..remove(poi.placeId),
      );
    }
  }

  static Map<String, int> _buildSavedMap(List<PoiFavorite> favorites) {
    return {
      for (final f in favorites)
        if (f.poiName != null) f.poiName!.trim(): f.id,
    };
  }
}

final exploreControllerProvider =
    NotifierProvider<ExploreController, ExploreState>(ExploreController.new);
