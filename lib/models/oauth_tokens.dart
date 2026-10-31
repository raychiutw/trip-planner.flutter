/// OAuth token pair(/oauth/token 回應 + 本地持久化)。
library;

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.tokenType = 'Bearer',
    this.scope,
    required this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;

  /// OIDC id_token(JWT);scope 含 openid 時才有。身分來源(userinfo 不收 Bearer)。
  final String? idToken;
  final String tokenType;
  final String? scope;
  final DateTime expiresAt;

  /// 含 skew(預設 60s)提前視為過期,避免邊界用到剛好失效的 token。
  bool isExpired({Duration skew = const Duration(seconds: 60)}) =>
      DateTime.now().isAfter(expiresAt.subtract(skew));

  OAuthTokens copyWith({String? idToken}) => OAuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    idToken: idToken ?? this.idToken,
    tokenType: tokenType,
    scope: scope,
    expiresAt: expiresAt,
  );

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
      idToken: json['id_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      scope: json['scope'] as String?,
      expiresAt: base.add(Duration(seconds: expiresIn)),
    );
  }

  /// 落地用的版本:**不含 access token**(只放記憶體,見 ADR-0014)。
  /// 讀回來的 access token 是空字串且視為已過期,第一次使用前會先 refresh。
  OAuthTokens withoutAccessToken() => OAuthTokens(
    accessToken: '',
    refreshToken: refreshToken,
    idToken: idToken,
    tokenType: tokenType,
    scope: scope,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  /// 持久化用:只存 refresh token 與身分資訊,絕不存 access token。
  Map<String, dynamic> toJson() => {
    'refresh_token': ?refreshToken,
    'id_token': ?idToken,
    'token_type': tokenType,
    'scope': ?scope,
  };

  /// 讀回落地內容。舊版曾存過 access_token / expires_at,一律忽略。
  factory OAuthTokens.fromJson(Map<String, dynamic> json) => OAuthTokens(
    accessToken: '',
    refreshToken: json['refresh_token'] as String?,
    idToken: json['id_token'] as String?,
    tokenType: json['token_type'] as String? ?? 'Bearer',
    scope: json['scope'] as String?,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}
