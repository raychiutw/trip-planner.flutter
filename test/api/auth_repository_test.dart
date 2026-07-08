import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/models/auth.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late InMemorySessionStore sessionStore;
  late AuthRepository authRepository;

  const signupPw = 'secret123';
  const inviteCode = 'invite-token';
  const resetCode = 'reset-token';
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
    test('解析 set-cookie、回 SignupResult 並寫入 store', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(
          201,
          {
            'ok': true,
            'userId': 'u1hex',
            'email': 'ray@example.com',
            'requiresVerification': true,
            'joinedTrip': {'id': 'trip-1', 'title': '沖繩家族旅行'},
            'invitationError': null,
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': [
              'tripline_session=signup.token; Path=/; HttpOnly; Secure',
            ],
          },
        ),
        data: {
          'email': 'ray@example.com',
          'password': signupPw,
          'displayName': 'Ray',
          'invitationToken': inviteCode,
        },
      );

      final result = await authRepository.signup(
        email: 'ray@example.com',
        password: signupPw,
        displayName: 'Ray',
        invitationToken: inviteCode,
      );

      expect(await sessionStore.read(), 'signup.token');
      expect(result.email, 'ray@example.com');
      expect(result.requiresVerification, isTrue);
      expect(result.joinedTrip?.id, 'trip-1');
    });

    test('註冊成功但無 session cookie → 丟 ApiError', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(201, {
          'ok': true,
          'userId': 'u1hex',
          'email': 'ray@example.com',
        }),
        data: {'email': 'ray@example.com', 'password': signupPw},
      );

      await expectLater(
        authRepository.signup(email: 'ray@example.com', password: signupPw),
        throwsA(
          isA<ApiError>().having(
            (error) => error.code,
            'code',
            'AUTH_NO_SESSION_COOKIE',
          ),
        ),
      );
      expect(await sessionStore.read(), isNull);
    });
  });

  group('password and verification helpers', () {
    test('requestPasswordReset 打 POST /oauth/forgot-password', () async {
      dioAdapter.onPost(
        '/oauth/forgot-password',
        (server) =>
            server.reply(200, {'ok': true, 'message': '若 email 已註冊，重設連結將寄至信箱'}),
        data: {'email': 'ray@example.com'},
      );

      final result = await authRepository.requestPasswordReset(
        'ray@example.com',
      );

      expect(result, isA<AuthMessageResult>());
      expect(result.ok, isTrue);
      expect(result.message, contains('重設連結'));
    });

    test('resetPassword 打 POST /oauth/reset-password', () async {
      dioAdapter.onPost(
        '/oauth/reset-password',
        (server) => server.reply(200, {'ok': true, 'message': '密碼已更新，請用新密碼登入'}),
        data: {'token': resetCode, 'password': signupPw},
      );

      final result = await authRepository.resetPassword(
        token: resetCode,
        password: signupPw,
      );

      expect(result.ok, isTrue);
      expect(result.message, contains('密碼已更新'));
    });

    test('verifyEmail 打 POST /oauth/verify', () async {
      dioAdapter.onPost(
        '/oauth/verify',
        (server) => server.reply(200, {'ok': true}),
        data: {'token': 'verify-token'},
      );

      await authRepository.verifyEmail('verify-token');
    });

    test('sendVerificationEmail 打 POST /oauth/send-verification', () async {
      dioAdapter.onPost(
        '/oauth/send-verification',
        (server) =>
            server.reply(200, {'ok': true, 'message': '若帳號需要驗證，驗證信會寄至信箱'}),
        data: {'email': 'ray@example.com'},
      );

      final result = await authRepository.sendVerificationEmail(
        'ray@example.com',
      );

      expect(result.ok, isTrue);
      expect(result.message, contains('驗證信'));
    });
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
