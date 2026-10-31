/// OAuth PKCE 登入編排:開系統瀏覽器授權 → 以 https callback(Universal Link／
/// App Link)回到 App → 換 token → 交給憑證來源。
/// 瀏覽器那一段由 [AuthorizationLauncher] 負責(device 相依、測試以假的替換)。
library;

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../models/oauth_tokens.dart';
import 'oauth_config.dart';
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

/// 正式實作:iOS ASWebAuthenticationSession、Android Auth Tab。
class WebAuthLauncher implements AuthorizationLauncher {
  const WebAuthLauncher();

  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async {
    final result = await FlutterWebAuth2.authenticate(
      url: authorizeUrl.toString(),
      callbackUrlScheme: 'https',
      options: FlutterWebAuth2Options(
        httpsHost: callbackHost,
        httpsPath: callbackPath,
      ),
    );
    return Uri.parse(result);
  }
}

class OAuthLoginService {
  OAuthLoginService({
    required OAuthRepository repository,
    required StoredBearerTokenSource source,
    AuthorizationLauncher launcher = const WebAuthLauncher(),
    String clientId = OAuthConfig.clientId,
  }) : _repo = repository,
       _source = source,
       _launcher = launcher,
       _clientId = clientId;

  final OAuthRepository _repo;
  final StoredBearerTokenSource _source;
  final AuthorizationLauncher _launcher;
  final String _clientId;

  Future<OAuthTokens> login() async {
    final verifier = generateCodeVerifier();
    final challenge = codeChallengeS256(verifier);
    final state = generateState();

    final authUrl = _repo.buildAuthorizeUrl(
      clientId: _clientId,
      redirectUri: OAuthConfig.redirectUri,
      codeChallenge: challenge,
      state: state,
    );

    final Uri callback;
    try {
      callback = await _launcher.authorize(
        authUrl,
        callbackHost: OAuthConfig.callbackHost,
        callbackPath: OAuthConfig.callbackPath,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw OAuthLoginException(
          '使用者取消登入',
          userMessage: '已取消登入',
          cancelled: true,
        );
      }
      throw OAuthLoginException('無法開啟瀏覽器登入:${e.code}');
    }

    final params = callback.queryParameters;
    // 只認 state 相符的 callback,防止別的網頁偽造回跳(CSRF)。
    if (params['state'] != state) {
      throw OAuthLoginException('callback 的 state 不符');
    }
    final error = params['error'];
    if (error != null) throw OAuthLoginException('授權失敗:$error');
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw OAuthLoginException('未取得授權碼');
    }

    final tokens = await _repo.exchangeCode(
      code: code,
      codeVerifier: verifier,
      clientId: _clientId,
      redirectUri: OAuthConfig.redirectUri,
    );
    await _source.adopt(tokens);
    return tokens;
  }
}
