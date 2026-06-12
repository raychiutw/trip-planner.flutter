import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/session_store.dart';

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
