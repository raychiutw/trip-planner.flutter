/// OAuth 2.1 PKCE 流程的 HTTP:authorize URL 組裝 + /oauth/token 交換/刷新。
/// 自帶 Dio(不經 ApiClient 的 cookie/Origin;/oauth/* 後端本就不需認證)。
library;

import 'package:dio/dio.dart';

import '../../models/oauth_tokens.dart';
import '../api_client.dart' show kTriplineOrigin;
import '../api_error.dart';

class OAuthRepository {
  OAuthRepository({Dio? dio, String origin = kTriplineOrigin})
    : _origin = origin,
      _dio = dio ?? Dio() {
    _dio.options.baseUrl = '$origin/api';
    _dio.options.validateStatus = (_) => true;
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
  }) => _token({
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': redirectUri,
    'client_id': clientId,
    'code_verifier': codeVerifier,
  });

  /// refresh_token 換新 token pair(public client 不帶 secret)。
  Future<OAuthTokens> refresh({
    required String refreshToken,
    required String clientId,
  }) => _token({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': clientId,
  });

  Future<OAuthTokens> _token(Map<String, dynamic> form) async {
    final res = await _dio.post<dynamic>(
      '/oauth/token',
      data: form,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final status = res.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiError.fromResponse(status, res.data);
    }
    return OAuthTokens.fromTokenResponse(res.data as Map<String, dynamic>);
  }
}
