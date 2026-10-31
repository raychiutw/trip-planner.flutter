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
import 'package:tripline/features/account/settings/biometric_login_row.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';

const _user = UserInfo(id: 'u1', email: 'a@example.com');

class _FakeAuth extends AuthNotifier {
  int logouts = 0;

  @override
  Future<UserInfo?> build() async => null;

  void signIn() => state = const AsyncData(_user);

  @override
  Future<void> logout() async {
    logouts++;
    await ref.read(oauthTokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final _prompt = find.byKey(const ValueKey('bio-login-prompt'));

void main() {
  late InMemoryOAuthTokenStore store;
  late FakeBiometricAuthenticator bio;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    store = InMemoryOAuthTokenStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    bio = FakeBiometricAuthenticator();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(_FakeAuth.new),
            settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
            biometricAuthenticatorProvider.overrideWithValue(bio),
            oauthTokenStoreProvider.overrideWithValue(store),
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

  /// 詢問框要等幾個 async 讀寫才出現；沒有排程中的 frame 時 pumpAndSettle 會先
  /// 返回，所以明確多推幾個 frame。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  /// 登入後先問 App 鎖；生物辨識登入的詢問排在它之後。
  Future<void> signInAndDismissAppLockPrompt(WidgetTester tester) async {
    (container.read(authStateProvider.notifier) as _FakeAuth).signIn();
    await settle(tester);
    expect(find.byKey(const ValueKey('app-lock-prompt')), findsOneWidget);
    expect(_prompt, findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-cancel')));
    await settle(tester);
  }

  testWidgets('登入後詢問；選「開啟」驗證後把 refresh token 改成生物辨識保護', (tester) async {
    await pump(tester);
    await signInAndDismissAppLockPrompt(tester);
    expect(_prompt, findsOneWidget);
    expect(find.text('要用 Face ID 登入 Tripline 嗎？'), findsOneWidget);
    expect(store.protection, TokenProtection.passcode);

    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-confirm')));
    await settle(tester);

    expect(_prompt, findsNothing);
    expect(bio.authenticateCalls, 1);
    expect(store.protection, TokenProtection.biometric);
    expect((await store.read())!.refreshToken, 'RT'); // 憑證還在，沒被登出
  });

  testWidgets('選「稍後再說」：保護等級不變，也不驗證', (tester) async {
    await pump(tester);
    await signInAndDismissAppLockPrompt(tester);
    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-cancel')));
    await settle(tester);

    expect(_prompt, findsNothing);
    expect(bio.authenticateCalls, 0);
    expect(store.protection, TokenProtection.passcode);
  });

  testWidgets('只有裝置密碼（沒有生物辨識）：不詢問', (tester) async {
    await pump(tester);
    bio.kind = BiometricKind.passcode;
    (container.read(authStateProvider.notifier) as _FakeAuth).signIn();
    await settle(tester);
    // 只會有 App 鎖的詢問（若有），不會有生物辨識登入的詢問。
    final cancel = find.byKey(const ValueKey('app-lock-dialog-cancel'));
    if (cancel.evaluate().isNotEmpty) {
      await tester.tap(cancel);
      await settle(tester);
    }
    expect(_prompt, findsNothing);
  });

  testWidgets('開啟時驗證被取消：保護等級不變', (tester) async {
    await pump(tester);
    bio.outcomes.add(BiometricOutcome.cancelled);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(store.protection, TokenProtection.passcode);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('設定列：開啟後可關閉，關閉要確認、驗證，並清掉憑證登出', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(store.protection, TokenProtection.biometric);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(find.byKey(const ValueKey('bio-disable-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bio-disable-confirm')));
    await settle(tester);

    expect(bio.authenticateCalls, 2); // 開啟一次、關閉一次
    expect(await store.read(), isNull);
    expect(
      (container.read(authStateProvider.notifier) as _FakeAuth).logouts,
      1,
    );
  });

  testWidgets('關閉時在確認框按取消：什麼都不動', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('bio-disable-cancel')));
    await settle(tester);

    expect(store.protection, TokenProtection.biometric);
    expect(
      (container.read(authStateProvider.notifier) as _FakeAuth).logouts,
      0,
    );
  });

  testWidgets('設定列：裝置沒有生物辨識就不出現', (tester) async {
    await pump(tester);
    bio.kind = null;
    container.invalidate(appLockKindProvider);
    await settle(tester);
    expect(find.byType(Switch), findsNothing);
  });
}
