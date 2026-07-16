/// OIDC id_token(JWT)的 payload claims 解析與驗證(身分用;userinfo 不收 Bearer)。
library;

import 'dart:convert';

/// 純解碼 payload,不做任何驗證。身分用途請走 [verifiedIdTokenClaims]。
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

/// 解析並驗證 id_token,通過才回 claims;任何一項不合即回 null(呼叫端當作未登入)。
///
/// 驗證 [OIDC Core 3.1.3.7] 中此流程仍為必要的項目:`exp` 未過期、`aud` 是本
/// client、`sub` 存在。[leeway] 容忍裝置與 server 的時鐘偏移。
///
/// **不驗簽章**:token 是經 TLS 由 token 端點直接取得,OIDC Core 3.1.3.7 第 6 點
/// 明文允許此情況以 TLS server 驗證代替簽章驗證。
///
/// **刻意不驗 `iss`**(2026-07-16 查證):後端的 discovery 文件與實際簽發**不一致** ——
/// `openid-configuration.ts` 宣告 `issuer: '<origin>/api/oauth'`,但 `_id_token.ts`
/// 實際簽的是 `getPublicOrigin()`(= `<origin>`,無 `/api/oauth` 後綴)。兩個候選值
/// 都可能是「對的」,寫死任一個都會在另一邊被修正時讓登入全掛。
/// 待後端對齊後再補,屆時應以 discovery 的 `issuer` 為準而非寫死。
Map<String, dynamic>? verifiedIdTokenClaims(
  String idToken, {
  required String clientId,
  DateTime? now,
  Duration leeway = const Duration(minutes: 1),
}) {
  final claims = decodeIdTokenClaims(idToken);
  if (claims.isEmpty) return null;

  // sub:沒有主體就不成其為身分。
  final subject = claims['sub'];
  if (subject is! String || subject.isEmpty) return null;

  // aud:可能是字串或字串陣列(OIDC 允許兩者)。必須包含本 client ——
  // 否則就是別人的 token,不能拿來當自己的身分。
  if (!_audienceMatches(claims['aud'], clientId)) return null;

  // exp:缺漏視為不可信(沒有到期資訊的身分等於永不過期)。
  final exp = claims['exp'];
  if (exp is! num) return null;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(
    exp.toInt() * 1000,
    isUtc: true,
  );
  final at = (now ?? DateTime.now()).toUtc();
  if (!at.isBefore(expiresAt.add(leeway))) return null;

  return claims;
}

bool _audienceMatches(Object? audience, String clientId) {
  if (audience is String) return audience == clientId;
  if (audience is List) return audience.contains(clientId);
  return false;
}
