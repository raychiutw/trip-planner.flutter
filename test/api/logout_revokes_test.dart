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

  group('登出一律撤銷並清除', () {
    for (final biometric in [true, false]) {
      final label = biometric ? '開啟' : '未開啟';
      test('$label生物辨識登入：撤銷伺服器端憑證，清掉憑證與 DPoP 金鑰', () async {
        if (biometric) await store.setProtection(TokenProtection.biometric);
        final c = container();
        expect(await c.read(authStateProvider.future), isNotNull);

        await c.read(authStateProvider.notifier).logout();

        expect(c.read(authStateProvider).value, isNull);
        verifyRevokedOnce();
        expect(await store.read(), isNull, reason: '憑證要清掉');
        expect(await keys.load(), isNull, reason: '金鑰要跟憑證一起清掉');
      });
    }

    for (final biometric in [true, false]) {
      final label = biometric ? '開啟' : '未開啟';
      test('$label生物辨識登入且撤銷失敗（離線）：本機仍清除，回到未登入', () async {
        if (biometric) await store.setProtection(TokenProtection.biometric);
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
    }
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
}
