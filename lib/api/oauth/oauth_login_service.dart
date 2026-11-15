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
    // 旗標只是「請在手機上開啟」的請求，不含憑證。一般登入只認 enable；disable 只會出現在
    // 設定頁的重新驗證（見 [reauthenticate]），登入收到時不處理。
    return OAuthLoginResult(
      tokens,
      enableBiometric:
          params[OAuthProtocol.biometricIntentParam] ==
          OAuthProtocol.intentEnable,
    );
  }

  /// 開系統瀏覽器等 callback；只認 state 相符的（防止別的網頁偽造回跳，CSRF），
  /// 授權端回 error 或沒有授權碼就丟 [OAuthLoginException]。
  ///
  /// [reauth]：是否為重新驗證。重新驗證才把 `access_denied` 當使用者取消（一般登入
  /// 維持原行為、顯示錯誤）；另外 api 判定帳號不符會回 `error=reauth_account_mismatch`
  /// （state 照常驗證、無授權碼），這裡轉成 `accountMismatch`；一般登入維持一般錯誤。
  Future<Map<String, String>> _authorize(
    Uri authUrl,
    String state, {
    bool reauth = false,
  }) async {
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
      if (reauth && error == OAuthProtocol.errorReauthAccountMismatch) {
        throw OAuthLoginException(
          '授權端判定重新驗證的帳號與目前帳號不同',
          userMessage: '登入的帳號與目前帳號不同',
          accountMismatch: true,
        );
      }
      throw OAuthLoginException(
        '授權失敗:$error',
        cancelled: reauth && error == OAuthProtocol.errorAccessDenied,
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
  /// 帳號比對由 api 在伺服器端完成（見 callback 旗標檢查），這裡不兌換授權碼：
  /// 沒有新憑證、不動 DPoP 金鑰、不會在「已登入裝置」多留一筆。
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
        theme: _webTheme?.call(),
        reauthIntent: intent,
        expectedAccount: expectedAccount,
      ),
      state,
      reauth: true,
    );
    // api 只在批准者就是 expected_account 時才加 biometric_intent 旗標（不符會導回
    // error=reauth_account_mismatch），所以旗標與發起時的意圖一致即證明帳號相同；缺漏或不一致一律拒絕。
    if (params[OAuthProtocol.biometricIntentParam] != intent) {
      throw OAuthLoginException('重新驗證的 callback 沒有帶預期的意圖');
    }
  }
}
