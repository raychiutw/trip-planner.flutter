/// 行程資料 repository：my-trips / trips / days / notes / stats / profile。
library;

import '../models/day.dart';
import '../models/notes.dart';
import '../models/poi.dart';
import '../models/trip.dart';
import '../models/user.dart';
import 'api_client.dart';

/// 對應 `/api/my-trips`、`/api/trips/*`、`/api/account/*`。
class TripRepository {
  TripRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /my-trips。
  Future<List<TripSummary>> fetchMyTrips() async {
    final responseBody = await _client.get('/my-trips');
    return (responseBody as List<dynamic>)
        .map(
          (tripJson) => TripSummary.fromJson(tripJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// GET /trips（published 行程清單）。
  Future<List<Trip>> fetchTrips() async {
    final responseBody = await _client.get('/trips');
    return (responseBody as List<dynamic>)
        .map((tripJson) => Trip.fromJson(tripJson as Map<String, dynamic>))
        .toList();
  }

  /// GET /trips/:id。
  Future<Trip> fetchTrip(String id) async {
    final responseBody = await _client.get('/trips/${Uri.encodeComponent(id)}');
    return Trip.fromJson(responseBody as Map<String, dynamic>);
  }

  /// GET /trips/:id/days?all=1（完整 timeline）。
  Future<List<TripDay>> fetchDays(String id) async {
    final responseBody = await _client.get(
      '/trips/${Uri.encodeComponent(id)}/days',
      query: {'all': '1'},
    );
    return (responseBody as List<dynamic>)
        .map((dayJson) => TripDay.fromJson(dayJson as Map<String, dynamic>))
        .toList();
  }

  /// GET /trips/:id/notes（5 區聚合）。
  Future<TripNotes> fetchNotes(String id) async {
    final responseBody = await _client.get(
      '/trips/${Uri.encodeComponent(id)}/notes',
    );
    return TripNotes.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /trips/:id（限 owner/admin）。
  Future<void> deleteTrip(String id) =>
      _client.delete('/trips/${Uri.encodeComponent(id)}');

  /// GET /account/stats。
  Future<AccountStats> fetchStats() async {
    final responseBody = await _client.get('/account/stats');
    return AccountStats.fromJson(responseBody as Map<String, dynamic>);
  }

  /// PATCH /account/profile（displayName 傳 null 表示清除）。
  Future<UserInfo> updateProfile({String? displayName}) async {
    final responseBody = await _client.patch(
      '/account/profile',
      body: {'displayName': displayName},
    );
    return UserInfo.fromJson(responseBody as Map<String, dynamic>);
  }

  /// GET /poi-favorites。
  Future<List<PoiFavorite>> fetchPoiFavorites() async {
    final responseBody = await _client.get('/poi-favorites');
    return (responseBody as List<dynamic>)
        .map(
          (favoriteJson) =>
              PoiFavorite.fromJson(favoriteJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// GET /poi-search?q=...&region=...&limit=...。
  Future<List<PoiSearchResult>> searchPois({
    required String query,
    String? region,
    int limit = 20,
  }) async {
    final trimmedQuery = query.trim();
    final trimmedRegion = region?.trim();
    final responseBody = await _client.get(
      '/poi-search',
      query: {
        'q': trimmedQuery,
        if (trimmedRegion != null && trimmedRegion.isNotEmpty)
          'region': trimmedRegion,
        'limit': '$limit',
      },
    );
    final results =
        (responseBody as Map<String, dynamic>)['results'] as List<dynamic>;
    return results
        .map(
          (resultJson) =>
              PoiSearchResult.fromJson(resultJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// POST /pois/find-or-create，回傳 POI table id。
  Future<int> findOrCreatePoi(PoiSearchResult poi) async {
    final responseBody = await _client.post(
      '/pois/find-or-create',
      body: {
        'name': poi.name,
        'type': mapPoiCategoryToType(poi.category),
        'lat': poi.lat,
        'lng': poi.lng,
        'address': poi.address ?? '',
        'category': poi.category ?? '',
        'source': 'user-explore',
        'country': poi.country,
        'place_id': poi.placeId,
      },
    );
    return ((responseBody as Map<String, dynamic>)['id'] as num).toInt();
  }

  /// POST /poi-favorites。
  Future<PoiFavorite> createPoiFavorite({
    required int poiId,
    String? note,
  }) async {
    final responseBody = await _client.post(
      '/poi-favorites',
      body: {'poiId': poiId, 'note': ?note},
    );
    return PoiFavorite.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /poi-favorites/:id。
  Future<void> deletePoiFavorite(int id) =>
      _client.delete('/poi-favorites/${Uri.encodeComponent('$id')}');

  /// POST /poi-favorites/:id/add-to-trip。
  Future<PoiFavoriteAddToTripResult> addPoiFavoriteToTrip(
    int favoriteId, {
    required String tripId,
    required int dayNum,
    required String startTime,
    required String endTime,
  }) async {
    final responseBody = await _client.post(
      '/poi-favorites/${Uri.encodeComponent('$favoriteId')}/add-to-trip',
      body: {
        'tripId': tripId,
        'dayNum': dayNum,
        'startTime': startTime,
        'endTime': endTime,
      },
    );
    return PoiFavoriteAddToTripResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// POST /trips/:id/days/:num/entries，用 Explore direct-mode POI 直建 entry。
  Future<void> createEntryFromPoiSearchResult({
    required String tripId,
    required int dayNum,
    required PoiSearchResult poi,
    required String startTime,
    required String endTime,
  }) {
    final time = startTime.trim().isNotEmpty && endTime.trim().isNotEmpty
        ? '${startTime.trim()}-${endTime.trim()}'
        : null;
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/days/$dayNum/entries',
      body: {
        'name': poi.name,
        'note': ?poi.address,
        'lat': poi.lat,
        'lng': poi.lng,
        'source': 'google',
        'time': ?time,
        'poi_type': mapPoiCategoryToType(poi.category),
      },
    );
  }

  /// POST /trips/:id/recompute-travel?day=N。
  Future<void> recomputeTravel(String tripId, {int? dayNum}) {
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/recompute-travel',
      query: {if (dayNum != null) 'day': '$dayNum'},
    );
  }
}
