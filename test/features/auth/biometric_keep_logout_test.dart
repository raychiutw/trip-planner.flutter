import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/logout_confirm.dart';
import 'package:tripline/features/account/settings/biometric_login_row.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../../helpers/fake_biometric.dart';
import '../../helpers/fake_oauth.dart';

/// 計算受保護讀取次數：冷啟動不該碰它。
class _CountingStore extends InMemoryOAuthTokenStore {
  int reads = 0;

  @override
  Future<OAuthTokens?> read() {
    reads++;
    return super.read();
  }
}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockOAuthRepo extends Mock implements OAuthRepository {}

const _user = UserInfo(id: 'u1', email: 'ray@example.com');
const _entry = ValueKey('login-biometric-button');
const _account = ValueKey('login-biometric-account');
const _browser = ValueKey('login-browser-button');

void main() {
  late _CountingStore store;
  late InMemorySettingsStore settings;
  late InMemoryProofKeyStore keys;
  late _MockOAuthRepo oauthRepo;
  late _MockAuthRepo authRepo;
  late FakeBiometricAuthenticator bio;

  Widget app(Widget? home) => ProviderScope(
    key: UniqueKey(),
    overrides: [
      oauthTokenStoreProvider.overrideWithValue(store),
      proofKeyStoreProvider.overrideWithValue(keys),
      oauthRepositoryProvider.overrideWithValue(oauthRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
      biometricAuthenticatorProvider.overrideWithValue(bio),
      settingsStoreProvider.overrideWithValue(settings),
      ...fakeBrowserLoginOverrides(),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home ?? const LoginScreen()),
        ],
      ),
    ),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  /// 模擬重開 App：憑證、金鑰、偏好設定都留著，ProviderContainer 全新。
  Future<ProviderContainer> coldStart(WidgetTester tester) async {
    store.reads = 0;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(null));
    await tester.pumpAndSettle();
    final c = containerOf(tester);
    await c.read(authStateProvider.future);
    await tester.pumpAndSettle();
    return c;
  }

  /// [biometric]：登入憑證是否受生物辨識保護（＝已開啟生物辨識登入）。
  Future<ProviderContainer> pumpSignedIn(
    WidgetTester tester, {
    required bool biometric,
    Widget? home,
    BiometricKind kind = BiometricKind.faceId,
  }) async {
    store = _CountingStore();
    settings = InMemorySettingsStore();
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
    // 解鎖後會立刻 refresh 確認憑證還有效。
    when(
      () => oauthRepo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer(
      (_) async => OAuthTokens(
        accessToken: 'AT2',
        refreshToken: 'RT2',
        tokenType: 'DPoP',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    authRepo = _MockAuthRepo();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _user);
    bio = FakeBiometricAuthenticator(kind: kind);
    await tester.pumpWidget(app(home));
    await tester.pumpAndSettle();
    final container = containerOf(tester);
    expect((await container.read(authStateProvider.future)), isNotNull);
    return container;
  }

  Future<void> logout(WidgetTester tester, ProviderContainer c) async {
    await c.read(authStateProvider.notifier).logout();
    await tester.pumpAndSettle();
  }

  group('開啟生物辨識登入後登出（保留模式）', () {
    testWidgets('憑證與金鑰一起留下，不呼叫伺服器端撤銷；登入頁出現入口並標示帳號', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);

      await logout(tester, c);

      expect(c.read(authStateProvider).value, isNull);
      expect(await store.read(), isNotNull, reason: '憑證要留');
      expect(await keys.load(), isNotNull, reason: '金鑰要跟憑證一起留');
      verifyNever(
        () => oauthRepo.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
          tokenTypeHint: any(named: 'tokenTypeHint'),
        ),
      );
      expect(find.byKey(_entry), findsOneWidget);
      expect(find.text('用 Face ID 登入'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_account)).data, 'ray@example.com');
    });

    testWidgets('按入口且生物辨識通過：回到已登入', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c);

      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();

      expect(c.read(authStateProvider).value?.email, 'ray@example.com');
    });

    testWidgets('取消：留在登入頁、憑證沒被登出，可改用瀏覽器登入', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c);
      store.unlockSucceeds = false;

      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();

      expect(c.read(authStateProvider).value, isNull);
      expect(find.byKey(_entry), findsOneWidget);
      expect(find.byKey(_browser), findsOneWidget);
      expect(find.text('改用瀏覽器登入'), findsOneWidget);
      store.unlockSucceeds = true;
      expect(await store.read(), isNotNull, reason: '取消不能清掉憑證');
      expect(await keys.load(), isNotNull);
    });

    testWidgets('只有裝置密碼的手機：不顯示入口', (tester) async {
      final c = await pumpSignedIn(
        tester,
        biometric: true,
        kind: BiometricKind.passcode,
      );
      await logout(tester, c);

      expect(find.byKey(_entry), findsNothing);
      expect(find.byKey(const ValueKey('login-unlock-button')), findsNothing);
    });
  });

  group('登出後重開 App（冷啟動）', () {
    testWidgets('視為已登出：不讀憑證、不跳驗證，登入頁仍有入口與帳號', (tester) async {
      final c0 = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c0);

      final c = await coldStart(tester);

      expect(c.read(authStateProvider).value, isNull);
      expect(store.reads, 0, reason: '冷啟動不得觸發受保護讀取');
      expect(find.byKey(_entry), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_account)).data, 'ray@example.com');
      expect(await keys.load(), isNotNull);
    });

    testWidgets('按入口且通過：登入並清掉保留標記，再重開就照常自動登入', (tester) async {
      final c0 = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c0);
      final c1 = await coldStart(tester);

      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();

      expect(c1.read(authStateProvider).value?.email, 'ray@example.com');
      expect(await settings.read('bio_login_kept_account'), anyOf(isNull, ''));

      final c2 = await coldStart(tester);
      expect(c2.read(authStateProvider).value?.email, 'ray@example.com');
    });

    testWidgets('按入口但取消：仍在登入頁，標記與憑證都還在', (tester) async {
      final c0 = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c0);
      final c1 = await coldStart(tester);
      store.unlockSucceeds = false;

      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();

      expect(c1.read(authStateProvider).value, isNull);
      expect(find.byKey(_entry), findsOneWidget);
      expect(await settings.read('bio_login_kept_account'), 'ray@example.com');
      store.unlockSucceeds = true;
      expect(await store.read(), isNotNull);
      expect(await keys.load(), isNotNull);
    });

    testWidgets('沒有保留標記：冷啟動照常自動登入', (tester) async {
      await pumpSignedIn(tester, biometric: true);

      final c = await coldStart(tester);

      expect(c.read(authStateProvider).value?.email, 'ray@example.com');
    });
  });

  group('未開啟生物辨識登入者登出', () {
    testWidgets('憑證與金鑰被清掉、仍撤銷、登入頁沒有入口', (tester) async {
      final c = await pumpSignedIn(tester, biometric: false);

      await logout(tester, c);

      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
      verify(
        () => oauthRepo.revokeToken(
          token: 'RT',
          clientId: OAuthConfig.clientId,
          tokenTypeHint: 'refresh_token',
        ),
      ).called(1);
      expect(find.byKey(_entry), findsNothing);
    });
  });

  group('帳號設定關閉生物辨識登入', () {
    testWidgets('仍是清掉憑證與金鑰並登出，登入頁沒有入口', (tester) async {
      final c = await pumpSignedIn(
        tester,
        biometric: true,
        home: const Scaffold(body: BiometricLoginRow()),
      );

      await tester.tap(find.byKey(const ValueKey('settings-biometric-login')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bio-disable-confirm')));
      await tester.pumpAndSettle();

      expect(c.read(authStateProvider).value, isNull);
      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
      expect(c.read(keptBiometricAccountProvider).value, isNull);
    });
  });

  group('登出確認的說明文字', () {
    Future<void> openConfirm(
      WidgetTester tester, {
      required bool biometric,
    }) async {
      await pumpSignedIn(
        tester,
        biometric: biometric,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => confirmLogout(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('開啟者：誠實寫明這支手機仍可用 Face ID 登入', (tester) async {
      await openConfirm(tester, biometric: true);

      expect(
        find.textContaining('這支手機仍可用 Face ID 登入，要完全清除請選忘記這支手機'),
        findsOneWidget,
      );
    });

    testWidgets('未開啟者：文字不變', (tester) async {
      await openConfirm(tester, biometric: false);

      expect(find.text('確定要登出嗎？'), findsOneWidget);
      expect(find.textContaining('忘記這支手機'), findsNothing);
    });
  });
}
