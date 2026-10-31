import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late AuthRepository authRepository;
  late List<RequestOptions> recordedRequests;

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
    recordedRequests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          recordedRequests.add(options);
          handler.next(options);
        },
      ),
    );
    authRepository = AuthRepository(client: ApiClient(dio: dio));
  });

  group('public config', () {
    test(
      'fetchPublicConfig：GET /public-config → 解析 auth feature flags',
      () async {
        dioAdapter.onGet(
          '/public-config',
          (server) => server.reply(200, {
            'providers': {'google': true},
            'features': {'passwordSignup': true, 'emailVerification': true},
          }),
        );

        final config = await authRepository.fetchPublicConfig();

        expect(config.googleProviderEnabled, isTrue);
        expect(config.passwordSignupEnabled, isTrue);
        expect(config.emailVerificationEnabled, isTrue);
      },
    );
  });

  group('signup', () {
    test('201 回 signup 結果（不再有 session cookie，需另外用瀏覽器登入）', () async {
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
          },
        ),
        data: {
          'email': 'traveler@example.com',
          'password': 'secret123',
          'privacyConsent': true,
          'displayName': 'Ray',
          'invitationToken': 'invite-token',
        },
      );

      final result = await authRepository.signup(
        email: ' traveler@example.com ',
        password: 'secret123',
        privacyConsent: true,
        displayName: ' Ray ',
        invitationToken: ' invite-token ',
      );

      expect(result.userId, 'u2hex');
      expect(result.email, 'traveler@example.com');
      expect(result.requiresVerification, isTrue);
      expect(result.joinedTrip?.id, 'trip-1');
      expect(result.joinedTrip?.title, '沖繩家庭旅行');
      expect(result.invitationError, isNull);
      expect(recordedRequests.single.headers.containsKey('Origin'), isFalse);
    });

    test('SIGNUP_EMAIL_TAKEN → 丟 ApiError', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(409, {
          'error': {'code': 'SIGNUP_EMAIL_TAKEN', 'message': '已註冊'},
        }),
        data: {
          'email': 'ray@example.com',
          'password': 'secret123',
          'privacyConsent': true,
        },
      );

      await expectLater(
        authRepository.signup(
          email: 'ray@example.com',
          password: 'secret123',
          privacyConsent: true,
        ),
        throwsA(
          isA<ApiError>().having(
            (error) => error.code,
            'code',
            'SIGNUP_EMAIL_TAKEN',
          ),
        ),
      );
    });

    test('privacyConsent 會以實際 boolean false 傳給後端', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(400, {
          'error': {
            'code': 'SIGNUP_CONSENT_REQUIRED',
            'message': 'consent required',
          },
        }),
        data: {
          'email': 'ray@example.com',
          'password': 'secret123',
          'privacyConsent': false,
        },
      );

      await expectLater(
        authRepository.signup(
          email: 'ray@example.com',
          password: 'secret123',
          privacyConsent: false,
        ),
        throwsA(
          isA<ApiError>().having(
            (error) => error.code,
            'code',
            'SIGNUP_CONSENT_REQUIRED',
          ),
        ),
      );
    });

    test('SIGNUP_RATE_LIMITED 保留 Retry-After 秒數', () async {
      dioAdapter.onPost(
        '/oauth/signup',
        (server) => server.reply(
          429,
          {
            'error': {
              'code': 'SIGNUP_RATE_LIMITED',
              'message': 'too many requests',
            },
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'retry-after': ['42'],
          },
        ),
        data: {
          'email': 'ray@example.com',
          'password': 'secret123',
          'privacyConsent': true,
        },
      );

      await expectLater(
        authRepository.signup(
          email: 'ray@example.com',
          password: 'secret123',
          privacyConsent: true,
        ),
        throwsA(
          isA<ApiError>()
              .having((error) => error.code, 'code', 'SIGNUP_RATE_LIMITED')
              .having(
                (error) => error.retryAfterSeconds,
                'retryAfterSeconds',
                42,
              ),
        ),
      );
    });
  });

  group('account deletion', () {
    test('GET /account 解析刪除影響預覽且不使用快取', () async {
      dioAdapter.onGet(
        '/account',
        (server) => server.reply(200, {
          'hasPassword': true,
          'tripsOwned': 3,
          'collaboratorsAffected': 5,
        }),
      );

      final preview = await authRepository.fetchAccountDeletionPreview();

      expect(preview.hasPassword, isTrue);
      expect(preview.tripsOwned, 3);
      expect(preview.collaboratorsAffected, 5);
    });

    test('GET /account 缺少影響數字時拒絕顯示誤導性的零值', () async {
      dioAdapter.onGet(
        '/account',
        (server) => server.reply(200, {'hasPassword': true}),
      );

      await expectLater(
        authRepository.fetchAccountDeletionPreview(),
        throwsA(isA<TypeError>()),
      );
    });

    test('密碼帳號 DELETE /account 送 password', () async {
      dioAdapter.onDelete(
        '/account',
        (server) => server.reply(200, {'ok': true, 'tripsDeleted': 2}),
        data: {'password': 'secret123'},
      );

      await authRepository.deleteAccount(
        hasPassword: true,
        confirmation: 'secret123',
      );
    });

    test('DELETE /account 失敗時丟 ApiError，讓使用者可重新驗證再試', () async {
      dioAdapter.onDelete(
        '/account',
        (server) => server.reply(401, {
          'code': 'ACCOUNT_DELETE_PASSWORD_INVALID',
          'message': 'invalid password',
        }),
        data: {'password': 'wrong-password'},
      );

      await expectLater(
        authRepository.deleteAccount(
          hasPassword: true,
          confirmation: 'wrong-password',
        ),
        throwsA(isA<ApiError>()),
      );
    });

    test('純 OAuth 帳號 DELETE /account 送 confirm DELETE', () async {
      dioAdapter.onDelete(
        '/account',
        (server) => server.reply(200, {'ok': true, 'tripsDeleted': 0}),
        data: {'confirm': 'DELETE'},
      );

      await expectLater(
        authRepository.deleteAccount(
          hasPassword: false,
          confirmation: 'DELETE',
        ),
        completes,
      );
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

  group('AI authorization', () {
    test('AI authorization GET/POST 回 authorized 狀態', () async {
      dioAdapter.onGet(
        '/account/ai-authorization',
        (server) => server.reply(200, {'authorized': false}),
      );
      dioAdapter.onPost(
        '/account/ai-authorization',
        (server) => server.reply(200, {'authorized': true}),
      );

      expect(await authRepository.fetchAiAuthorization(), isFalse);
      expect(await authRepository.authorizeAi(), isTrue);
    });
  });
}
