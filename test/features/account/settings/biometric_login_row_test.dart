import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
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
import 'package:tripline/features/account/settings/app_lock_row.dart';
import 'package:tripline/features/account/settings/biometric_login_row.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../../../helpers/fake_biometric.dart';
import '../../../helpers/fake_oauth.dart';

const _user = UserInfo(id: 'u1', email: 'a@example.com');

class _FakeAuth extends AuthNotifier {
  int logouts = 0;

  @override
  Future<UserInfo?> build() async => null;

  void signIn() => state = const AsyncData(_user);

  @override
  Future<void> logout({bool clear = false}) async {
    logouts++;
    await ref.read(oauthTokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}

/// 設定頁「使用 Face ID／Touch ID／指紋登入」開關（ADR-0019）。
void main() {
  late InMemoryOAuthTokenStore store;
  late FakeBiometricAuthenticator bio;
  late ProviderContainer container;

  _FakeAuth auth() => container.read(authStateProvider.notifier) as _FakeAuth;
  bool switchValue(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch)).value;

  /// 推幾個 frame 讓 async 讀寫跑完；沒有排程中的 frame 時 pumpAndSettle 會先返回。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    BiometricKind? kind = BiometricKind.faceId,
    BiometricKind? loginKind,
    bool biometric = false,
    Widget body = const BiometricLoginRow(),
  }) async {
    store = InMemoryOAuthTokenStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    if (biometric) await store.setProtection(TokenProtection.biometric);
    bio = FakeBiometricAuthenticator(kind: kind)..loginKindOverride = loginKind;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(_FakeAuth.new),
            settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
            biometricAuthenticatorProvider.overrideWithValue(bio),
            foregroundWaiterProvider.overrideWithValue(() async {}),
            oauthTokenStoreProvider.overrideWithValue(store),
            ...fakeBrowserLoginOverrides(stubBiometric: false),
          ],
        ),
        child: MaterialApp(
          builder: (context, child) => AppLockHost(child: child!),
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
    auth().signIn();
    await settle(tester);
  }

  testWidgets('登入後不會自動要求生物辨識驗證', (tester) async {
    await pump(tester);

    expect(bio.authenticateCalls, 0);
    expect(store.protection, TokenProtection.passcode);
  });

  testWidgets('開啟：驗證一次生物辨識就改成生物辨識保護', (tester) async {
    await pump(tester);
    expect(switchValue(tester), isFalse);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(bio.authenticateCalls, 1);
    expect(bio.biometricOnlyCalls, [true]);
    expect(store.protection, TokenProtection.biometric);
    expect(switchValue(tester), isTrue);
  });

  testWidgets('開啟時取消驗證：維持關閉', (tester) async {
    await pump(tester);
    bio.outcomes.add(BiometricOutcome.cancelled);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(store.protection, TokenProtection.passcode);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('關閉：不確認、不驗證、不登出，改回一般保存', (tester) async {
    await pump(tester, biometric: true);
    expect(switchValue(tester), isTrue);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(bio.authenticateCalls, 0);
    expect(auth().logouts, 0);
    expect(container.read(authStateProvider).value, _user);
    expect((await store.read())?.refreshToken, 'RT');
    expect(store.protection, TokenProtection.passcode);
    expect(switchValue(tester), isFalse);
  });

  group('沒有生物辨識的裝置不顯示開關', () {
    for (final kind in [null, BiometricKind.passcode]) {
      testWidgets(kind?.name ?? '什麼都沒有', (tester) async {
        await pump(tester, kind: kind);
        expect(
          find.byKey(const ValueKey('settings-biometric-login')),
          findsNothing,
        );
      });

      testWidgets('${kind?.name ?? '什麼都沒有'}，即使先前開啟過', (tester) async {
        await pump(tester, kind: kind, biometric: true);
        expect(
          find.byKey(const ValueKey('settings-biometric-login')),
          findsNothing,
        );
      });
    }

    // Android 只有 weak 生物辨識：生物辨識登入不提供（只接受 STRONG），App 鎖照常可用。
    testWidgets('Android 只有 weak：不顯示生物辨識登入，App 鎖仍以生物辨識顯示', (tester) async {
      await pump(
        tester,
        kind: BiometricKind.biometric,
        loginKind: BiometricKind.passcode,
        body: const Column(children: [BiometricLoginRow(), AppLockRow()]),
      );
      expect(
        find.byKey(const ValueKey('settings-biometric-login')),
        findsNothing,
      );
      expect(find.text('生物辨識 解鎖'), findsOneWidget);
    });

    testWidgets('對照：有 Face ID 時顯示', (tester) async {
      await pump(tester);
      expect(
        find.byKey(const ValueKey('settings-biometric-login')),
        findsOneWidget,
      );
      expect(find.text('Face ID 登入'), findsOneWidget);
    });
  });
}
