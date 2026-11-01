/// OAuth 2.1 PKCE 流程的 HTTP:authorize URL 組裝 + /oauth/token 交換/刷新。
/// 自帶 Dio(不經 ApiClient 的 Bearer 與 refresh 重送;/oauth/* 本就不需認證)。
library;

import 'package:dio/dio.dart';

import '../../models/oauth_tokens.dart';
import '../api_client.dart' show kTriplineOrigin;
import '../api_error.dart';
import '../dpop/dpop_proof.dart';
import '../dpop/proof_key.dart';

class OAuthRepository {
  OAuthRepository({Dio? dio, String origin = kTriplineOrigin})
    : _origin = origin,
      _dio = dio ?? Dio() {
    _dio.options.baseUrl = '$origin/api';
    _dio.options.validateStatus = (_) => true;
    // 避免 token 交換/刷新無限期 hang(連帶卡住所有等 refresh 的 request)。
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  final String _origin;
  final Dio _dio;

  /// 在系統瀏覽器開啟的授權 URL(absolute)。
  Uri buildAuthorizeUrl({
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    String scope = 'openid profile email offline_access',
  }) {
    return Uri.parse('$_origin/api/oauth/authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': scope,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );
  }

  /// authorization_code + PKCE code_verifier 換 token。
  Future<OAuthTokens> exchangeCode({
    required String code,
    required String codeVerifier,
    required String clientId,
    required String redirectUri,
    ProofKey? proofKey,
  }) => _token({
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': redirectUri,
    'client_id': clientId,
    'code_verifier': codeVerifier,
  }, proofKey);

  /// refresh_token 換新 token pair(public client 不帶 secret)。
  Future<OAuthTokens> refresh({
    required String refreshToken,
    required String clientId,
    ProofKey? proofKey,
  }) => _token({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': clientId,
  }, proofKey);

  /// RFC 7009 token revocation. Unknown/already revoked tokens still return 200.
  Future<void> revokeToken({
    required String token,
    required String clientId,
    String? tokenTypeHint,
    String? clientSecret,
  }) async {
    final res = await _dio.post<dynamic>(
      '/oauth/revoke',
      data: {
        'token': token,
        'client_id': clientId,
        'token_type_hint': ?tokenTypeHint,
        'client_secret': ?clientSecret,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final status = res.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiError.fromResponse(status, res.data);
    }
  }

  /// 有 [proofKey] 就附 DPoP proof（ADR-0015）；伺服器依此決定 token 是否綁定金鑰。
  Future<OAuthTokens> _token(
    Map<String, dynamic> form,
    ProofKey? proofKey,
  ) async {
    final proof = proofKey == null
        ? null
        : await buildDpopProof(
            key: proofKey,
            method: 'POST',
            url: Uri.parse('$_origin/api/oauth/token'),
          );
    final res = await _dio.post<dynamic>(
      '/oauth/token',
      data: form,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'DPoP': ?proof},
      ),
    );
    final status = res.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiError.fromResponse(status, res.data);
    }
    return OAuthTokens.fromTokenResponse(res.data as Map<String, dynamic>);
  }
}
