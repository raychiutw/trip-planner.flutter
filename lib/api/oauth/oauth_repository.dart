/// OAuth 2.1 PKCE 流程的 HTTP:authorize URL 組裝 + /oauth/token 交換/刷新。
/// 自帶 Dio(不經 ApiClient 的 Bearer 與 refresh 重送;/oauth/* 本就不需認證)。
library;

import 'package:dio/dio.dart';

import '../../models/oauth_tokens.dart';
import '../api_client.dart' show kTriplineOrigin;
import '../api_error.dart';
import '../dpop/dpop_clock.dart';
import '../dpop/dpop_proof.dart';
import '../dpop/proof_key.dart';

/// 瀏覽器登入與 passkey 登入共用的 scope（兩條路徑簽出的 token 要等價）。
const kOAuthLoginScope =
    'openid profile email offline_access trips:read trips:write';

class OAuthRepository {
  OAuthRepository({Dio? dio, String origin = kTriplineOrigin, DpopClock? clock})
    : _origin = origin,
      _clock = clock ?? DpopClock(),
      _dio = dio ?? Dio() {
    _dio.options.baseUrl = '$origin/api';
    _dio.options.validateStatus = (_) => true;
    // 避免 token 交換/刷新無限期 hang(連帶卡住所有等 refresh 的 request)。
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  final String _origin;
  final Dio _dio;
  final DpopClock _clock;

  /// 在系統瀏覽器開啟的授權 URL(absolute)。
  Uri buildAuthorizeUrl({
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    String scope = kOAuthLoginScope,
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

  /// POST /oauth/passkey/options（未登入）：取得一次性登入挑戰，原樣交給平台層。
  Future<Map<String, dynamic>> passkeyOptions() async =>
      await _postJson('/oauth/passkey/options', <String, dynamic>{})
          as Map<String, dynamic>;

  /// POST /oauth/passkey/login（未登入）：assertion 驗證通過回 authorization code，
  /// 之後以 [exchangeCode]（不帶 redirect_uri）兌換。
  Future<String> passkeyLogin({
    required String clientId,
    required Map<String, dynamic> credential,
    required String codeChallenge,
    String? dpopJkt,
    String scope = kOAuthLoginScope,
  }) async {
    final body = await _postJson('/oauth/passkey/login', {
      'client_id': clientId,
      'credential': credential,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'scope': scope,
      'dpop_jkt': ?dpopJkt,
    });
    return (body as Map<String, dynamic>)['code'] as String;
  }

  Future<dynamic> _postJson(String path, Map<String, dynamic> data) async {
    final res = await _dio.post<dynamic>(path, data: data);
    final status = res.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiError.fromResponse(status, res.data);
    }
    return res.data;
  }

  /// authorization_code + PKCE code_verifier 換 token。
  Future<OAuthTokens> exchangeCode({
    required String code,
    required String codeVerifier,
    required String clientId,
    String? redirectUri,
    ProofKey? proofKey,
  }) => _token({
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': ?redirectUri,
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
  /// 回 400 `invalid_dpop_proof` 且有 `Date` 標頭時，校正時差後重簽重送一次。
  Future<OAuthTokens> _token(
    Map<String, dynamic> form,
    ProofKey? proofKey,
  ) async {
    for (var attempt = 0; ; attempt++) {
      final proof = proofKey == null
          ? null
          : await buildDpopProof(
              key: proofKey,
              method: 'POST',
              url: Uri.parse('$_origin/api/oauth/token'),
              now: _clock.now(),
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
      if (status >= 200 && status < 300) {
        return OAuthTokens.fromTokenResponse(res.data as Map<String, dynamic>);
      }
      final error = ApiError.fromResponse(status, res.data);
      if (attempt == 0 &&
          proofKey != null &&
          status == 400 &&
          error.code == 'invalid_dpop_proof' &&
          _clock.adoptServerDate(res.headers.value('date'))) {
        continue;
      }
      throw error;
    }
  }
}
