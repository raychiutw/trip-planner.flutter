import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/map_repository.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/reports_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/models/oauth_tokens.dart';

import '../helpers/fake_oauth.dart';

class _MockOAuthRepo extends Mock implements OAuthRepository {}

/// 簽章不重要（只驗 claims）的 id_token。
String _idToken({
  String sub = 'u1hex',
  String email = 'ray@example.com',
  Duration ttl = const Duration(hours: 1),
}) {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(ttl).millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'none'})}.${enc({'sub': sub, 'email': email, 'email_verified': true, 'name': 'Ray', 'aud': OAuthConfig.clientId, 'exp': exp})}.sig';
}

OAuthTokens _tokens({String? idToken, String refresh = 'RT'}) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: refresh,
  idToken: idToken,
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

class _ThrowingClearCache extends InMemoryCacheStore {
  @override
  Future<void> clear() async => throw StateError('disk');
}

class _LockedStore extends InMemoryOAuthTokenStore {
  bool locked = true;

  @override
  Future<OAuthTokens?> read() async {
    if (locked) throw const TokenStoreLockedException();
    return super.read();
  }
}

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
  late InMemoryOAuthTokenStore store;
  late _MockOAuthRepo oauthRepo;
  late ProviderContainer container;

  ProviderContainer makeContainer({
    OAuthTokenStore? tokenStore,
    Object? loginError,
  }) {
    final c = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(tokenStore ?? store),
        oauthRepositoryProvider.overrideWithValue(oauthRepo),
        apiClientProvider.overrideWithValue(ApiClient(dio: dio)),
        ...fakeBrowserLoginOverrides(error: loginError),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    store = InMemoryOAuthTokenStore();
    oauthRepo = _MockOAuthRepo();
    when(
      () => oauthRepo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    ).thenAnswer((_) async {});
    container = makeContainer();
  });

  test('providers 串接：auth / trip repository 由 apiClient 組成', () {
    expect(container.read(authRepositoryProvider), isA<AuthRepository>());
    expect(container.read(tripRepositoryProvider), isA<TripRepository>());
    expect(container.read(mapRepositoryProvider), isA<MapRepository>());
    expect(container.read(reportsRepositoryProvider), isA<ReportsRepository>());
  });

  group('authStateProvider', () {
    test('build：沒有登入憑證 → AsyncData(null)，不打任何 API', () async {
      expect(await container.read(authStateProvider.future), isNull);
      expect(container.read(authLockedProvider), isFalse);
    });

    test('build：有憑證且 id_token 驗證通過 → 身分來自 claims', () async {
      await store.write(_tokens(idToken: _idToken()));

      final user = await container.read(authStateProvider.future);

      expect(user!.email, 'ray@example.com');
      expect(user.id, 'u1hex');
      expect(user.displayName, 'Ray');
    });

    test('build：id_token 過期 → 落回 userinfo 查身分', () async {
      await store.write(
        _tokens(idToken: _idToken(ttl: const Duration(hours: -1))),
      );
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(200, userInfoJson),
      );

      final user = await container.read(authStateProvider.future);

      expect(user!.email, 'ray@example.com');
    });

    test('build：有憑證但沒有 id_token → userinfo 401 → 未登入', () async {
      await store.write(_tokens());
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(401, {
          'error': {'code': 'AUTH_REQUIRED', 'message': '請先登入'},
        }),
      );

      expect(await container.read(authStateProvider.future), isNull);
    });

    test('build：憑證被生物辨識鎖住 → 未登入，標記需要解鎖；解鎖後登入', () async {
      final locked = _LockedStore();
      await locked.write(_tokens(idToken: _idToken()));
      final c = makeContainer(tokenStore: locked);

      expect(await c.read(authStateProvider.future), isNull);
      expect(c.read(authLockedProvider), isTrue);

      locked.locked = false;
      await c.read(authStateProvider.notifier).unlock();

      expect(c.read(authStateProvider).value!.email, 'ray@example.com');
      expect(c.read(authLockedProvider), isFalse);
    });

    test('signInWithBrowser 成功 → state 更新為登入使用者', () async {
      expect(await container.read(authStateProvider.future), isNull);
      dioAdapter.onGet(
        '/oauth/userinfo',
        (server) => server.reply(200, userInfoJson),
      );

      await container.read(authStateProvider.notifier).signInWithBrowser();

      expect(container.read(authStateProvider).value!.email, 'ray@example.com');
    });

    test('signInWithBrowser 使用者取消 → 維持未登入、不是錯誤', () async {
      final c = makeContainer(
        loginError: OAuthLoginException('取消', cancelled: true),
      );
      expect(await c.read(authStateProvider.future), isNull);

      await c.read(authStateProvider.notifier).signInWithBrowser();

      expect(c.read(authStateProvider).hasError, isFalse);
      expect(c.read(authStateProvider).value, isNull);
    });

    test('signInWithBrowser 失敗 → state 為 AsyncError', () async {
      final c = makeContainer(loginError: OAuthLoginException('boom'));
      expect(await c.read(authStateProvider.future), isNull);

      await c.read(authStateProvider.notifier).signInWithBrowser();

      expect(c.read(authStateProvider).hasError, isTrue);
    });

    test('logout：撤銷 refresh token、清空憑證，state 為 AsyncData(null)', () async {
      await store.write(_tokens(idToken: _idToken()));
      expect(await container.read(authStateProvider.future), isNotNull);

      await container.read(authStateProvider.notifier).logout();

      verify(
        () => oauthRepo.revokeToken(
          token: 'RT',
          clientId: OAuthConfig.clientId,
          tokenTypeHint: 'refresh_token',
        ),
      ).called(1);
      expect(container.read(authStateProvider).value, isNull);
      expect(await store.read(), isNull);
    });

    test('logout：DPoP 金鑰一併刪除', () async {
      final keys = InMemoryProofKeyStore();
      await keys.create();
      final c = ProviderContainer(
        overrides: [
          oauthTokenStoreProvider.overrideWithValue(store),
          proofKeyStoreProvider.overrideWithValue(keys),
          oauthRepositoryProvider.overrideWithValue(oauthRepo),
          apiClientProvider.overrideWithValue(ApiClient(dio: dio)),
        ],
      );
      addTearDown(c.dispose);
      await store.write(_tokens(idToken: _idToken()));
      expect(await c.read(authStateProvider.future), isNotNull);

      await c.read(authStateProvider.notifier).logout();

      expect(await keys.load(), isNull);
    });

    test('logout：撤銷失敗仍清空本機憑證', () async {
      when(
        () => oauthRepo.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
          tokenTypeHint: any(named: 'tokenTypeHint'),
        ),
      ).thenThrow(const ApiError(status: 500, code: 'X', message: 'x'));
      await store.write(_tokens(idToken: _idToken()));
      expect(await container.read(authStateProvider.future), isNotNull);

      await container.read(authStateProvider.notifier).logout();

      expect(container.read(authStateProvider).value, isNull);
      expect(await store.read(), isNull);
    });

    test('refresh 被後端拒絕（憑證已清）→ state 回到未登入', () async {
      await store.write(_tokens(idToken: _idToken()));
      expect(await container.read(authStateProvider.future), isNotNull);
      when(
        () => oauthRepo.refresh(
          refreshToken: any(named: 'refreshToken'),
          clientId: any(named: 'clientId'),
          proofKey: any(named: 'proofKey'),
        ),
      ).thenThrow(
        const ApiError(status: 400, code: 'invalid_grant', message: 'x'),
      );

      // access token 只在記憶體，剛啟動時沒有 → 第一次取用會 refresh，被拒。
      await container.read(bearerTokenSourceProvider).refresh();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authStateProvider).value, isNull);
      expect(await store.read(), isNull);
    });

    test('登出時清快取失敗也要回到未登入，不能卡在已登入畫面', () async {
      await store.write(_tokens(idToken: _idToken()));
      final c = ProviderContainer(
        overrides: [
          oauthTokenStoreProvider.overrideWithValue(store),
          oauthRepositoryProvider.overrideWithValue(oauthRepo),
          apiClientProvider.overrideWithValue(ApiClient(dio: dio)),
          cacheStoreProvider.overrideWithValue(_ThrowingClearCache()),
        ],
      );
      addTearDown(c.dispose);
      expect(await c.read(authStateProvider.future), isNotNull);

      await expectLater(
        c.read(authStateProvider.notifier).logout(),
        throwsA(isA<StateError>()),
      );

      expect(c.read(authStateProvider).value, isNull);
    });

    test('帳號刪除後清除離線快取與憑證，state 設為未登入', () async {
      await store.write(_tokens(idToken: _idToken()));
      expect(await container.read(authStateProvider.future), isNotNull);
      final cache = container.read(cacheStoreProvider);
      await cache.writeResponse('trip-cache', {'id': 'trip-1'});

      await container.read(authStateProvider.notifier).accountDeleted();

      expect(container.read(authStateProvider).value, isNull);
      expect(await cache.readResponse('trip-cache'), isNull);
      expect(await store.read(), isNull);
    });
  });
}
