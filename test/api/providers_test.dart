import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/api/trip_repository.dart';

void main() {
  const userInfoJson = {
    'id': 'u1hex',
    'email': 'ray@example.com',
    'emailVerified': 1,
    'displayName': 'Ray',
    'avatarUrl': null,
    'createdAt': '2026-01-01T00:00:00Z',
  };

  late Dio dio;
  late DioAdapter dioAdapter;
  late InMemorySessionStore sessionStore;
  late ProviderContainer container;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    sessionStore = InMemorySessionStore();
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        apiClientProvider.overrideWithValue(
          ApiClient(sessionStore: sessionStore, dio: dio),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('providers 串接：auth / trip repository 由 apiClient 組成', () {
    expect(container.read(authRepositoryProvider), isA<AuthRepository>());
    expect(container.read(tripRepositoryProvider), isA<TripRepository>());
  });

  test('sessionStoreProvider 預設為 SecureSessionStore', () {
    final defaultContainer = ProviderContainer();
    addTearDown(defaultContainer.dispose);

    expect(
      defaultContainer.read(sessionStoreProvider),
      isA<SecureSessionStore>(),
    );
  });

  test('ApiEndpointConfig 預設正式站 origin 與 /api base URL', () {
    final config = ApiEndpointConfig.fromApiUrl('');

    expect(config.origin, kTriplineOrigin);
    expect(config.apiBaseUrl, '$kTriplineOrigin/api');
  });

  test('ApiEndpointConfig 可由 TRIPLINE_API_URL 接受 origin 或 /api URL', () {
    final originConfig = ApiEndpointConfig.fromApiUrl('http://127.0.0.1:8788');
    final apiUrlConfig = ApiEndpointConfig.fromApiUrl(
      'http://127.0.0.1:8788/api',
    );

    expect(originConfig.origin, 'http://127.0.0.1:8788');
    expect(originConfig.apiBaseUrl, 'http://127.0.0.1:8788/api');
    expect(apiUrlConfig.origin, 'http://127.0.0.1:8788');
    expect(apiUrlConfig.apiBaseUrl, 'http://127.0.0.1:8788/api');
  });

  test('ApiEndpointConfig 正規化 trailing slash 並拒絕不安全 URL', () {
    final config = ApiEndpointConfig.fromApiUrl(' http://127.0.0.1:8788/api/ ');

    expect(config.origin, 'http://127.0.0.1:8788');
    expect(config.apiBaseUrl, 'http://127.0.0.1:8788/api');
    expect(() => ApiEndpointConfig.fromApiUrl('/api'), throwsArgumentError);
    expect(
      () => ApiEndpointConfig.fromApiUrl('http://127.0.0.1:8788/api?debug=1'),
      throwsArgumentError,
    );
    expect(
      () => ApiEndpointConfig.fromApiUrl('http://127.0.0.1:8788/api#local'),
      throwsArgumentError,
    );
  });

  test('apiClientProvider 使用 apiEndpointProvider 的 base URL 與 Origin', () {
    final localContainer = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        apiEndpointProvider.overrideWithValue(
          const ApiEndpointConfig(
            origin: 'http://127.0.0.1:8788',
            apiBaseUrl: 'http://127.0.0.1:8788/api',
          ),
        ),
      ],
    );
    addTearDown(localContainer.dispose);

    final client = localContainer.read(apiClientProvider);

    expect(client.dio.options.baseUrl, 'http://127.0.0.1:8788/api');
  });

  group('authStateProvider', () {
    test('build：未登入（userinfo 401）→ AsyncData(null)', () async {
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(401, {
          'error': {'code': 'AUTH_REQUIRED', 'message': '請先登入'},
        }),
      );

      final initialUser = await container.read(authStateProvider.future);

      expect(initialUser, isNull);
    });

    test('login 後 state 更新為登入使用者', () async {
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(401, {
          'error': {'code': 'AUTH_REQUIRED', 'message': '請先登入'},
        }),
      );
      expect(await container.read(authStateProvider.future), isNull);

      dioAdapter.onPost(
        '/oauth/login',
        (server) => server.reply(
          200,
          {'ok': true, 'userId': 'u1hex', 'email': 'ray@example.com'},
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': ['tripline_session=abc.def; Path=/; HttpOnly'],
          },
        ),
        data: {'email': 'ray@example.com', 'password': 'secret'},
      );
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(200, userInfoJson),
      );

      await container
          .read(authStateProvider.notifier)
          .login('ray@example.com', 'secret');

      final authState = container.read(authStateProvider);
      expect(authState.value!.email, 'ray@example.com');
      expect(await sessionStore.read(), 'abc.def');
    });

    test('login 失敗 → state 為 AsyncError', () async {
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(401, {
          'error': {'code': 'AUTH_REQUIRED', 'message': '請先登入'},
        }),
      );
      expect(await container.read(authStateProvider.future), isNull);

      dioAdapter.onPost(
        '/oauth/login',
        (server) => server.reply(401, {
          'error': {'code': 'LOGIN_INVALID', 'message': '帳號或密碼錯誤'},
        }),
        data: {'email': 'ray@example.com', 'password': 'wrong'},
      );

      await container
          .read(authStateProvider.notifier)
          .login('ray@example.com', 'wrong');

      expect(container.read(authStateProvider).hasError, isTrue);
    });

    test('logout 後 state 為 AsyncData(null) 且 store 清空', () async {
      await sessionStore.write('abc.def');
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(200, userInfoJson),
      );
      final loggedInUser = await container.read(authStateProvider.future);
      expect(loggedInUser, isNotNull);

      dioAdapter.onPost(
        '/oauth/logout',
        (server) => server.reply(200, {'ok': true}),
      );

      await container.read(authStateProvider.notifier).logout();

      expect(container.read(authStateProvider).value, isNull);
      expect(await sessionStore.read(), isNull);
    });

    test('updateProfile 後 state 更新為後端回傳 UserInfo', () async {
      await sessionStore.write('abc.def');
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(200, userInfoJson),
      );
      final loggedInUser = await container.read(authStateProvider.future);
      expect(loggedInUser!.displayName, 'Ray');

      final updatedUserInfoJson = {...userInfoJson, 'displayName': '新名字'};
      dioAdapter.onPatch(
        '/account/profile',
        (server) => server.reply(200, updatedUserInfoJson),
        data: {'displayName': '新名字'},
      );

      final updatedUser = await container
          .read(authStateProvider.notifier)
          .updateProfile(displayName: '新名字');

      expect(updatedUser.displayName, '新名字');
      expect(container.read(authStateProvider).value!.displayName, '新名字');
    });
  });
}
