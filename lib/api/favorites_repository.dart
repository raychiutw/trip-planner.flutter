/// 收藏 repository：跨 trip 收藏池（`/api/poi-favorites`）。
library;

import '../models/add_to_trip.dart';
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

  /// POST /poi-favorites/:id/add-to-trip（body camelCase,startTime/endTime 必填 HH:MM）。
  /// 409 時 ApiClient 丟 ApiError（status 409,payload 含 conflictWith）。
  Future<AddToTripResult> addFavoriteToTrip({
    required int favoriteId,
    required String tripId,
    required int dayNum,
    required String startTime,
    required String endTime,
  }) async {
    final body = await _client.post(
      '/poi-favorites/$favoriteId/add-to-trip',
      body: {
        'tripId': tripId,
        'dayNum': dayNum,
        'startTime': startTime,
        'endTime': endTime,
      },
    );
    return AddToTripResult.fromJson(body as Map<String, dynamic>);
  }
}
