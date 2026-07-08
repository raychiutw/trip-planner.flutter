/// 使用者 models（`GET /oauth/userinfo`、`GET /account/stats`、sessions）。
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

/// `GET /account/sessions` 回應 wrapper。
class AccountSessionsPage {
  const AccountSessionsPage({required this.currentSid, required this.sessions});

  /// 後端標示的目前 session id，未登入或 cookie 無 sid 時可能為 null。
  final String? currentSid;

  /// 目前帳號可見的登入裝置清單。
  final List<AccountSession> sessions;

  factory AccountSessionsPage.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'];
    return AccountSessionsPage(
      currentSid: _stringFromAnyKey(json, 'current_sid', 'currentSid'),
      sessions: rawSessions is List<dynamic>
          ? rawSessions
                .whereType<Map>()
                .map(
                  (sessionJson) => AccountSession.fromJson(
                    Map<String, dynamic>.from(sessionJson),
                  ),
                )
                .toList()
          : const <AccountSession>[],
    );
  }
}

/// 登入中的單一裝置/session row。
class AccountSession {
  const AccountSession({
    required this.sid,
    this.uaSummary,
    this.ipHashPrefix,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isCurrent,
  });

  /// Opaque session id。
  final String sid;

  /// 後端整理過的 User-Agent 摘要。
  final String? uaSummary;

  /// IP hash prefix，只用於辨識，不顯示完整 IP。
  final String? ipHashPrefix;

  final String createdAt;
  final String lastSeenAt;
  final bool isCurrent;

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    return AccountSession(
      sid: json['sid'] as String,
      uaSummary: _stringFromAnyKey(json, 'ua_summary', 'uaSummary'),
      ipHashPrefix: _stringFromAnyKey(json, 'ip_hash_prefix', 'ipHashPrefix'),
      createdAt: _stringFromAnyKey(json, 'created_at', 'createdAt') ?? '',
      lastSeenAt: _stringFromAnyKey(json, 'last_seen_at', 'lastSeenAt') ?? '',
      isCurrent:
          json['is_current'] == true ||
          json['is_current'] == 1 ||
          json['isCurrent'] == true ||
          json['isCurrent'] == 1,
    );
  }
}

String? _stringFromAnyKey(
  Map<String, dynamic> json,
  String key,
  String fallbackKey,
) {
  final value = json[key] ?? json[fallbackKey];
  return value is String && value.trim().isNotEmpty ? value : null;
}
