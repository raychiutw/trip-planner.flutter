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

/// 設定頁開啟生物辨識登入：web 重新驗證回來後的指紋步驟。
/// Android 實機曾「回到 App 沒有指紋提示、開關維持關閉、沒有任何訊息」。
void main() {
  late InMemoryOAuthTokenStore store;
  late FakeBiometricAuthenticator bio;
  late ProviderContainer container;
  late List<String> events;

  Future<void> setUp0() async {
    events = [];
    store = InMemoryOAuthTokenStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        tokenType: 'DPoP',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    final keys = InMemoryProofKeyStore();
    await keys.create();
    final oauthRepo = _MockOAuthRepo();
    final authRepo = _MockAuthRepo();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _user);
    bio = FakeBiometricAuthenticator()
      ..onAuthenticate = () => events.add('auth');
    container = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(store),
        proofKeyStoreProvider.overrideWithValue(keys),
        oauthRepositoryProvider.overrideWithValue(oauthRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
        biometricAuthenticatorProvider.overrideWithValue(bio),
        foregroundWaiterProvider.overrideWithValue(() async {
          events.add('wait');
        }),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        ...fakeBrowserLoginOverrides(stubBiometric: false),
      ],
    );
    addTearDown(container.dispose);
    container.read(oauthLoginServiceProvider);
    container.listen(biometricLoginProvider, (_, _) {});
    expect(await container.read(authStateProvider.future), _user);
  }

  BiometricLoginController ctl() =>
      container.read(biometricLoginProvider.notifier);
  BiometricLoginState st() => container.read(biometricLoginProvider);

  test('驗證指紋前先等 App 回到前景', () async {
    await setUp0();
    await ctl().reauthenticate(turnOn: true);

    expect(events, ['wait', 'auth']);
    expect(st().enabled, isTrue);
  });

  test('被系統中斷一次：再等前景並重試，重試通過就開啟', () async {
    await setUp0();
    bio.outcomes.add(BiometricOutcome.interrupted);
    await ctl().reauthenticate(turnOn: true);

    expect(events, ['wait', 'auth', 'wait', 'auth']);
    expect(store.protection, TokenProtection.biometric);
    expect(st().enabled, isTrue);
    expect(st().reauthNotice, isNull);
  });

  test('連續被中斷：不開啟，並顯示帶原因碼的提示', () async {
    await setUp0();
    bio.lastFailureCode = 'uiUnavailable';
    bio.outcomes
      ..add(BiometricOutcome.interrupted)
      ..add(BiometricOutcome.interrupted);
    await ctl().reauthenticate(turnOn: true);

    expect(bio.authenticateCalls, 2);
    expect(store.protection, TokenProtection.passcode);
    expect(st().enabled, isFalse);
    expect(st().reauthNotice, contains('uiUnavailable'));
    expect(st().reauthNotice, contains('沒有開啟'));
  });

  test('驗證失敗：不開啟，並顯示帶原因碼的提示（不再靜默）', () async {
    await setUp0();
    bio.lastFailureCode = 'noBiometricsEnrolled';
    bio.outcomes.add(BiometricOutcome.failed);
    await ctl().reauthenticate(turnOn: true);

    expect(bio.authenticateCalls, 1);
    expect(st().enabled, isFalse);
    expect(st().reauthNotice, contains('noBiometricsEnrolled'));
  });

  test('使用者自己取消：維持原狀，不顯示提示', () async {
    await setUp0();
    bio.outcomes.add(BiometricOutcome.cancelled);
    await ctl().reauthenticate(turnOn: true);

    expect(bio.authenticateCalls, 1);
    expect(st().enabled, isFalse);
    expect(st().reauthNotice, isNull);
  });
}
