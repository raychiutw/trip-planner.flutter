/// 收藏 repository：跨 trip 收藏池（`/api/poi-favorites`）。
library;

import '../models/poi_favorite.dart';
import 'api_client.dart';

/// 對應 `/api/poi-favorites`。
class FavoritesRepository {
  FavoritesRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /poi-favorites。
  Future<List<PoiFavorite>> fetchFavorites() async {
    final responseBody = await _client.get('/poi-favorites');
    return (responseBody as List<dynamic>)
        .map((favoriteJson) =>
            PoiFavorite.fromJson(favoriteJson as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /poi-favorites/:id（mutation，ApiClient 自動帶 CSRF Origin）。
  Future<void> deleteFavorite(int id) => _client.delete('/poi-favorites/$id');

  /// POST /poi-favorites（camelCase body）。重複收藏後端回 409。
  Future<void> addFavorite(int poiId) =>
      _client.post('/poi-favorites', body: {'poiId': poiId});
}
