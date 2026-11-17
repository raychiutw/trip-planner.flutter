// 開啟生物辨識登入者登出時保留憑證，按「登入」直接用生物辨識解鎖（ADR-0020、#650）。
// 認證 owner 層：記憶體 token store＋mock oauth repository。
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

class _MockOAuthRepo extends Mock implements OAuthRepository {}

class _MockAuthRepo extends Mock implements AuthRepository {}

/// 記錄讀取次數：讀受生物辨識保護的憑證會跳出系統驗證。
class _CountingStore extends InMemoryOAuthTokenStore {
  int reads = 0;

  @override
  Future<OAuthTokens?> read() {
    reads++;
    return super.read();
  }
}

String _idToken() {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${enc({'alg': 'none'})}.${enc({'sub': 'u1', 'email': 'ray@example.com', 'aud': OAuthConfig.clientId, 'exp': exp})}.sig';
}

OAuthTokens _tokens({String refresh = 'RT'}) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: refresh,
  idToken: _idToken(),
  tokenType: 'DPoP',
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

void main() {
  late _CountingStore store;
  late InMemoryProofKeyStore keys;
  late _MockOAuthRepo oauthRepo;
  late _MockAuthRepo authRepo;
  var refreshes = 0;

  setUp(() async {
    refreshes = 0;
    store = _CountingStore();
    await store.write(_tokens());
    keys = InMemoryProofKeyStore();
    await keys.create();
    oauthRepo = _MockOAuthRepo();
    when(
      () => oauthRepo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => oauthRepo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer((_) async {
      refreshes++;
      return _tokens(refresh: 'RT${refreshes + 1}');
    });
    authRepo = _MockAuthRepo();
    when(
      () => authRepo.currentUser(),
    ).thenAnswer((_) async => const UserInfo(id: 'u1', email: 'x@y.z'));
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(store),
        proofKeyStoreProvider.overrideWithValue(keys),
        oauthRepositoryProvider.overrideWithValue(oauthRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void verifyNeverRevoked() => verifyNever(
    () => oauthRepo.revokeToken(
      token: any(named: 'token'),
      clientId: any(named: 'clientId'),
      tokenTypeHint: any(named: 'tokenTypeHint'),
    ),
  );

  group('開啟生物辨識登入者登出', () {
    setUp(() async => store.setProtection(TokenProtection.biometric));

    test('不呼叫撤銷，憑證與 DPoP 金鑰仍在，狀態為未登入', () async {
      final c = container();
      expect(await c.read(authStateProvider.future), isNotNull);

      await c.read(authStateProvider.notifier).logout();

      expect(c.read(authStateProvider).value, isNull);
      expect(c.read(authStateProvider).hasError, isFalse);
      verifyNeverRevoked();
      expect(await keys.load(), isNotNull, reason: '金鑰要跟憑證一起留下');
      expect(store.protection, TokenProtection.biometric, reason: '仍只接受生物辨識');
      expect((await store.read())?.refreshToken, 'RT2', reason: '憑證要留下');
    });

    test('登出後 API 取 token 不讀受保護憑證（不跳生物辨識）', () async {
      final c = container();
      await c.read(authStateProvider.future);
      await c.read(authStateProvider.notifier).logout();
      store.reads = 0;

      expect(await c.read(bearerTokenSourceProvider).accessToken(), isNull);
      expect(store.reads, 0);
    });

    test('登出後歡迎頁的登入鈕走解鎖（標成還沒解開）', () async {
      final c = container();
      await c.read(authStateProvider.future);

      await c.read(authStateProvider.notifier).logout();

      expect(c.read(authLockedProvider), isTrue);
    });

    test('按登入解鎖：讀受保護憑證 → refresh → 已登入，不開瀏覽器', () async {
      final c = container();
      await c.read(authStateProvider.future);
      await c.read(authStateProvider.notifier).logout();
      store.reads = 0;
      final before = refreshes;

      await c.read(authStateProvider.notifier).unlock();

      expect(c.read(authStateProvider).value?.email, 'ray@example.com');
      expect(store.reads, greaterThan(0), reason: '要經過受保護讀取（生物辨識）');
      expect(refreshes, before + 1, reason: '通過即 refresh');
      expect(c.read(authLockedProvider), isFalse);
    });

    group('主動登出後冷啟動', () {
      Future<void> logoutThenRestart() async {
        final c = container();
        await c.read(authStateProvider.future);
        await c.read(authStateProvider.notifier).logout();
        await store.lock(); // 重開 App：受保護的憑證要再驗證才讀得到
        store.reads = 0;
      }

      test('不讀受保護憑證、不跳生物辨識，停在未登入且登入鈕走解鎖', () async {
        await logoutThenRestart();
        final c = container();

        expect(await c.read(authStateProvider.future), isNull);
        expect(store.reads, 0);
        expect(c.read(authLockedProvider), isTrue);
      });

      test('0.42.0 的舊版保留遷移不得誤刪登出保留的憑證與金鑰', () async {
        await logoutThenRestart();
        final c = container();

        await c.read(authStateProvider.future);

        expect(await store.hasLegacyKeptMarker(), isFalse);
        expect(await keys.load(), isNotNull, reason: '金鑰要留著');
        expect(await store.read(), isNotNull, reason: '憑證要留著');
      });

      test('冷啟動後按登入解鎖 → 已登入；再下一次冷啟動照常自動還原', () async {
        await logoutThenRestart();
        final c = container();
        await c.read(authStateProvider.future);

        await c.read(authStateProvider.notifier).unlock();
        expect(c.read(authStateProvider).value, isNotNull);

        await store.lock();
        store.reads = 0;
        final next = container();
        expect(await next.read(authStateProvider.future), isNotNull);
        expect(store.reads, greaterThan(0), reason: '沒登出的冷啟動照舊讀憑證（跳生物辨識）');
      });
    });
  });

  group('未開啟生物辨識登入者登出', () {
    test('撤銷並清除，登入鈕不走解鎖', () async {
      final c = container();
      expect(await c.read(authStateProvider.future), isNotNull);

      await c.read(authStateProvider.notifier).logout();

      verify(
        () => oauthRepo.revokeToken(
          token: 'RT',
          clientId: OAuthConfig.clientId,
          tokenTypeHint: 'refresh_token',
        ),
      ).called(1);
      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
      expect(c.read(authLockedProvider), isFalse);
    });
  });

  test('切換帳號（clear: true）：開啟者也撤銷並清除', () async {
    await store.setProtection(TokenProtection.biometric);
    final c = container();
    await c.read(authStateProvider.future);

    await c.read(authStateProvider.notifier).logout(clear: true);

    verify(
      () => oauthRepo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    ).called(1);
    expect(await store.read(), isNull);
    expect(await keys.load(), isNull);
  });
}
