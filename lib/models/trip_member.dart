/// 共編 models:已授權成員(trip_permissions)與待接受邀請(trip_invitations)。
library;

/// 行程成員(GET /permissions 的一列;`id` 是 permission row PK,供 PATCH/DELETE)。
class TripMember {
  const TripMember({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    this.userId,
  });

  final int id;
  final String email;
  final String? displayName;
  final String role; // owner | admin | member | viewer
  final String? userId;

  /// owner/admin 不可改 role、不可移除。
  bool get isManageable => role != 'owner' && role != 'admin';

  factory TripMember.fromJson(Map<String, dynamic> json) => TripMember(
    id: (json['id'] as num).toInt(),
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String?,
    role: json['role'] as String? ?? 'member',
    userId: json['userId'] as String?,
  );
}

/// 待接受邀請(GET /invitations 的一列;`id` 是 token_hash)。
class TripInvite {
  const TripInvite({
    required this.id,
    required this.invitedEmail,
    this.expiresAt,
    this.daysRemaining,
    this.isExpired = false,
  });

  final String id;
  final String invitedEmail;
  final String? expiresAt;
  final int? daysRemaining;
  final bool isExpired;

  factory TripInvite.fromJson(Map<String, dynamic> json) => TripInvite(
    id: json['id']?.toString() ?? '',
    invitedEmail: json['invitedEmail'] as String? ?? '',
    expiresAt: json['expiresAt'] as String?,
    daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
    isExpired: json['isExpired'] == 1 || json['isExpired'] == true,
  );
}

class InvitationDetails {
  const InvitationDetails({
    required this.tripId,
    required this.tripTitle,
    required this.invitedEmail,
    this.inviterDisplayName,
    required this.inviterEmail,
    required this.expiresAt,
  });

  final String tripId;
  final String tripTitle;
  final String invitedEmail;
  final String? inviterDisplayName;
  final String inviterEmail;
  final String expiresAt;

  factory InvitationDetails.fromJson(Map<String, dynamic> json) =>
      InvitationDetails(
        tripId: _stringValue(json, 'tripId', 'trip_id'),
        tripTitle: _stringValue(json, 'tripTitle', 'trip_title'),
        invitedEmail: _stringValue(json, 'invitedEmail', 'invited_email'),
        inviterDisplayName:
            json['inviterDisplayName'] as String? ??
            json['inviter_display_name'] as String?,
        inviterEmail: _stringValue(json, 'inviterEmail', 'inviter_email'),
        expiresAt: _stringValue(json, 'expiresAt', 'expires_at'),
      );
}

class InvitationAcceptResult {
  const InvitationAcceptResult({required this.tripId, required this.tripTitle});

  final String tripId;
  final String tripTitle;

  factory InvitationAcceptResult.fromJson(Map<String, dynamic> json) =>
      InvitationAcceptResult(
        tripId: _stringValue(json, 'tripId', 'trip_id'),
        tripTitle: _stringValue(json, 'tripTitle', 'trip_title'),
      );
}

String _stringValue(
  Map<String, dynamic> json,
  String camelKey,
  String snakeKey,
) {
  return json[camelKey]?.toString() ?? json[snakeKey]?.toString() ?? '';
}
