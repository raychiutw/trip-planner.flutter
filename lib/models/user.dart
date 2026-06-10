/// 使用者 models（`GET /oauth/userinfo`、`GET /account/stats`）。
library;

/// `GET /oauth/userinfo` 回應。
class UserInfo {
  const UserInfo({
    required this.id,
    required this.email,
    this.emailVerified = false,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
  });

  /// 32-char hex uuid。
  final String id;
  final String email;
  final bool emailVerified;
  final String? displayName;
  final String? avatarUrl;
  final String? createdAt;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified:
          json['emailVerified'] == 1 || json['emailVerified'] == true,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

/// `GET /account/stats` 回應（Account hub hero 3 stats）。
class AccountStats {
  const AccountStats({
    this.tripCount = 0,
    this.totalDays = 0,
    this.collaboratorCount = 0,
  });

  final int tripCount;
  final int totalDays;
  final int collaboratorCount;

  factory AccountStats.fromJson(Map<String, dynamic> json) {
    return AccountStats(
      tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
      collaboratorCount: (json['collaboratorCount'] as num?)?.toInt() ?? 0,
    );
  }
}
