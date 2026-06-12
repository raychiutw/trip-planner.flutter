/// 解析 OIDC id_token(JWT)的 payload claims(身分用;userinfo 不收 Bearer)。
/// 注意:只解碼 payload、不驗簽 — token 由 token 端點經 TLS 直接取得。完整 OIDC
/// 應另以 JWKS 驗 id_token 簽章,列為後續強化。
library;

import 'dart:convert';

Map<String, dynamic> decodeIdTokenClaims(String idToken) {
  final parts = idToken.split('.');
  if (parts.length < 2) return const {};
  try {
    final decoded = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(decoded);
    return json is Map<String, dynamic> ? json : const {};
  } on Exception {
    return const {};
  }
}
