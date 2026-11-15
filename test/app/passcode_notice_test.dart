import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/app_lock_host.dart';
import 'package:tripline/app/biometric_login.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';

const _text = '這支手機沒有設定 Face ID／Touch ID，已用一般方式登入';

/// 模擬 callback 帶 `biometric_intent=enable` 的登入。
class _FakeAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => null;

  @override
  Future<bool> signInWithBrowser({String? biometricHint}) async {
    state = const AsyncData(UserInfo(id: 'u1', email: 'a@example.com'));
    return true;
  }
}

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_FakeAuth.new),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(kind: BiometricKind.passcode),
        ),
        oauthTokenStoreProvider.overrideWithValue(InMemoryOAuthTokenStore()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => AppLockHost(child: child!),
          home: const Scaffold(),
        ),
      ),
    );
    await tester.pump();
  }

  bool noticeFlag() =>
      container.read(biometricLoginProvider).passcodeOnlyNotice;

  testWidgets('沒有收到旗標：不顯示提示', (tester) async {
    await pump(tester);
    expect(find.text(_text), findsNothing);
    expect(noticeFlag(), isFalse);
  });

  testWidgets('只有裝置密碼收到開啟旗標：顯示提示，4 秒後自動消失並清除狀態', (tester) async {
    await pump(tester);
    await container.read(biometricLoginProvider.notifier).signInWithBrowser();
    await tester.pump();
    expect(find.text(_text), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text(_text), findsOneWidget, reason: '4 秒內仍在');
    expect(noticeFlag(), isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_text), findsNothing);
    expect(noticeFlag(), isFalse);
  });
}
