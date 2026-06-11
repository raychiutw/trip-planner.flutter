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
