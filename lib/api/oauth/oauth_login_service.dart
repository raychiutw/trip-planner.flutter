/// OAuth PKCE 登入編排:開系統瀏覽器授權 → 以 https callback(Universal Link／
/// App Link)回到 App → 換 token → 交給憑證來源。
/// 瀏覽器那一段由 [AuthorizationLauncher] 負責(device 相依、測試以假的替換)。
library;

import '../../models/oauth_tokens.dart';
import '../dpop/proof_key.dart';
import '../dpop/proof_key_store.dart';
import 'id_token.dart';
import 'oauth_config.dart';
import 'oauth_repository.dart';
import 'pkce.dart';
import 'stored_bearer_token_source.dart';

class OAuthLoginException implements Exception {
  OAuthLoginException(
    this.message, {
    String? userMessage,
    this.cancelled = false,
    this.accountMismatch = false,
  }) : userMessage = userMessage ?? 'Tripline 登入失敗，請稍後再試';

  /// 除錯用原文，可能含 client_id；**不可直接顯示給使用者**。
  final String message;

  /// 給使用者看的繁中訊息。
  final String userMessage;

  /// 使用者自己在瀏覽器關掉或取消，不算錯誤。
  final bool cancelled;

  /// 重新驗證回來的帳號與目前登入的帳號不同。
  final bool accountMismatch;
  @override
  String toString() => 'OAuthLoginException: $message';
}

/// 把授權網址交給系統瀏覽器，等 https callback 帶著結果回到 App。
abstract interface class AuthorizationLauncher {
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  });
}

/// 尚未組裝平台實作時的預設(測試或忘了 override):直接失敗。
/// App 於 main() override 成 `WebAuthLauncher`(lib/app/web_auth_launcher.dart)。
class UnavailableAuthorizationLauncher implements AuthorizationLauncher {
  const UnavailableAuthorizationLauncher();

  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async => throw OAuthLoginException('尚未設定授權啟動器');
}

class OAuthLoginService {
  OAuthLoginService({
    required OAuthRepository repository,
    required StoredBearerTokenSource source,
    required AuthorizationLauncher launcher,
    String clientId = OAuthConfig.clientId,
    ProofKeyStore? proofKeys,
  }) : _repo = repository,
       _proofKeys = proofKeys,
       _source = source,
       _launcher = launcher,
       _clientId = clientId;

  final OAuthRepository _repo;
  final StoredBearerTokenSource _source;
  final AuthorizationLauncher _launcher;
  final String _clientId;
  final ProofKeyStore? _proofKeys;

  /// [biometricHint]：授權網址帶給 web 的按鈕名稱提示（faceid／touchid／generic）。
  /// [onEnableIntent]：登入完成後、callback 帶 `biometric_intent=enable` 時呼叫。
  Future<OAuthTokens> login({
    String? biometricHint,
    void Function()? onEnableIntent,
  }) async {
    final verifier = generateCodeVerifier();
    final challenge = codeChallengeS256(verifier);
    final state = generateState();

    final authUrl = _repo.buildAuthorizeUrl(
      clientId: _clientId,
      redirectUri: OAuthConfig.redirectUri,
      codeChallenge: challenge,
      state: state,
      biometricHint: biometricHint,
    );

    final params = await _authorize(authUrl, state);
    final code = params['code']!;

    // 每次登入一把新金鑰（ADR-0015）；伺服器沒綁定就用不到，立刻刪掉。
    final keys = _proofKeys;
    final key = await keys?.create();
    final OAuthTokens tokens;
    try {
      tokens = await _repo.exchangeCode(
        code: code,
        codeVerifier: verifier,
        clientId: _clientId,
        redirectUri: OAuthConfig.redirectUri,
        proofKey: key,
      );
    } on Object {
      await keys?.delete();
      rethrow;
    }
    if (!tokens.isDpop) await keys?.delete();
    await _source.adopt(tokens);
    // 旗標只是「請在手機上開啟」的請求，不含憑證；disable 屬另一張票，這裡忽略。
    if (params['biometric_intent'] == 'enable') onEnableIntent?.call();
    return tokens;
  }

  /// 開系統瀏覽器等 callback；只認 state 相符的（防止別的網頁偽造回跳，CSRF），
  /// 授權端回 error 或沒有授權碼就丟 [OAuthLoginException]。
  Future<Map<String, String>> _authorize(Uri authUrl, String state) async {
    final callback = await _launcher.authorize(
      authUrl,
      callbackHost: OAuthConfig.callbackHost,
      callbackPath: OAuthConfig.callbackPath,
    );
    final params = callback.queryParameters;
    if (params['state'] != state) {
      throw OAuthLoginException('callback 的 state 不符');
    }
    final error = params['error'];
    if (error != null) {
      throw OAuthLoginException(
        '授權失敗:$error',
        cancelled: error == 'access_denied', // 使用者在授權頁按了拒絕
      );
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw OAuthLoginException('未取得授權碼');
    }
    return params;
  }

  /// 重新驗證（設定頁開啟／關閉生物辨識登入，ADR-0018）：只確認「現在操作的人仍知道
  /// 密碼、且是目前這個帳號」，**不改變目前的登入**。成功就正常返回；取消、帳號不同、
  /// 其他失敗都丟 [OAuthLoginException]（取消 `cancelled`、帳號不同 `accountMismatch`）。
  ///
  /// 為了拿到 id_token 比對帳號，必須兌換授權碼；但 DPoP 金鑰槽只有一把，用正式的
  /// [ProofKeyStore.create] 會先洗掉目前登入的金鑰（帳號不符時就把目前登入弄壞），
  /// 所以改用拋棄式的記憶體金鑰兌換，換回來的憑證**一律不採用**並撤銷。
  Future<void> reauthenticate({
    required String intent,
    required String expectedAccount,
    String? biometricHint,
  }) async {
    final verifier = generateCodeVerifier();
    final state = generateState();
    final params = await _authorize(
      _repo.buildAuthorizeUrl(
        clientId: _clientId,
        redirectUri: OAuthConfig.redirectUri,
        codeChallenge: codeChallengeS256(verifier),
        state: state,
        biometricHint: biometricHint,
        reauthIntent: intent,
        expectedAccount: expectedAccount,
      ),
      state,
    );
    // 旗標必須與發起時的意圖一致；不一致不兌換，免得多留一份授權。
    if (params['biometric_intent'] != intent) {
      throw OAuthLoginException('重新驗證的 callback 沒有帶預期的意圖');
    }
    final tokens = await _repo.exchangeCode(
      code: params['code']!,
      codeVerifier: verifier,
      clientId: _clientId,
      redirectUri: OAuthConfig.redirectUri,
      proofKey: SoftwareProofKey.generate(),
    );
    try {
      final idToken = tokens.idToken;
      final claims = idToken == null
          ? null
          : verifiedIdTokenClaims(idToken, clientId: _clientId);
      if (claims == null) throw OAuthLoginException('重新驗證沒有取得可驗證的 id_token');
      if (claims['sub'] != expectedAccount) {
        throw OAuthLoginException(
          '重新驗證的帳號與目前帳號不同',
          userMessage: '登入的帳號與目前帳號不同',
          accountMismatch: true,
        );
      }
    } finally {
      // 盡力撤銷；失敗不影響結果（沒人拿得到這份憑證）。
      final refresh = tokens.refreshToken;
      if (refresh != null) {
        await _repo
            .revokeToken(
              token: refresh,
              clientId: _clientId,
              tokenTypeHint: 'refresh_token',
            )
            .then<void>((_) {}, onError: (Object _) {});
      }
    }
  }
}
