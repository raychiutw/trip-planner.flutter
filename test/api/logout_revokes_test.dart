// 登出即撤銷（ADR-0019）：不論有沒有開啟生物辨識登入，登出都撤銷並清除；
// 舊版「已登出但保留憑證」的使用者，更新後第一次啟動直接刪掉保留的憑證。
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

const _user = UserInfo(id: 'u1', email: 'ray@example.com');

/// Android 的 Keychain 替身：biometric 項目在獨立 namespace，flutter_secure_storage
/// 對該 namespace 的任何呼叫（含 delete）都會先初始化 cipher 而跳出生物辨識。
/// 以 (namespace, key) 存放，並記錄每次以 biometric 保護碰 vault 的操作。
class _AndroidVault implements SecretVault {
  final data = <(TokenProtection, String), String>{};
  final biometricCalls = <String>[];

  void _touch(String op, String key, TokenProtection? p) {
    if (p == TokenProtection.biometric) biometricCalls.add('$op $key');
  }

  @override
  bool get biometricUsesOwnNamespace => true;

  @override
  Future<String?> read(
    String key, {
    required TokenProtection protection,
  }) async {
    _touch('read', key, protection);
    return data[(protection, key)];
  }

  @override
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  }) async {
    _touch('write', key, protection);
    data[(protection, key)] = value;
  }

  @override
  Future<void> delete(String key, {TokenProtection? protection}) async {
    final p = protection ?? TokenProtection.passcode;
    _touch('delete', key, p);
    data.remove((p, key));
  }
}

void main() {
  late _CountingStore store;
  late InMemoryProofKeyStore keys;
  late _MockOAuthRepo oauthRepo;
  late _MockAuthRepo authRepo;

  setUp(() async {
    store = _CountingStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        tokenType: 'DPoP',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
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
    authRepo = _MockAuthRepo();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _user);
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

  void verifyRevokedOnce() => verify(
    () => oauthRepo.revokeToken(
      token: 'RT',
      clientId: OAuthConfig.clientId,
      tokenTypeHint: 'refresh_token',
    ),
  ).called(1);

  // 開啟者登出改為保留（ADR-0020），見 logout_keeps_biometric_test.dart。
  group('未開啟生物辨識登入者登出撤銷並清除', () {
    test('撤銷伺服器端憑證，清掉憑證與 DPoP 金鑰', () async {
      final c = container();
      expect(await c.read(authStateProvider.future), isNotNull);

      await c.read(authStateProvider.notifier).logout();

      expect(c.read(authStateProvider).value, isNull);
      verifyRevokedOnce();
      expect(await store.read(), isNull, reason: '憑證要清掉');
      expect(await keys.load(), isNull, reason: '金鑰要跟憑證一起清掉');
    });

    test('撤銷失敗（離線）：本機仍清除，回到未登入', () async {
      when(
        () => oauthRepo.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
          tokenTypeHint: any(named: 'tokenTypeHint'),
        ),
      ).thenThrow(Exception('offline'));
      final c = container();
      expect(await c.read(authStateProvider.future), isNotNull);

      await c.read(authStateProvider.notifier).logout();

      expect(c.read(authStateProvider).value, isNull);
      expect(c.read(authStateProvider).hasError, isFalse);
      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
    });
  });

  group('啟動遷移：舊版登出後保留的憑證', () {
    setUp(() async {
      await store.setProtection(TokenProtection.biometric);
      store.legacyKeptMarker = true;
      await store.lock(); // 重開 App：受保護的憑證要再驗證才讀得到
      store.reads = 0;
    });

    test('有舊保留標記：刪掉憑證、金鑰與標記，回到未登入', () async {
      final c = container();

      expect(await c.read(authStateProvider.future), isNull);

      expect(store.legacyKeptMarker, isFalse, reason: '標記要刪掉');
      expect(await keys.load(), isNull, reason: '金鑰要刪掉');
      expect(await store.read(), isNull, reason: '憑證要刪掉');
    });

    test('不讀受保護的憑證（不跳生物辨識）、不呼叫撤銷', () async {
      final c = container();

      await c.read(authStateProvider.future);

      expect(store.reads, 0, reason: '遷移不得觸發受保護讀取');
      verifyNever(
        () => oauthRepo.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
          tokenTypeHint: any(named: 'tokenTypeHint'),
        ),
      );
      expect(c.read(authLockedProvider), isFalse, reason: '不是鎖定，是已登出');
    });

    test('沒有舊保留標記：冷啟動照常還原登入', () async {
      store.legacyKeptMarker = false;
      final c = container();

      expect((await c.read(authStateProvider.future))?.email, _user.email);
      expect(await keys.load(), isNotNull);
    });
  });

  test('Android 正式儲存層：遷移只刪不需驗證的項目，不以生物辨識保護碰 vault（不跳驗證）', () async {
    final vault = _AndroidVault();
    const pass = TokenProtection.passcode;
    vault.data[(pass, 'tripline_oauth_tokens')] =
        '{"protection":"biometric","refresh_slot":"a","bio_ns":1,'
        '"token_type":"DPoP"}';
    vault.data[(TokenProtection.biometric, 'tripline_oauth_refresh')] = 'RT';
    vault.data[(pass, 'tripline_oauth_kept_account')] = 'ray@example.com';
    final real = SecureOAuthTokenStore(vault: vault);
    final c = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(real),
        proofKeyStoreProvider.overrideWithValue(keys),
        oauthRepositoryProvider.overrideWithValue(oauthRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );
    addTearDown(c.dispose);

    expect(await c.read(authStateProvider.future), isNull);

    expect(
      vault.biometricCalls,
      isEmpty,
      reason: '碰 biometric namespace 就會跳驗證',
    );
    expect(
      vault.data.keys.where((k) => k.$1 == pass),
      isEmpty,
      reason: 'meta、標記與 passcode 區的槽位都要刪掉',
    );
    expect(await keys.load(), isNull, reason: '金鑰要刪掉');
  });
}
