/// 以 authorization code 換 token 的共用收尾（瀏覽器登入與 passkey 登入共用，ADR-0016）。
///
/// DPoP 金鑰的生命週期在這裡一次處理：換票失敗、或伺服器沒綁定就刪掉金鑰；
/// 成功才把憑證交給 [StoredBearerTokenSource]。
library;

import '../../models/oauth_tokens.dart';
import '../dpop/proof_key.dart';
import '../dpop/proof_key_store.dart';
import 'oauth_repository.dart';
import 'stored_bearer_token_source.dart';

/// [redirectUri] 為 null 時不送（passkey 登入簽出的 code 沒有 redirect_uri）。
Future<OAuthTokens> redeemAuthorizationCode({
  required OAuthRepository repository,
  required StoredBearerTokenSource source,
  required String clientId,
  required String code,
  required String codeVerifier,
  String? redirectUri,
  ProofKey? key,
  ProofKeyStore? proofKeys,
}) async {
  final OAuthTokens tokens;
  try {
    tokens = await repository.exchangeCode(
      code: code,
      codeVerifier: codeVerifier,
      clientId: clientId,
      redirectUri: redirectUri,
      proofKey: key,
    );
  } on Object {
    await proofKeys?.delete();
    rethrow;
  }
  if (!tokens.isDpop) await proofKeys?.delete();
  await source.adopt(tokens);
  return tokens;
}
