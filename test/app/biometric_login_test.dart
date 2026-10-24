import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/credential_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/biometric_login.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';

const _user = UserInfo(id: 'u1', email: 'a@example.com');

class _FakeAuth extends AuthNotifier {
  final logins = <(String, String)>[];
  Object? failWith;

  @override
  Future<UserInfo?> build() async => null;

  @override
  Future<void> login(String email, String password) async {
    logins.add((email, password));
    state = failWith == null
        ? const AsyncData(_user)
        : AsyncError(failWith!, StackTrace.empty);
  }

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

class _Rig {
  _Rig({this.kind = BiometricKind.faceId, List<BiometricOutcome>? outcomes})
    : bio = FakeBiometricAuthenticator(kind: kind, outcomes: outcomes);
  final BiometricKind? kind;
  final FakeBiometricAuthenticator bio;
  final store = InMemoryCredentialStore();
  final settings = InMemorySettingsStore();
  final auth = _FakeAuth();

  late final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(() => auth),
      biometricAuthenticatorProvider.overrideWithValue(bio),
      credentialStoreProvider.overrideWithValue(store),
      settingsStoreProvider.overrideWithValue(settings),
    ],
  );

  BiometricLoginController get ctl =>
      container.read(biometricLoginProvider.notifier);
  BiometricLoginState get state => container.read(biometricLoginProvider);

  Future<void> start() async {
    container.listen(biometricLoginProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  /// 模擬登入畫面：先登記帳密，再呼叫 login。
  Future<void> passwordLogin() async {
    ctl.rememberAttempt('a@example.com', 'pw1');
    await auth.login('a@example.com', 'pw1');
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('密碼登入成功後詢問一次；選開啟就存帳密並標記已問過', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    expect(rig.state.promptPending, isTrue);

    await rig.ctl.answerPrompt(enable: true);
    expect(rig.state.promptPending, isFalse);
    expect(rig.state.hasSaved, isTrue);
    final saved = await rig.store.read();
    expect(saved?.email, 'a@example.com');
    expect(saved?.password, 'pw1');
    expect(await rig.settings.read('bio_login_prompted'), '1');
  });

  test('選稍後再說：不存帳密，之後登入不再問', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    await rig.ctl.answerPrompt(enable: false);
    expect(await rig.store.read(), isNull);

    await rig.auth.logout();
    await rig.passwordLogin();
    expect(rig.state.promptPending, isFalse);
  });

  test('裝置沒有生物辨識：不問也不記為已問過', () async {
    final rig = _Rig(kind: null);
    await rig.start();
    await rig.passwordLogin();
    expect(rig.state.promptPending, isFalse);
    expect(await rig.settings.read('bio_login_prompted'), isNull);
  });

  test('已開啟時用新密碼登入成功：靜默更新存下的密碼', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    await rig.ctl.answerPrompt(enable: true);
    await rig.auth.logout();

    rig.ctl.rememberAttempt('a@example.com', 'pw2');
    await rig.auth.login('a@example.com', 'pw2');
    await Future<void>.delayed(Duration.zero);
    expect((await rig.store.read())?.password, 'pw2');
    expect(rig.state.promptPending, isFalse);
  });

  test('登出保留存下的帳密（登出後仍能用生物辨識登入）', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    await rig.ctl.answerPrompt(enable: true);
    await rig.auth.logout();
    expect(rig.state.hasSaved, isTrue);
    expect(await rig.store.read(), isNotNull);
  });

  test('生物辨識登入：驗證成功才讀帳密並登入', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    await rig.ctl.answerPrompt(enable: true);
    await rig.auth.logout();
    rig.auth.logins.clear();
    rig.bio.outcomes.add(BiometricOutcome.success);

    final outcome = await rig.ctl.loginWithBiometric();
    expect(outcome, BiometricOutcome.success);
    expect(rig.auth.logins, [('a@example.com', 'pw1')]);
  });

  for (final o in [BiometricOutcome.cancelled, BiometricOutcome.failed]) {
    test('生物辨識${o.name}：不送出登入、保留帳密', () async {
      final rig = _Rig();
      await rig.start();
      await rig.passwordLogin();
      await rig.ctl.answerPrompt(enable: true);
      await rig.auth.logout();
      rig.auth.logins.clear();
      rig.bio.outcomes.add(o);

      expect(await rig.ctl.loginWithBiometric(), o);
      expect(rig.auth.logins, isEmpty);
      expect(await rig.store.read(), isNotNull);
    });
  }

  test('存下的密碼已失效（LOGIN_INVALID）：清掉帳密，改回手動登入', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    await rig.ctl.answerPrompt(enable: true);
    await rig.auth.logout();

    rig.auth.failWith = const ApiError(
      status: 401,
      code: 'LOGIN_INVALID',
      message: 'bad',
    );
    await rig.ctl.loginWithBiometric();
    await Future<void>.delayed(Duration.zero);
    expect(await rig.store.read(), isNull);
    expect(rig.state.hasSaved, isFalse);
  });

  test('一般失敗（例如網路）：保留帳密', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    await rig.ctl.answerPrompt(enable: true);
    await rig.auth.logout();

    rig.auth.failWith = Exception('offline');
    await rig.ctl.loginWithBiometric();
    await Future<void>.delayed(Duration.zero);
    expect(await rig.store.read(), isNotNull);
  });

  test('關閉：先驗證身分，通過才清除帳密', () async {
    final rig = _Rig();
    await rig.start();
    await rig.passwordLogin();
    await rig.ctl.answerPrompt(enable: true);

    rig.bio.outcomes.add(BiometricOutcome.failed);
    expect(await rig.ctl.disable(), isFalse);
    expect(rig.state.hasSaved, isTrue);

    expect(await rig.ctl.disable(), isTrue);
    expect(rig.state.hasSaved, isFalse);
    expect(await rig.store.read(), isNull);
  });

  test('密碼登入失敗：不詢問、不存帳密', () async {
    final rig = _Rig();
    await rig.start();
    rig.auth.failWith = const ApiError(
      status: 401,
      code: 'LOGIN_INVALID',
      message: 'bad',
    );
    await rig.passwordLogin();
    expect(rig.state.promptPending, isFalse);
    expect(await rig.store.read(), isNull);
  });
}
