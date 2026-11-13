import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../../helpers/fake_biometric.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockOAuthRepo extends Mock implements OAuthRepository {}

/// 瀏覽器登入成另一個帳號：換新憑證、新金鑰（與正式的 OAuthLoginService 一樣）。
class _OtherAccountLogin implements OAuthLoginService {
  _OtherAccountLogin(this._source, this._keys);
  final StoredBearerTokenSource _source;
  final ProofKeyStore _keys;

  @override
  Future<OAuthTokens> login() async {
    await _keys.create();
    final tokens = OAuthTokens(
      accessToken: 'AT2',
      refreshToken: 'RT2',
      tokenType: 'DPoP',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    await _source.adopt(tokens);
    return tokens;
  }
}

const _userA = UserInfo(id: 'a', email: 'a@example.com');
const _userB = UserInfo(id: 'b', email: 'b@example.com');
const _entry = ValueKey('login-biometric-button');
const _browser = ValueKey('login-browser-button');
const _kept = 'bio_login_kept_account';

void main() {
  late InMemoryOAuthTokenStore store;
  late InMemorySettingsStore settings;
  late InMemoryProofKeyStore keys;
  late _MockOAuthRepo oauthRepo;
  late _MockAuthRepo authRepo;
  late InMemoryCacheStore cache;

  Widget app() => ProviderScope(
    key: UniqueKey(),
    overrides: [
      oauthTokenStoreProvider.overrideWithValue(store),
      proofKeyStoreProvider.overrideWithValue(keys),
      oauthRepositoryProvider.overrideWithValue(oauthRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
      biometricAuthenticatorProvider.overrideWithValue(
        FakeBiometricAuthenticator(),
      ),
      settingsStoreProvider.overrideWithValue(settings),
      cacheStoreProvider.overrideWithValue(cache),
      oauthLoginServiceProvider.overrideWith(
        (ref) => _OtherAccountLogin(ref.watch(bearerTokenSourceProvider), keys),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const LoginScreen())],
      ),
    ),
  );

  /// 登入 A（開啟生物辨識登入）後登出，停在有 Face ID 入口的登入頁。
  Future<ProviderContainer> pumpKept(WidgetTester tester) async {
    store = InMemoryOAuthTokenStore();
    settings = InMemorySettingsStore();
    cache = InMemoryCacheStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        tokenType: 'DPoP',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    await store.setProtection(TokenProtection.biometric);
    keys = InMemoryProofKeyStore();
    await keys.create();
    oauthRepo = _MockOAuthRepo();
    authRepo = _MockAuthRepo();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _userA);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await c.read(authStateProvider.future);
    await c.read(authStateProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(find.byKey(_entry), findsOneWidget);
    return c;
  }

  void tokenEndpointRejects(int status) => when(
    () => oauthRepo.refresh(
      refreshToken: any(named: 'refreshToken'),
      clientId: any(named: 'clientId'),
      proofKey: any(named: 'proofKey'),
    ),
  ).thenThrow(ApiError(status: status, code: 'invalid_grant', message: 'x'));

  Future<void> expectCleared(ProviderContainer c) async {
    expect(await store.read(), isNull, reason: '憑證要清掉');
    expect(await keys.load(), isNull, reason: '金鑰要清掉');
    expect(await settings.read(_kept), anyOf(isNull, ''), reason: '保留標記要清掉');
    expect(c.read(authStateProvider).value, isNull);
  }

  for (final status in [400, 401]) {
    testWidgets('按入口後 refresh 被拒($status)：清憑證／金鑰／標記、入口消失、顯示失效訊息', (
      tester,
    ) async {
      final c = await pumpKept(tester);
      tokenEndpointRejects(status);

      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();

      await expectCleared(c);
      expect(find.byKey(_entry), findsNothing);
      expect(find.byKey(_browser), findsOneWidget);
      expect(find.text('登入已失效，請用瀏覽器重新登入'), findsOneWidget);
    });
  }

  testWidgets('暫時性網路錯誤：不判失效，憑證與金鑰保留、照常登入', (tester) async {
    final c = await pumpKept(tester);
    when(
      () => oauthRepo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenThrow(Exception('offline'));

    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();

    expect(find.text('登入已失效，請用瀏覽器重新登入'), findsNothing);
    expect(c.read(authStateProvider).value?.email, 'a@example.com');
    expect(await store.read(), isNotNull);
    expect(await keys.load(), isNotNull);
  });

  testWidgets('金鑰因生物特徵變更而遺失：清掉並說明原因', (tester) async {
    final c = await pumpKept(tester);
    await keys.delete(); // 硬體金鑰失效 → load() 回 null

    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();

    await expectCleared(c);
    expect(find.byKey(_entry), findsNothing);
    expect(find.textContaining('生物辨識資料已變更'), findsOneWidget);
  });

  testWidgets('受保護憑證因生物特徵變更被儲存層清掉：清掉標記與金鑰並說明原因', (tester) async {
    final c = await pumpKept(tester);
    await store.clear(); // SecureOAuthTokenStore 讀到 invalidated 時的行為

    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();

    await expectCleared(c);
    expect(find.byKey(_entry), findsNothing);
    expect(find.textContaining('生物辨識資料已變更'), findsOneWidget);
  });

  testWidgets('保留模式下改用瀏覽器登入成另一個帳號：舊憑證／金鑰／標記被覆蓋，不串帳號', (tester) async {
    final c = await pumpKept(tester);
    final oldKey = await keys.load();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _userB);

    await tester.tap(find.byKey(_browser));
    await tester.pumpAndSettle();

    expect(c.read(authStateProvider).value?.email, 'b@example.com');
    expect((await store.read())?.refreshToken, 'RT2');
    expect(await keys.load(), isNot(same(oldKey)));
    expect(await settings.read(_kept), anyOf(isNull, ''));
    expect(c.read(keptBiometricAccountProvider).value, isNull);
  });

  testWidgets('保留標記存在時快取擁有者檢查仍成立：換帳號清掉前一人的快取', (tester) async {
    final c = await pumpKept(tester);
    await cache.writeResponse('__cache_owner__', 'a|a@example.com');
    await cache.writeResponse('trip:1', 'A 的資料');
    when(() => authRepo.currentUser()).thenAnswer((_) async => _userB);

    await tester.tap(find.byKey(_browser));
    await tester.pumpAndSettle();

    expect(c.read(authStateProvider).value?.email, 'b@example.com');
    expect(await cache.readResponse('trip:1'), isNull);
  });
}
