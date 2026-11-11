import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';

void main() {
  late DioAdapter adapter;
  late OAuthRepository repo;

  setUp(() {
    final dio = Dio();
    adapter = DioAdapter(dio: dio);
    repo = OAuthRepository(dio: dio, origin: 'https://x');
  });

  const credential = <String, dynamic>{
    'id': 'cred-1',
    'response': {'clientDataJSON': 'cd', 'authenticatorData': 'ad'},
  };

  test('passkeyOptions：POST /oauth/passkey/options 回挑戰原樣', () async {
    adapter.onPost(
      '/oauth/passkey/options',
      (server) => server.reply(200, {
        'challenge': 'ch',
        'rpId': 'trip-planner-dby.pages.dev',
        'allowCredentials': [],
      }),
      data: <String, dynamic>{},
    );

    final options = await repo.passkeyOptions();

    expect(options['challenge'], 'ch');
    expect(options['rpId'], 'trip-planner-dby.pages.dev');
  });

  test(
    'passkeyLogin：帶 client_id、credential、PKCE S256、scope、dpop_jkt，回 code',
    () async {
      adapter.onPost(
        '/oauth/passkey/login',
        (server) => server.reply(200, {'code': 'CODE', 'expires_in': 60}),
        data: {
          'client_id': 'cid',
          'credential': credential,
          'code_challenge': 'chal',
          'code_challenge_method': 'S256',
          'scope': 'openid profile email offline_access trips:read trips:write',
          'dpop_jkt': 'jkt',
        },
      );

      final code = await repo.passkeyLogin(
        clientId: 'cid',
        credential: credential,
        codeChallenge: 'chal',
        dpopJkt: 'jkt',
      );

      expect(code, 'CODE');
    },
  );

  test('passkeyLogin：沒有 DPoP 金鑰就不送 dpop_jkt', () async {
    adapter.onPost(
      '/oauth/passkey/login',
      (server) => server.reply(200, {'code': 'CODE', 'expires_in': 60}),
      data: {
        'client_id': 'cid',
        'credential': credential,
        'code_challenge': 'chal',
        'code_challenge_method': 'S256',
        'scope': 'openid profile email offline_access trips:read trips:write',
      },
    );

    expect(
      await repo.passkeyLogin(
        clientId: 'cid',
        credential: credential,
        codeChallenge: 'chal',
      ),
      'CODE',
    );
  });

  test('passkeyLogin：401 PASSKEY_LOGIN_INVALID 轉成 ApiError', () async {
    adapter.onPost(
      '/oauth/passkey/login',
      (server) => server.reply(401, {
        'error': {'code': 'PASSKEY_LOGIN_INVALID', 'message': 'x'},
      }),
      data: Matchers.any,
    );

    await expectLater(
      repo.passkeyLogin(
        clientId: 'cid',
        credential: credential,
        codeChallenge: 'chal',
      ),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.code, 'code', 'PASSKEY_LOGIN_INVALID'),
      ),
    );
  });

  test(
    'exchangeCode：沒給 redirectUri 就不送 redirect_uri（passkey 簽的 code 沒有）',
    () async {
      adapter.onPost(
        '/oauth/token',
        (server) => server.reply(200, {
          'access_token': 'AT',
          'refresh_token': 'RT',
          'expires_in': 3600,
        }),
        data: {
          'grant_type': 'authorization_code',
          'code': 'c',
          'client_id': 'cid',
          'code_verifier': 'ver',
        },
      );

      final t = await repo.exchangeCode(
        code: 'c',
        codeVerifier: 'ver',
        clientId: 'cid',
      );

      expect(t.accessToken, 'AT');
    },
  );
}
