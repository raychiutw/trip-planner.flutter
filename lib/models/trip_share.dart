/// 行程公開分享連結(trip_shares)。
library;

/// 一筆分享連結(list 回應;不含 token/hash)。
class TripShare {
  const TripShare({
    required this.id,
    this.label = '',
    this.visibleSections = const [],
    this.expiresAt,
    this.viewCount = 0,
    this.anonymous = false,
    this.createdAt,
    this.revokedAt,
  });

  final int id;
  final String label;
  final List<String> visibleSections;

  /// epoch ms;null = 永久。
  final int? expiresAt;
  final int viewCount;
  final bool anonymous;
  final String? createdAt;
  final String? revokedAt;

  bool get isRevoked => revokedAt != null;
  bool get isExpired =>
      expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt!;
  bool get isActive => !isRevoked && !isExpired;

  factory TripShare.fromJson(Map<String, dynamic> json) => TripShare(
        id: (json['id'] as num).toInt(),
        label: json['label'] as String? ?? '',
        visibleSections:
            (json['visibleSections'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(),
        expiresAt: (json['expiresAt'] as num?)?.toInt(),
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        anonymous: json['anonymous'] == 1 || json['anonymous'] == true,
        createdAt: json['createdAt'] as String?,
        revokedAt: json['revokedAt'] as String?,
      );
}

/// 建立分享連結的回應(raw token 只回一次)。
class ShareLink {
  const ShareLink({
    required this.id,
    required this.token,
    required this.url,
    this.label = '',
  });

  final int id;
  final String token;

  /// 相對路徑,如 `/s/<token>`。
  final String url;
  final String label;

  /// 完整可分享 URL = origin + url。
  String fullUrl(String origin) => '$origin$url';

  factory ShareLink.fromJson(Map<String, dynamic> json) => ShareLink(
        id: (json['id'] as num).toInt(),
        token: json['token'] as String? ?? '',
        url: json['url'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}
