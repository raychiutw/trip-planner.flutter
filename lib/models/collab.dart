/// 共編權限與邀請 models（wire format 為 camelCase）。
library;

class TripPermission {
  const TripPermission({
    required this.id,
    required this.email,
    required this.tripId,
    required this.role,
    this.displayName,
    this.userId,
  });

  final int id;
  final String email;
  final String tripId;
  final String role;
  final String? displayName;
  final String? userId;

  bool get isOwner => role == 'owner';
  bool get isViewer => role == 'viewer';

  String get roleLabel {
    return switch (role) {
      'owner' => '擁有者',
      'member' => '共編成員',
      'viewer' => '檢視者',
      _ => role,
    };
  }

  String get displayLabel {
    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    return email;
  }

  factory TripPermission.fromJson(Map<String, dynamic> json) {
    return TripPermission(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      tripId: json['tripId'] as String? ?? '',
      role: json['role'] as String? ?? 'viewer',
      userId: json['userId'] as String?,
    );
  }
}

class PermissionInviteResult {
  const PermissionInviteResult({
    required this.ok,
    required this.status,
    required this.email,
    this.id,
    this.expiresAt,
  });

  final bool ok;
  final String status;
  final String email;
  final int? id;
  final String? expiresAt;

  factory PermissionInviteResult.fromJson(Map<String, dynamic> json) {
    return PermissionInviteResult(
      ok: json['ok'] == true,
      status: json['status'] as String? ?? '',
      email: json['email'] as String? ?? '',
      id: (json['id'] as num?)?.toInt(),
      expiresAt: json['expiresAt'] as String?,
    );
  }
}

class PermissionRoleUpdateResult {
  const PermissionRoleUpdateResult({
    required this.ok,
    this.role,
    this.unchanged = false,
  });

  final bool ok;
  final String? role;
  final bool unchanged;

  factory PermissionRoleUpdateResult.fromJson(Map<String, dynamic> json) {
    return PermissionRoleUpdateResult(
      ok: json['ok'] == true,
      role: json['role'] as String?,
      unchanged: json['unchanged'] == true,
    );
  }
}

class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.invitedEmail,
    this.createdAt,
    this.expiresAt,
    this.daysRemaining,
    this.isExpired = false,
  });

  final String id;
  final String invitedEmail;
  final String? createdAt;
  final String? expiresAt;
  final int? daysRemaining;
  final bool isExpired;

  String get statusLabel {
    if (isExpired) return '已過期';
    final days = daysRemaining;
    if (days == null) return '待接受';
    return '剩 $days 天';
  }

  factory PendingInvitation.fromJson(Map<String, dynamic> json) {
    return PendingInvitation(
      id: json['id'] as String? ?? '',
      invitedEmail: json['invitedEmail'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
      isExpired: json['isExpired'] == true,
    );
  }
}

class PendingInvitationPage {
  const PendingInvitationPage({required this.items});

  final List<PendingInvitation> items;

  factory PendingInvitationPage.fromJson(Map<String, dynamic> json) {
    return PendingInvitationPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (itemJson) =>
                PendingInvitation.fromJson(itemJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class InvitationPreview {
  const InvitationPreview({
    required this.tripId,
    required this.tripTitle,
    required this.invitedEmail,
    required this.inviterEmail,
    required this.expiresAt,
    this.inviterDisplayName,
  });

  final String tripId;
  final String tripTitle;
  final String invitedEmail;
  final String? inviterDisplayName;
  final String inviterEmail;
  final String expiresAt;

  String get inviterLabel {
    final trimmedName = inviterDisplayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    return inviterEmail;
  }

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    return InvitationPreview(
      tripId: json['tripId'] as String? ?? '',
      tripTitle: json['tripTitle'] as String? ?? '',
      invitedEmail: json['invitedEmail'] as String? ?? '',
      inviterDisplayName: json['inviterDisplayName'] as String?,
      inviterEmail: json['inviterEmail'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
    );
  }
}

class InvitationAcceptResult {
  const InvitationAcceptResult({
    required this.ok,
    required this.tripId,
    required this.tripTitle,
  });

  final bool ok;
  final String tripId;
  final String tripTitle;

  factory InvitationAcceptResult.fromJson(Map<String, dynamic> json) {
    return InvitationAcceptResult(
      ok: json['ok'] == true,
      tripId: json['tripId'] as String? ?? '',
      tripTitle: json['tripTitle'] as String? ?? '',
    );
  }
}
