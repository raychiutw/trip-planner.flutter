import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/credential_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/biometric_login.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = UserInfo(id: 'u1', email: 'a@example.com');

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => null;

  @override
  Future<void> login(String email, String password) async =>
      state = const AsyncData(_user);
}

void main() {
  late _MockAuthRepository repo;
  late InMemoryCredentialStore store;
  late ProviderContainer container;

  BiometricLoginController ctlOf() =>
      container.read(biometricLoginProvider.notifier);
  BiometricLoginState stateOf() => container.read(biometricLoginProvider);

  setUp(() async {
    repo = _MockAuthRepository();
    store = InMemoryCredentialStore();
    when(
      () => repo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _user);
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_FakeAuth.new),
        authRepositoryProvider.overrideWithValue(repo),
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(),
        ),
        credentialStoreProvider.overrideWithValue(store),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      ],
    );
    container.listen(biometricLoginProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() => container.dispose());

  test('登入頁首次綁定：帳密登入成功就直接存進 Keychain，不再詢問', () async {
    ctlOf().rememberAttempt('a@example.com', 'pw1', bind: true);
    await container
        .read(authStateProvider.notifier)
        .login('a@example.com', 'pw1');
    await Future<void>.delayed(Duration.zero);

    expect(stateOf().hasSaved, isTrue);
    expect(stateOf().promptPending, isFalse);
    expect((await store.read())?.password, 'pw1');
  });

  test('登入頁首次綁定：登入失敗不綁定', () async {
    ctlOf().rememberAttempt('a@example.com', 'bad', bind: true);
    container.read(authStateProvider.notifier).state = AsyncError(
      const ApiError(status: 401, code: 'LOGIN_INVALID', message: 'x'),
      StackTrace.empty,
    );
    await Future<void>.delayed(Duration.zero);

    expect(stateOf().hasSaved, isFalse);
    expect(await store.read(), isNull);
  });

  group('設定頁開啟：重新輸入帳密綁定', () {
    setUp(() async {
      await container
          .read(authStateProvider.notifier)
          .login('a@example.com', 'old');
      await Future<void>.delayed(Duration.zero);
    });

    test('帳密驗證通過 → 存進 Keychain', () async {
      final outcome = await ctlOf().bind('a@example.com', 'pw1');

      expect(outcome, BindOutcome.bound);
      verify(
        () => repo.login(email: 'a@example.com', password: 'pw1'),
      ).called(1);
      expect(stateOf().hasSaved, isTrue);
      expect((await store.read())?.password, 'pw1');
    });

    test('密碼錯誤（ApiError）往上丟，不綁定', () async {
      when(
        () => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ApiError(status: 401, code: 'LOGIN_INVALID', message: 'x'),
      );

      await expectLater(
        ctlOf().bind('a@example.com', 'bad'),
        throwsA(isA<ApiError>()),
      );
      expect(stateOf().hasSaved, isFalse);
      expect(await store.read(), isNull);
    });

    test('email 不是目前登入的帳號 → 不送出驗證、不綁定', () async {
      final outcome = await ctlOf().bind('other@example.com', 'pw1');

      expect(outcome, BindOutcome.wrongAccount);
      verifyNever(
        () => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
      expect(await store.read(), isNull);
    });
  });
}
