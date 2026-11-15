import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
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
import 'package:tripline/features/auth/welcome_route.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../../helpers/fake_biometric.dart';
import '../../helpers/fake_oauth.dart';

/// 計算受保護讀取次數：冷啟動不該碰它。
class _CountingStore extends InMemoryOAuthTokenStore {
  int reads = 0;

  /// 封存（lock）之後第一次讀取才算一次系統驗證；解開後與正式 store 一樣走快取。
  int prompts = 0;
  bool _sealed = false;

  @override
  Future<void> lock() async {
    _sealed = true;
    await super.lock();
  }

  @override
  Future<OAuthTokens?> read() {
    reads++;
    if (_sealed) {
      prompts++;
      if (unlockSucceeds) _sealed = false;
    }
    return super.read();
  }
}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockOAuthRepo extends Mock implements OAuthRepository {}

const _user = UserInfo(id: 'u1', email: 'ray@example.com');
const _hero = ValueKey('welcome-login-hero');
// 有保留憑證時歡迎頁顯示的帳號標示（同時代表 Face ID 入口存在）。
const _entry = ValueKey('welcome-kept-account');
const _account = _entry;

/// 解鎖成功時歡迎頁的進度畫面會一直留著（正式環境由 router 換頁），
/// 測試直接掛 WelcomeRoute 沒有換頁，不能 pumpAndSettle（轉圈永不停）。
Future<void> pumpAfterLogin(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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
      ...fakeBrowserLoginOverrides(stubBiometric: false),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home ?? const WelcomeRoute()),
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
      expect(tester.widget<Text>(find.byKey(_account)).data, 'ray@example.com');
    });

    testWidgets('按入口且生物辨識通過：回到已登入', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c);

      await tester.tap(find.byKey(_hero));
      await pumpAfterLogin(tester);

      expect(c.read(authStateProvider).value?.email, 'ray@example.com');
    });

    testWidgets('解鎖只觸發一次受保護讀取（系統驗證一次）', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c);
      store.prompts = 0;

      await tester.tap(find.byKey(_hero));
      await pumpAfterLogin(tester);

      expect(c.read(authStateProvider).value?.email, 'ray@example.com');
      expect(store.prompts, 1);
    });

    testWidgets('取消：留在歡迎頁、憑證沒被登出，可再按一次', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c);
      store.unlockSucceeds = false;

      await tester.tap(find.byKey(_hero));
      await pumpAfterLogin(tester);

      expect(c.read(authStateProvider).value, isNull);
      expect(find.byKey(_entry), findsOneWidget);
      expect(find.byKey(_hero), findsOneWidget);
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

      await tester.tap(find.byKey(_hero));
      await pumpAfterLogin(tester);

      expect(c1.read(authStateProvider).value?.email, 'ray@example.com');
      expect(await store.readKeptAccount(), isNull);

      final c2 = await coldStart(tester);
      expect(c2.read(authStateProvider).value?.email, 'ray@example.com');
    });

    testWidgets('按入口但取消：仍在登入頁，標記與憑證都還在', (tester) async {
      final c0 = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c0);
      final c1 = await coldStart(tester);
      store.unlockSucceeds = false;

      await tester.tap(find.byKey(_hero));
      await pumpAfterLogin(tester);

      expect(c1.read(authStateProvider).value, isNull);
      expect(find.byKey(_entry), findsOneWidget);
      expect(await store.readKeptAccount(), 'ray@example.com');
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
    bool? result;
    Future<void> openConfirm(
      WidgetTester tester, {
      required bool biometric,
      bool alwaysAsk = true,
    }) async {
      await pumpSignedIn(
        tester,
        biometric: biometric,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async => result = await confirmLogout(
                context,
                ref,
                alwaysAsk: alwaysAsk,
              ),
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

    // 說明是誠實告知「會保留」，不能因為 alwaysAsk:false 又沒有待同步變更就略過對話框。
    testWidgets('開啟者且 alwaysAsk:false、沒有待同步變更：仍顯示說明', (tester) async {
      await openConfirm(tester, biometric: true, alwaysAsk: false);

      expect(result, isNull, reason: '對話框還開著，尚未回傳');
      expect(
        find.textContaining('這支手機仍可用 Face ID 登入，要完全清除請選忘記這支手機'),
        findsOneWidget,
      );
    });

    testWidgets('未開啟者且 alwaysAsk:false、沒有待同步變更：不打擾，直接放行', (tester) async {
      await openConfirm(tester, biometric: false, alwaysAsk: false);

      expect(result, isTrue);
      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('確定要登出嗎'), findsNothing);
    });

    testWidgets('未開啟者：文字不變', (tester) async {
      await openConfirm(tester, biometric: false);

      expect(find.text('確定要登出嗎？'), findsOneWidget);
      expect(find.textContaining('忘記這支手機'), findsNothing);
    });
  });
  group('保留模式的守門', () {
    testWidgets('登出後呼叫 API 取 token 不會觸發受保護讀取或生物辨識；解鎖後恢復', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      final source = c.read(bearerTokenSourceProvider);
      expect(await source.accessToken(), isNotNull, reason: '登入中正常取用');
      await logout(tester, c);
      final reads = store.reads;

      expect(await source.accessToken(), isNull);
      expect(await source.refresh(), isFalse);

      expect(store.reads, reads, reason: '封存期間不得碰 store');

      await tester.tap(find.byKey(_hero));
      await pumpAfterLogin(tester);
      expect(await source.accessToken(), isNotNull, reason: '解鎖後恢復');
    });

    testWidgets('logout(clear: true)（切換帳號）：撤銷並清除憑證、金鑰與標記，不留給下一個人', (
      tester,
    ) async {
      final c = await pumpSignedIn(tester, biometric: true);

      await c.read(authStateProvider.notifier).logout(clear: true);
      await tester.pumpAndSettle();

      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
      expect(await store.readKeptAccount(), isNull);
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

  group('保留標記與憑證同生同滅', () {
    testWidgets('偏好設定被清掉、憑證與標記仍在：冷啟動不會自動登入回去', (tester) async {
      final c0 = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c0);
      settings = InMemorySettingsStore(); // 模擬 iOS 重裝：偏好設定沒了、Keychain 還在

      final c = await coldStart(tester);

      expect(c.read(authStateProvider).value, isNull);
      expect(store.reads, 0, reason: '不得讀憑證');
      expect(find.byKey(_entry), findsOneWidget);
    });

    testWidgets('憑證被清掉：標記一起消失，登入頁沒有入口', (tester) async {
      final c0 = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c0);
      expect(find.byKey(_entry), findsOneWidget);

      await store.clear();
      final c = await coldStart(tester);

      expect(c.read(authStateProvider).value, isNull);
      expect(await store.readKeptAccount(), isNull);
      expect(find.byKey(_entry), findsNothing);
    });
  });

  group('登入頁的「忘記這支手機」', () {
    const forget = ValueKey('welcome-forget-phone');

    testWidgets('取消：憑證、金鑰、入口都在', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c);
      expect(find.byKey(forget), findsOneWidget);

      await tester.tap(find.byKey(forget));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(await store.read(), isNotNull);
      expect(await keys.load(), isNotNull);
      expect(find.byKey(_entry), findsOneWidget);
      verifyNever(
        () => oauthRepo.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
          tokenTypeHint: any(named: 'tokenTypeHint'),
        ),
      );
    });

    testWidgets('確認：撤銷、清憑證／金鑰／標記，入口與帳號標示消失', (tester) async {
      final c = await pumpSignedIn(tester, biometric: true);
      await logout(tester, c);

      await tester.tap(find.byKey(forget));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '忘記這支手機'));
      await tester.pumpAndSettle();

      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
      expect(await store.readKeptAccount(), isNull);
      verify(
        () => oauthRepo.revokeToken(
          token: 'RT',
          clientId: OAuthConfig.clientId,
          tokenTypeHint: 'refresh_token',
        ),
      ).called(1);
      expect(find.byKey(_entry), findsNothing);
      expect(find.byKey(_account), findsNothing);
      expect(find.byKey(forget), findsNothing);
    });

    testWidgets('沒有保留的登入：不顯示', (tester) async {
      final c = await pumpSignedIn(tester, biometric: false);
      await logout(tester, c);

      expect(find.byKey(forget), findsNothing);
    });
  });
}
