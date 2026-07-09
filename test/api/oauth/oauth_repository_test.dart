import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late OAuthRepository repo;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    repo = OAuthRepository(dio: dio, origin: 'https://x');
  });

  test('buildAuthorizeUrl：帶齊 query + S256', () {
    final u = repo.buildAuthorizeUrl(
      clientId: 'cid',
      redirectUri: 'http://127.0.0.1:8765',
      codeChallenge: 'chal',
      state: 'st',
    );
    expect(u.path, '/api/oauth/authorize');
    expect(u.queryParameters['response_type'], 'code');
    expect(u.queryParameters['client_id'], 'cid');
    expect(u.queryParameters['redirect_uri'], 'http://127.0.0.1:8765');
    expect(u.queryParameters['code_challenge'], 'chal');
    expect(u.queryParameters['code_challenge_method'], 'S256');
    expect(u.queryParameters['state'], 'st');
  });

  test('exchangeCode：POST /oauth/token form → token', () async {
    adapter.onPost(
      '/oauth/token',
      (server) => server.reply(200, {
        'access_token': 'AT',
        'refresh_token': 'RT',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'scope': 'openid',
      }),
      data: {
        'grant_type': 'authorization_code',
        'code': 'c',
        'redirect_uri': 'http://127.0.0.1:8765',
        'client_id': 'cid',
        'code_verifier': 'ver',
      },
    );

    final t = await repo.exchangeCode(
      code: 'c',
      codeVerifier: 'ver',
      clientId: 'cid',
      redirectUri: 'http://127.0.0.1:8765',
    );
    expect(t.accessToken, 'AT');
    expect(t.refreshToken, 'RT');
  });

  test('refresh：POST /oauth/token grant_type=refresh_token', () async {
    adapter.onPost(
      '/oauth/token',
      (server) => server.reply(200, {
        'access_token': 'AT2',
        'refresh_token': 'RT2',
        'expires_in': 3600,
      }),
      data: {
        'grant_type': 'refresh_token',
        'refresh_token': 'RT',
        'client_id': 'cid',
      },
    );

    final t = await repo.refresh(refreshToken: 'RT', clientId: 'cid');
    expect(t.accessToken, 'AT2');
    expect(t.refreshToken, 'RT2');
  });

  test('revokeToken：POST /oauth/revoke form', () async {
    adapter.onPost(
      '/oauth/revoke',
      (server) => server.reply(200, ''),
      data: {
        'token': 'RT',
        'client_id': 'cid',
        'token_type_hint': 'refresh_token',
      },
    );

    await repo.revokeToken(
      token: 'RT',
      clientId: 'cid',
      tokenTypeHint: 'refresh_token',
    );
  });

  test('token 端點 400 → ApiError', () async {
    adapter.onPost(
      '/oauth/token',
      (server) => server.reply(400, {
        'error': 'invalid_grant',
        'error_description': 'bad code',
      }),
      data: {
        'grant_type': 'authorization_code',
        'code': 'bad',
        'redirect_uri': 'http://127.0.0.1:8765',
        'client_id': 'cid',
        'code_verifier': 'ver',
      },
    );

    await expectLater(
      repo.exchangeCode(
        code: 'bad',
        codeVerifier: 'ver',
        clientId: 'cid',
        redirectUri: 'http://127.0.0.1:8765',
      ),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 400)),
    );
  });

  test('revokeToken 401 → ApiError', () async {
    adapter.onPost(
      '/oauth/revoke',
      (server) => server.reply(401, {
        'error': 'invalid_client',
        'error_description': 'Missing client_id',
      }),
      data: {'token': 'RT', 'client_id': 'cid'},
    );

    await expectLater(
      repo.revokeToken(token: 'RT', clientId: 'cid'),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
  });
}
