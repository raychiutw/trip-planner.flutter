/// 共編 repository(`/api/permissions*`、`/api/invitations*`)。
/// 端點不在 /trips/:id 下;tripId 走 query/body。回應兩種形:permissions 裸陣列、
/// invitations `{items}`。管理權限限 owner/admin(他人 403)。無 OCC。
library;

import '../models/trip_member.dart';
import 'api_client.dart';

class CollabRepository {
  CollabRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /permissions?tripId= → 裸陣列。
  Future<List<TripMember>> fetchMembers(String tripId) async {
    final body = await _client.get('/permissions', query: {'tripId': tripId});
    return (body as List<dynamic>)
        .map((e) => TripMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /invitations?tripId= → {items:[...]}。
  Future<List<TripInvite>> fetchInvites(String tripId) async {
    final body = await _client.get('/invitations', query: {'tripId': tripId});
    final items =
        (body as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => TripInvite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /invitations?token= → public invitation preview for accept flow.
  Future<InvitationDetails> fetchInvitation(String token) async {
    final body = await _client.get(
      '/invitations',
      query: {'token': token.trim()},
      writeCache: false,
      fallbackToCache: false,
    );
    return InvitationDetails.fromJson(body as Map<String, dynamic>);
  }

  /// POST /invitations/accept {token} → accepted trip summary.
  Future<InvitationAcceptResult> acceptInvitation(String token) async {
    final body = await _client.post(
      '/invitations/accept',
      body: {'token': token.trim()},
    );
    return InvitationAcceptResult.fromJson(body as Map<String, dynamic>);
  }

  /// POST /permissions(camelCase body)。role 預設 member;201(去識別化,不分既有/新 email)。
  Future<void> invite({
    required String tripId,
    required String email,
    String role = 'member',
  }) => _client.post(
    '/permissions',
    body: {'email': email, 'tripId': tripId, 'role': role},
  );

  /// PATCH /permissions/:id(只接受 member|viewer)。
  Future<void> changeRole(int permissionId, String role) =>
      _client.patch('/permissions/$permissionId', body: {'role': role});

  /// DELETE /permissions/:id(不可移除 owner)。
  Future<void> removeMember(int permissionId) =>
      _client.delete('/permissions/$permissionId');

  /// POST /invitations/revoke(撤銷待接受邀請)。
  Future<void> revokeInvite({required String tripId, required String email}) =>
      _client.post(
        '/invitations/revoke',
        body: {'tripId': tripId, 'email': email},
      );
}
