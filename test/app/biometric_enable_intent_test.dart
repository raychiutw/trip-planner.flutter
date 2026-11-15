import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/oauth_protocol.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/biometric_login.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';

const _user = UserInfo(id: 'u1', email: 'a@example.com');

/// 模擬 callback：`enableIntent` 代表網址帶 `biometric_intent=enable`。
class _FakeAuth extends AuthNotifier {
  static bool enableIntent = false;
  static String? lastHint;

  @override
  Future<UserInfo?> build() async => null;

  @override
  Future<bool> signInWithBrowser({String? biometricHint}) async {
    lastHint = biometricHint;
    state = const AsyncData(_user);
    return enableIntent;
  }
}

void main() {
  late InMemoryOAuthTokenStore store;
  late InMemorySettingsStore settings;
  late FakeBiometricAuthenticator bio;
  late ProviderContainer container;

  setUp(() async {
    _FakeAuth.enableIntent = false;
    _FakeAuth.lastHint = null;
    store = InMemoryOAuthTokenStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    settings = InMemorySettingsStore();
    bio = FakeBiometricAuthenticator();
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_FakeAuth.new),
        settingsStoreProvider.overrideWithValue(settings),
        biometricAuthenticatorProvider.overrideWithValue(bio),
        oauthTokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    container.listen(biometricLoginProvider, (_, _) {});
  });

  Future<BiometricLoginState> signIn() async {
    await container.read(biometricLoginProvider.notifier).signInWithBrowser();
    // 登入後的詢問要等幾個 async 讀寫才出現。
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(biometricLoginProvider);
  }

  group('授權網址的 biometric_hint', () {
    for (final (kind, hint) in [
      (BiometricKind.faceId, OAuthProtocol.hintFaceId),
      (BiometricKind.touchId, OAuthProtocol.hintTouchId),
      (BiometricKind.biometric, OAuthProtocol.hintGeneric),
      (BiometricKind.passcode, null),
      (null, null),
    ]) {
      test('${kind?.name} → ${hint ?? '不帶'}', () async {
        bio.kind = kind;
        await signIn();
        expect(_FakeAuth.lastHint, hint);
      });
    }
  });

  group('收到 biometric_intent=enable', () {
    setUp(() => _FakeAuth.enableIntent = true);

    test('先通過生物辨識才改成生物辨識保護，且不再詢問', () async {
      final s = await signIn();

      expect(bio.authenticateCalls, 1);
      expect(store.protection, TokenProtection.biometric);
      expect(s.enabled, isTrue);
      expect(s.promptPending, isFalse, reason: '旗標處理過就不再問');
      expect(await settings.read('bio_login_prompted'), '1');
    });

    test('沒通過生物辨識（取消）→ 保護等級不變、不報錯、不再詢問', () async {
      bio.outcomes.add(BiometricOutcome.cancelled);
      final s = await signIn();

      expect(bio.authenticateCalls, 1);
      expect(store.protection, TokenProtection.passcode);
      expect(s.enabled, isFalse);
      expect(s.promptPending, isFalse, reason: '取消後也不再問第二次');
      expect(s.passcodeOnlyNotice, isFalse);
      expect(container.read(authStateProvider).value, _user);
    });

    test('驗證失敗 → 保護等級不變', () async {
      bio.outcomes.add(BiometricOutcome.failed);
      await signIn();
      expect(store.protection, TokenProtection.passcode);
    });

    test('只有裝置密碼：不驗證、不開啟、顯示提示、不報錯', () async {
      bio.kind = BiometricKind.passcode;
      final s = await signIn();

      expect(bio.authenticateCalls, 0);
      expect(store.protection, TokenProtection.passcode);
      expect(s.passcodeOnlyNotice, isTrue);
      expect(s.promptPending, isFalse);
      expect(container.read(authStateProvider).hasError, isFalse);
    });
  });

  test('沒有旗標：行為與現在相同（不驗證、不改保護、照常詢問）', () async {
    final s = await signIn();

    expect(bio.authenticateCalls, 0);
    expect(store.protection, TokenProtection.passcode);
    expect(s.promptPending, isTrue);
    expect(s.passcodeOnlyNotice, isFalse);
  });
}
