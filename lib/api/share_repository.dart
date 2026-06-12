/// 分享連結 repository(`/api/trips/:id/shares*`)。需 write permission。
library;

import '../models/trip_share.dart';
import 'api_client.dart';

class ShareRepository {
  ShareRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /trips/:id/shares → {shares:[...]}。
  Future<List<TripShare>> fetchShares(String tripId) async {
    final body = await _client.get(
      '/trips/${Uri.encodeComponent(tripId)}/shares',
    );
    final list =
        (body as Map<String, dynamic>)['shares'] as List<dynamic>? ?? const [];
    return list
        .map((e) => TripShare.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /trips/:id/shares → ShareLink(raw token 只回一次)。
  Future<ShareLink> createShare(String tripId, {String? label}) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/shares',
      body: {'label': ?label},
    );
    return ShareLink.fromJson(body as Map<String, dynamic>);
  }

  /// PATCH /trips/:id/shares/:shareId {action:'revoke'}。
  Future<void> revokeShare(String tripId, int shareId) => _client.patch(
    '/trips/${Uri.encodeComponent(tripId)}/shares/$shareId',
    body: {'action': 'revoke'},
  );
}
