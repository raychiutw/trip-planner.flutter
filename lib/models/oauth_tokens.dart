/// OAuth token pair(/oauth/token 回應 + 本地持久化)。
library;

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.scope,
    required this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final String? scope;
  final DateTime expiresAt;

  /// 含 skew(預設 60s)提前視為過期,避免邊界用到剛好失效的 token。
  bool isExpired({Duration skew = const Duration(seconds: 60)}) =>
      DateTime.now().isAfter(expiresAt.subtract(skew));

  /// 由 /oauth/token 回應建構(expiresAt = now + expires_in)。
  factory OAuthTokens.fromTokenResponse(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final base = now ?? DateTime.now();
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return OAuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      scope: json['scope'] as String?,
      expiresAt: base.add(Duration(seconds: expiresIn)),
    );
  }

  /// 持久化用(expiresAt 以 ISO8601 存)。
  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': ?refreshToken,
        'token_type': tokenType,
        'scope': ?scope,
        'expires_at': expiresAt.toIso8601String(),
      };

  factory OAuthTokens.fromJson(Map<String, dynamic> json) => OAuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String?,
        tokenType: json['token_type'] as String? ?? 'Bearer',
        scope: json['scope'] as String?,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}
