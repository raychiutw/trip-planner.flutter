import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/models/oauth.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late InMemorySessionStore sessionStore;
  late AuthRepository authRepository;

  const userInfoJson = {
    'id': 'u1hex',
    'email': 'ray@example.com',
    'emailVerified': 1,
    'displayName': 'Ray',
    'avatarUrl': null,
    'createdAt': '2026-01-01T00:00:00Z',
  };

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    sessionStore = InMemorySessionStore();
    final apiClient = ApiClient(sessionStore: sessionStore, dio: dio);
    authRepository = AuthRepository(
      client: apiClient,
      sessionStore: sessionStore,
    );
  });

  group('login', () {
    test('解析 set-cookie 的 tripline_session 寫入 store 並回 UserInfo', () async {
      dioAdapter.onPost(
        '/oauth/login',
        (server) => server.reply(
          200,
          {'ok': true, 'userId': 'u1hex', 'email': 'ray@example.com'},
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': [
              'other_cookie=zzz; Path=/',
              'tripline_session=abc.def; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=2592000',
            ],
          },
        ),
        data: {'email': 'ray@example.com', 'password': 'secret'},
      );
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(200, userInfoJson),
      );

      final loggedInUser = await authRepository.login(
        email: 'ray@example.com',
        password: 'secret',
      );

      expect(await sessionStore.read(), 'abc.def');
      expect(loggedInUser.id, 'u1hex');
      expect(loggedInUser.email, 'ray@example.com');
      expect(loggedInUser.emailVerified, isTrue);
      expect(loggedInUser.displayName, 'Ray');
    });

    test('401 LOGIN_INVALID → 丟 ApiError、store 不寫入', () async {
      dioAdapter.onPost(
        '/oauth/login',
        (server) => server.reply(401, {
          'error': {'code': 'LOGIN_INVALID', 'message': '帳號或密碼錯誤'},
        }),
        data: {'email': 'ray@example.com', 'password': 'wrong'},
      );

      await expectLater(
        authRepository.login(email: 'ray@example.com', password: 'wrong'),
        throwsA(
          isA<ApiError>()
              .having((error) => error.status, 'status', 401)
              .having((error) => error.code, 'code', 'LOGIN_INVALID'),
        ),
      );
      expect(await sessionStore.read(), isNull);
    });

    test('200 但無 tripline_session cookie → 丟 ApiError', () async {
      dioAdapter.onPost(
        '/oauth/login',
        (server) => server.reply(200, {
          'ok': true,
          'userId': 'u1hex',
          'email': 'ray@example.com',
        }),
        data: {'email': 'ray@example.com', 'password': 'secret'},
      );

      await expectLater(
        authRepository.login(email: 'ray@example.com', password: 'secret'),
        throwsA(isA<ApiError>()),
      );
      expect(await sessionStore.read(), isNull);
    });
  });

  group('signup', () {
    test('201 解析 set-cookie 寫入 store 並回 signup 結果', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(
          201,
          {
            'ok': true,
            'userId': 'u2hex',
            'email': 'traveler@example.com',
            'requiresVerification': true,
            'joinedTrip': {'id': 'trip-1', 'title': '沖繩家庭旅行'},
            'invitationError': null,
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': [
              'tripline_session=signup.session; Path=/; HttpOnly; Secure',
            ],
          },
        ),
        data: {
          'email': 'traveler@example.com',
          'password': 'secret123',
          'displayName': 'Ray',
          'invitationToken': 'invite-token',
        },
      );

      final result = await authRepository.signup(
        email: ' traveler@example.com ',
        password: 'secret123',
        displayName: ' Ray ',
        invitationToken: ' invite-token ',
      );

      expect(await sessionStore.read(), 'signup.session');
      expect(result.userId, 'u2hex');
      expect(result.email, 'traveler@example.com');
      expect(result.requiresVerification, isTrue);
      expect(result.joinedTrip?.id, 'trip-1');
      expect(result.joinedTrip?.title, '沖繩家庭旅行');
      expect(result.invitationError, isNull);
    });

    test('SIGNUP_EMAIL_TAKEN → 丟 ApiError、store 不寫入', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(409, {
          'error': {'code': 'SIGNUP_EMAIL_TAKEN', 'message': '已註冊'},
        }),
        data: {'email': 'ray@example.com', 'password': 'secret123'},
      );

      await expectLater(
        authRepository.signup(email: 'ray@example.com', password: 'secret123'),
        throwsA(
          isA<ApiError>().having(
            (error) => error.code,
            'code',
            'SIGNUP_EMAIL_TAKEN',
          ),
        ),
      );
      expect(await sessionStore.read(), isNull);
    });

    test('201 但無 tripline_session cookie → 丟 ApiError', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(201, {
          'ok': true,
          'userId': 'u2hex',
          'email': 'ray@example.com',
          'requiresVerification': true,
        }),
        data: {'email': 'ray@example.com', 'password': 'secret123'},
      );

      await expectLater(
        authRepository.signup(email: 'ray@example.com', password: 'secret123'),
        throwsA(isA<ApiError>()),
      );
      expect(await sessionStore.read(), isNull);
    });
  });

  group('account recovery and verification', () {
    test('requestPasswordReset：POST /oauth/forgot-password {email}', () async {
      dioAdapter.onPost(
        '/oauth/forgot-password',
        (server) =>
            server.reply(200, {'ok': true, 'message': '若 email 已註冊，重設連結將寄至信箱'}),
        data: {'email': 'ray@example.com'},
      );

      final message = await authRepository.requestPasswordReset(
        ' ray@example.com ',
      );

      expect(message, '若 email 已註冊，重設連結將寄至信箱');
    });

    test('resetPassword：POST /oauth/reset-password {token,password}', () async {
      dioAdapter.onPost(
        '/oauth/reset-password',
        (server) => server.reply(200, {'ok': true, 'message': '密碼已更新，請用新密碼登入'}),
        data: {'token': 'reset-token', 'password': 'newSecret123'},
      );

      final message = await authRepository.resetPassword(
        token: ' reset-token ',
        password: 'newSecret123',
      );

      expect(message, '密碼已更新，請用新密碼登入');
    });

    test('verifyEmail：POST /oauth/verify {token} → true', () async {
      dioAdapter.onPost(
        '/oauth/verify',
        (server) => server.reply(200, {'ok': true}),
        data: {'token': 'verify-token'},
      );

      expect(await authRepository.verifyEmail(' verify-token '), isTrue);
    });

    test(
      'sendVerificationEmail：POST /oauth/send-verification {email}',
      () async {
        dioAdapter.onPost(
          '/oauth/send-verification',
          (server) =>
              server.reply(200, {'ok': true, 'message': '若帳號需要驗證，驗證信會寄至信箱'}),
          data: {'email': 'ray@example.com'},
        );

        final message = await authRepository.sendVerificationEmail(
          ' ray@example.com ',
        );

        expect(message, '若帳號需要驗證，驗證信會寄至信箱');
      },
    );
  });

  group('currentUser', () {
    test('200 → 回 UserInfo', () async {
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(200, userInfoJson),
      );

      final currentUser = await authRepository.currentUser();

      expect(currentUser, isNotNull);
      expect(currentUser!.email, 'ray@example.com');
    });

    test('401 → 回 null 不 throw', () async {
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(401, {
          'error': {'code': 'AUTH_REQUIRED', 'message': '請先登入'},
        }),
      );

      expect(await authRepository.currentUser(), isNull);
    });

    test('非 401 錯誤照常 throw', () async {
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(500, {
          'error': {'code': 'SYS_INTERNAL', 'message': '系統錯誤'},
        }),
      );

      await expectLater(
        authRepository.currentUser(),
        throwsA(isA<ApiError>().having((error) => error.status, 'status', 500)),
      );
    });
  });

  group('oauth consent', () {
    test('submitOAuthConsent 打 POST /oauth/consent 並保留 302 Location', () async {
      final request = OAuthConsentRequest.fromUri(
        Uri.parse(
          'https://trip.example/oauth/consent?client_id=tp_alpha'
          '&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback'
          '&scope=openid%20email'
          '&state=abc123'
          '&response_type=code',
        ),
      );
      dioAdapter.onPost(
        '/oauth/consent',
        (server) => server.reply(
          302,
          '',
          headers: {
            'location': [
              '/api/oauth/authorize?client_id=tp_alpha&state=abc123',
            ],
          },
        ),
        data: {
          'client_id': 'tp_alpha',
          'redirect_uri': 'https://app.example.com/callback',
          'scope': 'openid email',
          'state': 'abc123',
          'response_type': 'code',
          'decision': 'allow',
        },
      );

      final result = await authRepository.submitOAuthConsent(
        request,
        decision: 'allow',
      );

      expect(result.statusCode, 302);
      expect(
        result.redirectLocation,
        '/api/oauth/authorize?client_id=tp_alpha&state=abc123',
      );
    });
  });

  group('logout', () {
    test('成功時清空 store', () async {
      await sessionStore.write('abc.def');
      dioAdapter.onPost(
        '/oauth/logout',
        (server) => server.reply(200, {'ok': true}),
      );

      await authRepository.logout();

      expect(await sessionStore.read(), isNull);
    });

    test('logout API 失敗仍清空 store 且不 throw', () async {
      await sessionStore.write('abc.def');
      dioAdapter.onPost(
        '/oauth/logout',
        (server) => server.reply(500, {
          'error': {'code': 'SYS_INTERNAL', 'message': '系統錯誤'},
        }),
      );

      await authRepository.logout();

      expect(await sessionStore.read(), isNull);
    });
  });
}
