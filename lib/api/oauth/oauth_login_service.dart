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
    final state = generateState();

    final HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        OAuthConfig.redirectPort,
      );
    } on Object catch (e) {
      throw OAuthLoginException(
        '無法在 127.0.0.1:${OAuthConfig.redirectPort} 啟動本地接收器(埠可能被占用):$e',
      );
    }
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

      // 只認 state 相符的 callback;忽略 favicon/prefetch/外來雜訊(防 first-request 搶占)。
      final params = await _awaitCallback(server, state).timeout(
        _timeout,
        onTimeout: () {
          unawaited(server.close(force: true));
          throw OAuthLoginException('登入逾時');
        },
      );

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
      await _store.write(tokens);
      return tokens;
    } finally {
      await server.close(force: true);
    }
  }

  /// 等到 state 相符的 callback(含 error redirect,後端 error 也會帶 state);
  /// 其他請求回 404 並忽略,避免第一個雜訊請求被當成 callback。
  Future<Map<String, String>> _awaitCallback(
    HttpServer server,
    String state,
  ) async {
    await for (final request in server) {
      final params = request.uri.queryParameters;
      if (params['state'] != state) {
        request.response
          ..statusCode = 404
          ..close();
        continue;
      }
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<html><body style="font-family:sans-serif;text-align:center;'
          'padding-top:3rem">登入完成,可關閉此頁回到 App。</body></html>',
        );
      await request.response.close();
      return params;
    }
    throw OAuthLoginException('接收器已關閉');
  }
}
