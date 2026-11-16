/// OAuth PKCE 登入編排:開系統瀏覽器授權 → 以 https callback(Universal Link／
/// App Link)回到 App → 換 token → 交給憑證來源。
/// 瀏覽器那一段由 [AuthorizationLauncher] 負責(device 相依、測試以假的替換)。
library;

import '../../models/oauth_tokens.dart';
import '../dpop/proof_key_store.dart';
import 'oauth_config.dart';
import 'oauth_protocol.dart';
import 'oauth_repository.dart';
import 'pkce.dart';
import 'stored_bearer_token_source.dart';

class OAuthLoginException implements Exception {
  OAuthLoginException(
    this.message, {
    String? userMessage,
    this.cancelled = false,
  }) : userMessage = userMessage ?? 'Tripline 登入失敗，請稍後再試';

  /// 除錯用原文，可能含 client_id；**不可直接顯示給使用者**。
  final String message;

  /// 給使用者看的繁中訊息。
  final String userMessage;

  /// 使用者自己在瀏覽器關掉或取消，不算錯誤。
  final bool cancelled;

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

/// 登入結果：憑證，加上 callback 是否要求在手機上開啟生物辨識登入。
class OAuthLoginResult {
  const OAuthLoginResult(this.tokens, {this.enableBiometric = false});

  final OAuthTokens tokens;
  final bool enableBiometric;
}

class OAuthLoginService {
  OAuthLoginService({
    required OAuthRepository repository,
    required StoredBearerTokenSource source,
    required AuthorizationLauncher launcher,
    String clientId = OAuthConfig.clientId,
    ProofKeyStore? proofKeys,
    String Function()? webTheme,
  }) : _webTheme = webTheme,
       _repo = repository,
       _proofKeys = proofKeys,
       _source = source,
       _launcher = launcher,
       _clientId = clientId;

  final OAuthRepository _repo;
  final StoredBearerTokenSource _source;
  final AuthorizationLauncher _launcher;
  final String _clientId;
  final ProofKeyStore? _proofKeys;

  /// 每次開授權頁才取值：App 當下實際顯示的明暗（`light`／`dark`）。
  final String Function()? _webTheme;

  /// [biometricHint]：授權網址帶給 web 的按鈕名稱提示（[OAuthProtocol] 的 hint 值）。
  /// 結果的 [OAuthLoginResult.enableBiometric] 表示 callback 帶了開啟生物辨識登入的旗標。
  Future<OAuthLoginResult> login({String? biometricHint}) async {
    final verifier = generateCodeVerifier();
    final challenge = codeChallengeS256(verifier);
    final state = generateState();

    final authUrl = _repo.buildAuthorizeUrl(
      clientId: _clientId,
      redirectUri: OAuthConfig.redirectUri,
      codeChallenge: challenge,
      state: state,
      biometricHint: biometricHint,
      theme: _webTheme?.call(),
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
    // 旗標只是「請在手機上開啟」的請求，不含憑證；只認 enable。
    return OAuthLoginResult(
      tokens,
      enableBiometric:
          params[OAuthProtocol.biometricIntentParam] ==
          OAuthProtocol.intentEnable,
    );
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
    if (error != null) throw OAuthLoginException('授權失敗:$error');
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw OAuthLoginException('未取得授權碼');
    }
    return params;
  }
}
