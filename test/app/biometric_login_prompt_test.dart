import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/credential_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/app_lock_host.dart';
import 'package:tripline/app/biometric_login.dart';
import 'package:tripline/features/account/settings/biometric_login_row.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  Future<UserInfo> login({
    required String email,
    required String password,
  }) async => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _user = UserInfo(id: 'u1', email: 'a@example.com');

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => null;

  @override
  Future<void> login(String email, String password) async =>
      state = const AsyncData(_user);

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

final _prompt = find.byKey(const ValueKey('bio-login-prompt'));

void main() {
  late InMemoryCredentialStore store;
  late FakeBiometricAuthenticator bio;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    store = InMemoryCredentialStore();
    bio = FakeBiometricAuthenticator();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(_FakeAuth.new),
            authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
            settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
            biometricAuthenticatorProvider.overrideWithValue(bio),
            credentialStoreProvider.overrideWithValue(store),
          ],
        ),
        child: MaterialApp(
          builder: (context, child) => AppLockHost(child: child!),
          home: const Scaffold(body: BiometricLoginRow()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 詢問框要等幾個 async 讀寫（settings、裝置種類）才出現；沒有排程中的
  /// frame 時 pumpAndSettle 會先返回，所以明確多推幾個 frame。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> passwordLogin(WidgetTester tester) async {
    container
        .read(biometricLoginProvider.notifier)
        .rememberAttempt('a@example.com', 'pw1');
    await container
        .read(authStateProvider.notifier)
        .login('a@example.com', 'pw1');
    await settle(tester);
    // 登入後先問 App 鎖；生物辨識登入的詢問排在它之後。
    expect(find.byKey(const ValueKey('app-lock-prompt')), findsOneWidget);
    expect(_prompt, findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-cancel')));
    await settle(tester);
  }

  testWidgets('密碼登入後詢問；選「開啟」存帳密並關掉詢問框', (tester) async {
    await pump(tester);
    await passwordLogin(tester);
    expect(_prompt, findsOneWidget);
    expect(find.text('要用 Face ID 登入 Tripline 嗎？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-confirm')));
    await settle(tester);

    expect(_prompt, findsNothing);
    expect((await store.read())?.password, 'pw1');
  });

  testWidgets('選「稍後再說」：不存帳密', (tester) async {
    await pump(tester);
    await passwordLogin(tester);
    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-cancel')));
    await settle(tester);

    expect(_prompt, findsNothing);
    expect(await store.read(), isNull);
  });

  testWidgets('設定列：開啟後可關閉，關閉要先驗證並清掉帳密', (tester) async {
    await pump(tester);
    await passwordLogin(tester);
    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-confirm')));
    await settle(tester);
    expect(find.text('Face ID 登入'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(bio.authenticateCalls, 1);
    expect(await store.read(), isNull);
  });

  testWidgets('設定列：沒綁定時是關閉的；開啟要重新輸入帳密，驗證通過才綁定', (tester) async {
    await pump(tester);
    await passwordLogin(tester);
    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-cancel')));
    await settle(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(find.byKey(const ValueKey('bio-bind-dialog')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('bio-bind-password')),
      'pw2',
    );
    await tester.tap(find.byKey(const ValueKey('bio-bind-confirm')));
    await settle(tester);

    expect(find.byKey(const ValueKey('bio-bind-dialog')), findsNothing);
    expect((await store.read())?.password, 'pw2');
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('設定列：裝置沒有生物辨識就不出現', (tester) async {
    await pump(tester);
    bio.kind = null;
    container.invalidate(appLockKindProvider);
    await settle(tester);
    expect(find.byType(Switch), findsNothing);
  });
}
