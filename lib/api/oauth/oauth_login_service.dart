/// OAuth PKCE 登入編排(RFC 8252 loopback):起本地 server → 開系統瀏覽器授權 →
/// 收 redirect 的 code → 換 token → 存。**device 相依、未單測**;核心(pkce/exchange)
/// 已於各自單元測試覆蓋。e2e 待 backend owner provision public client。
library;

import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../models/oauth_tokens.dart';
import 'oauth_config.dart';
import 'oauth_repository.dart';
import 'oauth_token_store.dart';
import 'pkce.dart';

class OAuthLoginException implements Exception {
  OAuthLoginException(this.message);
  final String message;
  @override
  String toString() => 'OAuthLoginException: $message';
}

class OAuthLoginService {
  OAuthLoginService({
    required OAuthRepository repository,
    required OAuthTokenStore store,
    String clientId = OAuthConfig.clientId,
    Duration timeout = const Duration(minutes: 5),
  }) : _repo = repository,
       _store = store,
       _clientId = clientId,
       _timeout = timeout;

  final OAuthRepository _repo;
  final OAuthTokenStore _store;
  final String _clientId;
  final Duration _timeout;

  Future<OAuthTokens> login() async {
    if (_clientId.isEmpty) {
      throw OAuthLoginException('未設定 OAuth client_id(--dart-define)');
    }
    final verifier = generateCodeVerifier();
    final challenge = codeChallengeS256(verifier);
    final state = generateCodeVerifier(); // 隨機 state(防竄改)

    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      OAuthConfig.redirectPort,
    );
    try {
      final authUrl = _repo.buildAuthorizeUrl(
        clientId: _clientId,
        redirectUri: OAuthConfig.redirectUri,
        codeChallenge: challenge,
        state: state,
      );
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw OAuthLoginException('無法開啟瀏覽器');
      }

      final request = await server.first.timeout(
        _timeout,
        onTimeout: () => throw OAuthLoginException('登入逾時'),
      );
      final params = request.uri.queryParameters;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<html><body style="font-family:sans-serif;text-align:center;'
          'padding-top:3rem">登入完成,可關閉此頁回到 App。</body></html>',
        );
      await request.response.close();

      final error = params['error'];
      if (error != null) throw OAuthLoginException('授權失敗:$error');
      if (params['state'] != state) {
        throw OAuthLoginException('state 不符(可能遭竄改)');
      }
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
      await _store.write(tokens);
      return tokens;
    } finally {
      await server.close(force: true);
    }
  }
}
