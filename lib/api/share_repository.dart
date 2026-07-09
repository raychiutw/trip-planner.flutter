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
  Future<ShareLink> createShare(
    String tripId, {
    String? label,
    List<String>? visibleSections,
    int? expiresAt,
    bool? anonymous,
  }) async {
    final requestBody = <String, Object?>{};
    if (label != null) requestBody['label'] = label;
    if (visibleSections != null) {
      requestBody['visibleSections'] = visibleSections;
    }
    if (expiresAt != null) requestBody['expiresAt'] = expiresAt;
    if (anonymous != null) requestBody['anonymous'] = anonymous;

    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/shares',
      body: requestBody,
    );
    return ShareLink.fromJson(body as Map<String, dynamic>);
  }

  /// PATCH /trips/:id/shares/:shareId {action:'update', ...patch}。
  Future<void> updateShare(
    String tripId,
    int shareId, {
    String? label,
    List<String>? visibleSections,
    int? expiresAt,
    bool clearExpiresAt = false,
    bool? anonymous,
  }) {
    if (expiresAt != null && clearExpiresAt) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'expiresAt 與 clearExpiresAt 只能擇一',
      );
    }

    final requestBody = <String, Object?>{'action': 'update'};
    if (label != null) requestBody['label'] = label;
    if (visibleSections != null) {
      requestBody['visibleSections'] = visibleSections;
    }
    if (expiresAt != null || clearExpiresAt) {
      requestBody['expiresAt'] = expiresAt;
    }
    if (anonymous != null) requestBody['anonymous'] = anonymous;

    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/shares/$shareId',
      body: requestBody,
    );
  }

  /// PATCH /trips/:id/shares/:shareId {action:'rotate'}。
  Future<RotatedShareLink> rotateShare(String tripId, int shareId) async {
    final body = await _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/shares/$shareId',
      body: {'action': 'rotate'},
    );
    return RotatedShareLink.fromJson(body as Map<String, dynamic>);
  }

  /// PATCH /trips/:id/shares/:shareId {action:'revoke'}。
  Future<void> revokeShare(String tripId, int shareId) => _client.patch(
    '/trips/${Uri.encodeComponent(tripId)}/shares/$shareId',
    body: {'action': 'revoke'},
  );

  /// DELETE /trips/:id/shares/:shareId。
  Future<void> deleteShare(String tripId, int shareId) =>
      _client.delete('/trips/${Uri.encodeComponent(tripId)}/shares/$shareId');
}
