import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/oauth_protocol.dart';
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

void main() {
  late InMemoryOAuthTokenStore store;
  late InMemoryProofKeyStore keys;
  late FakeBiometricAuthenticator bio;
  late FakeOAuthLoginService service;
  late ProviderContainer container;

  Future<void> setUpWith({Object? reauthError, bool biometric = false}) async {
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
    final oauthRepo = _MockOAuthRepo();
    when(
      () => oauthRepo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    ).thenAnswer((_) async {});
    final authRepo = _MockAuthRepo();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _user);
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
        ...fakeBrowserLoginOverrides(
          stubBiometric: false,
          reauthError: reauthError,
          created: (s) => service = s,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(oauthLoginServiceProvider); // 綁定這一輪的 fake
    container.listen(biometricLoginProvider, (_, _) {});
    expect(await container.read(authStateProvider.future), _user);
  }

  BiometricLoginController ctl() =>
      container.read(biometricLoginProvider.notifier);
  BiometricLoginState st() => container.read(biometricLoginProvider);

  group('開啟', () {
    test('重新驗證通過 + 生物辨識通過 → 改成生物辨識保護；授權帶 enable 與目前帳號', () async {
      await setUpWith();
      await ctl().reauthenticate(turnOn: true);

      expect(service.reauthCalls, 1);
      expect(service.lastReauthIntent, OAuthProtocol.intentEnable);
      expect(service.lastExpectedAccount, 'u1');
      expect(service.lastReauthHint, OAuthProtocol.hintFaceId);
      expect(bio.authenticateCalls, 1);
      expect(store.protection, TokenProtection.biometric);
      expect(st().enabled, isTrue);
      expect(st().reauthBusy, isFalse);
      expect(container.read(authStateProvider).value, _user);
    });

    test('重新驗證通過但生物辨識被取消 → 維持原狀、不報錯', () async {
      await setUpWith();
      bio.outcomes.add(BiometricOutcome.cancelled);
      await ctl().reauthenticate(turnOn: true);

      expect(bio.authenticateCalls, 1);
      expect(store.protection, TokenProtection.passcode);
      expect(st().enabled, isFalse);
      expect(st().reauthNotice, isNull);
      expect(st().reauthBusy, isFalse);
    });

    test('沒有通過重新驗證（任何失敗）→ 不問生物辨識、不套用', () async {
      await setUpWith(reauthError: OAuthLoginException('boom'));
      await ctl().reauthenticate(turnOn: true);

      expect(bio.authenticateCalls, 0);
      expect(store.protection, TokenProtection.passcode);
      expect(st().enabled, isFalse);
      expect(st().reauthBusy, isFalse);
    });

    test('只有裝置密碼：不發起重新驗證（沒東西可開）', () async {
      await setUpWith();
      bio.kind = BiometricKind.passcode;
      await ctl().reauthenticate(turnOn: true);

      expect(service.reauthCalls, 0);
      expect(store.protection, TokenProtection.passcode);
    });
  });

  group('關閉', () {
    test('重新驗證 + 生物辨識通過 → 憑證與 DPoP 金鑰一起清除並登出', () async {
      await setUpWith(biometric: true);
      await ctl().reauthenticate(turnOn: false);

      expect(service.lastReauthIntent, OAuthProtocol.intentDisable);
      expect(bio.authenticateCalls, 1);
      expect(container.read(authStateProvider).value, isNull);
      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
    });

    test('生物辨識被取消 → 不清、不登出', () async {
      await setUpWith(biometric: true);
      bio.outcomes.add(BiometricOutcome.cancelled);
      await ctl().reauthenticate(turnOn: false);

      expect(container.read(authStateProvider).value, _user);
      expect((await store.read())!.refreshToken, 'RT');
      expect(await keys.load(), isNotNull);
    });

    test('沒有通過重新驗證 → 不問生物辨識、不清、不登出', () async {
      await setUpWith(
        biometric: true,
        reauthError: OAuthLoginException('boom'),
      );
      await ctl().reauthenticate(turnOn: false);

      expect(bio.authenticateCalls, 0);
      expect(container.read(authStateProvider).value, _user);
      expect(await store.read(), isNotNull);
      expect(await keys.load(), isNotNull);
    });
  });

  group('取消與帳號不符', () {
    for (final enable in [true, false]) {
      test('關掉授權視窗（enable=$enable）：什麼都不變、沒有提示', () async {
        await setUpWith(
          biometric: !enable,
          reauthError: OAuthLoginException('取消', cancelled: true),
        );
        await ctl().reauthenticate(turnOn: enable);

        expect(bio.authenticateCalls, 0);
        expect(
          store.protection,
          enable ? TokenProtection.passcode : TokenProtection.biometric,
        );
        expect(container.read(authStateProvider).value, _user);
        expect(await keys.load(), isNotNull);
        expect(st().reauthNotice, isNull);
      });

      test('帳號不同（enable=$enable）：提示、不改任何狀態、不登出', () async {
        await setUpWith(
          biometric: !enable,
          reauthError: OAuthLoginException(
            'mismatch',
            userMessage: '登入的帳號與目前帳號不同',
            accountMismatch: true,
          ),
        );
        await ctl().reauthenticate(turnOn: enable);

        expect(st().reauthNotice, '登入的帳號與目前帳號不同');
        expect(bio.authenticateCalls, 0);
        expect(
          store.protection,
          enable ? TokenProtection.passcode : TokenProtection.biometric,
        );
        expect(container.read(authStateProvider).value, _user);
        expect((await store.read())!.refreshToken, 'RT');
        expect(await keys.load(), isNotNull);
      });
    }
  });

  test('進行中再觸發：忽略（只發起一次）', () async {
    await setUpWith();
    service.onReauth = () async {
      expect(st().reauthBusy, isTrue);
      await ctl().reauthenticate(turnOn: true);
    };
    await ctl().reauthenticate(turnOn: true);

    expect(service.reauthCalls, 1);
  });
}
