/// AI 聊天工單 repository（`/api/requests*`）。獨立於 TripRepository。
library;

import '../models/trip_request.dart';
import 'api_client.dart';

class RequestsRepository {
  RequestsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /requests（永遠帶 limit → 後端回 `{items,hasMore}` 物件形,避開裸陣列）。
  /// cursor 往更舊:before=<最舊 createdAt> + beforeId=<最舊 id>。
  Future<({List<TripRequest> items, bool hasMore})> fetchRequests({
    required String tripId,
    int limit = 20,
    String sort = 'desc',
    String? before,
    int? beforeId,
  }) async {
    final body = await _client.get('/requests', query: {
      'tripId': tripId,
      'limit': '$limit',
      'sort': sort,
      'before': ?before,
      'beforeId': ?beforeId?.toString(),
    });
    final map = body as Map<String, dynamic>;
    final items = (map['items'] as List<dynamic>? ?? [])
        .map((e) => TripRequest.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, hasMore: map['hasMore'] == true);
  }

  /// POST /requests（body camelCase）→ 201 新 row（或 30s 去重回 200 既有 row）。
  Future<TripRequest> sendRequest({
    required String tripId,
    required String message,
  }) async {
    final body = await _client.post(
      '/requests',
      body: {'tripId': tripId, 'message': message},
    );
    return TripRequest.fromJson(body as Map<String, dynamic>);
  }

  /// GET /requests/:id（polling 用）。
  Future<TripRequest> fetchRequest(int id) async {
    final body = await _client.get('/requests/$id');
    return TripRequest.fromJson(body as Map<String, dynamic>);
  }
}
