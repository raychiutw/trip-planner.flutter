import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/biometric_login.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';
import '../helpers/fake_oauth.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockOAuthRepo extends Mock implements OAuthRepository {}

const _user = UserInfo(id: 'u1', email: 'ray@example.com');
const _other = UserInfo(id: 'u2', email: 'other@example.com');

/// 設定頁的生物辨識登入開關（ADR-0019）：開啟只驗一次生物辨識；關閉改回一般保存、
/// 不驗證、不登出。
void main() {
  late InMemoryOAuthTokenStore store;
  late InMemoryProofKeyStore keys;
  late FakeBiometricAuthenticator bio;
  late _MockOAuthRepo oauthRepo;
  late ProviderContainer container;
  late UserInfo currentUser;

  Future<void> setUpWith({bool biometric = false}) async {
    store = InMemoryOAuthTokenStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        tokenType: 'DPoP',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    if (biometric) await store.setProtection(TokenProtection.biometric);
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
    final authRepo = _MockAuthRepo();
    currentUser = _user;
    when(() => authRepo.currentUser()).thenAnswer((_) async => currentUser);
    bio = FakeBiometricAuthenticator();
    container = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(store),
        proofKeyStoreProvider.overrideWithValue(keys),
        oauthRepositoryProvider.overrideWithValue(oauthRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
        biometricAuthenticatorProvider.overrideWithValue(bio),
        foregroundWaiterProvider.overrideWithValue(() async {}),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        ...fakeBrowserLoginOverrides(stubBiometric: false),
      ],
    );
    addTearDown(container.dispose);
    container.listen(biometricLoginProvider, (_, _) {});
    expect(await container.read(authStateProvider.future), _user);
  }

  BiometricLoginController ctl() =>
      container.read(biometricLoginProvider.notifier);
  BiometricLoginState st() => container.read(biometricLoginProvider);

  group('開啟', () {
    test('只驗一次生物辨識（只接受生物辨識）就改成生物辨識保護', () async {
      await setUpWith();

      final ok = await ctl().enable();

      expect(ok, isTrue);
      expect(bio.biometricOnlyCalls, [true]);
      expect(store.protection, TokenProtection.biometric);
      expect(st().enabled, isTrue);
      expect(container.read(authStateProvider).value, _user);
    });

    test('取消：維持一般保存', () async {
      await setUpWith();
      bio.outcomes.add(BiometricOutcome.cancelled);

      expect(await ctl().enable(), isFalse);
      expect(bio.authenticateCalls, 1);
      expect(store.protection, TokenProtection.passcode);
      expect(st().enabled, isFalse);
    });
  });

  group('驗證期間登入狀態改變：丟棄結果，不把舊憑證寫回', () {
    test('驗證期間登出', () async {
      await setUpWith();
      bio.whileAuthenticating = () =>
          container.read(authStateProvider.notifier).logout();

      expect(await ctl().enable(), isFalse);
      expect(container.read(authStateProvider).value, isNull);
      expect(store.protection, TokenProtection.passcode);
      expect(await store.read(), isNull, reason: '舊憑證不得寫回');
      expect(st().enabled, isFalse);
    });

    test('驗證期間登出並換成另一個帳號登入', () async {
      await setUpWith();
      bio.whileAuthenticating = () async {
        final auth = container.read(authStateProvider.notifier);
        await auth.logout();
        currentUser = _other;
        await auth.signInWithBrowser();
      };

      expect(await ctl().enable(), isFalse);
      expect(container.read(authStateProvider).value, _other);
      expect(
        store.protection,
        TokenProtection.passcode,
        reason: '新帳號沒有同意開啟，不能套用上一個帳號的驗證結果',
      );
      expect(st().enabled, isFalse);
    });
  });

  group('關閉', () {
    test('改回一般保存，不驗證、不登出、不撤銷，憑證與金鑰都還在', () async {
      await setUpWith(biometric: true);
      expect(st().enabled, isTrue);

      final ok = await ctl().disable();

      expect(ok, isTrue);
      expect(bio.authenticateCalls, 0);
      expect(store.protection, TokenProtection.passcode);
      expect(st().enabled, isFalse);
      expect(container.read(authStateProvider).value, _user);
      expect((await store.read())?.refreshToken, 'RT');
      expect(await keys.load(), isNotNull);
      verifyNever(
        () => oauthRepo.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
          tokenTypeHint: any(named: 'tokenTypeHint'),
        ),
      );
    });
  });
}
