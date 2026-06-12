/// POI 搜尋與建立 repository（`/api/poi-search`、`/api/pois/find-or-create`）。
library;

import 'package:dio/dio.dart';

import '../models/poi_search_result.dart';
import 'api_client.dart';

class PoiRepository {
  PoiRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /poi-search?q=&limit=&region=（region「全部地區」/null/空 則省略）。
  Future<List<PoiSearchResult>> searchPois({
    required String q,
    int limit = 20,
    String? region,
    CancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{'q': q, 'limit': '$limit'};
    final trimmedRegion = region?.trim();
    if (trimmedRegion != null &&
        trimmedRegion.isNotEmpty &&
        trimmedRegion != '全部地區') {
      query['region'] = trimmedRegion;
    }
    final responseBody = await _client.get(
      '/poi-search',
      query: query,
      cancelToken: cancelToken,
    );
    final results =
        (responseBody as Map<String, dynamic>)['results'] as List<dynamic>? ??
        const [];
    return results
        .map(
          (poiJson) =>
              PoiSearchResult.fromJson(poiJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// POST /pois/find-or-create（body 全 snake_case）→ 後端 pois PK。
  /// `type` 須先過 mapGooglePrimaryTypeToPoiType,否則後端 503。
  Future<int> findOrCreatePoi({
    required String name,
    required String type,
    double? lat,
    double? lng,
    String? address,
    String? category,
    String source = 'user-explore',
    String? placeId,
  }) async {
    final responseBody = await _client.post(
      '/pois/find-or-create',
      body: {
        'name': name,
        'type': type,
        'lat': lat,
        'lng': lng,
        'address': address,
        'category': category,
        'source': source,
        'place_id': placeId,
      },
    );
    return ((responseBody as Map<String, dynamic>)['id'] as num).toInt();
  }
}
