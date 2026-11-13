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
import 'package:tripline/features/account/settings/forget_this_phone_row.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../../helpers/fake_biometric.dart';
import '../../helpers/fake_oauth.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockOAuthRepo extends Mock implements OAuthRepository {}

const _user = UserInfo(id: 'u1', email: 'ray@example.com');
const _row = ValueKey('settings-forget-phone');
const _entry = ValueKey('login-biometric-button');

void main() {
  late InMemoryOAuthTokenStore store;
  late InMemorySettingsStore settings;
  late InMemoryProofKeyStore keys;
  late _MockOAuthRepo oauthRepo;
  late _MockAuthRepo authRepo;

  Future<void> Function() revoke() =>
      () => oauthRepo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      );

  /// 已登入顯示帳號設定那一列，未登入顯示登入頁（模擬 router redirect）。
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool biometric,
    bool revokeFails = false,
  }) async {
    store = InMemoryOAuthTokenStore();
    settings = InMemorySettingsStore();
    keys = InMemoryProofKeyStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        tokenType: 'DPoP',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    if (biometric) await store.setProtection(TokenProtection.biometric);
    await keys.create();
    oauthRepo = _MockOAuthRepo();
    final call = when(revoke());
    revokeFails
        ? call.thenThrow(Exception('offline'))
        : call.thenAnswer((_) async {});
    authRepo = _MockAuthRepo();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          oauthTokenStoreProvider.overrideWithValue(store),
          proofKeyStoreProvider.overrideWithValue(keys),
          oauthRepositoryProvider.overrideWithValue(oauthRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(),
          ),
          settingsStoreProvider.overrideWithValue(settings),
          ...fakeBrowserLoginOverrides(),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Consumer(
                  builder: (context, ref, _) =>
                      ref.watch(authStateProvider).value == null
                      ? const LoginScreen()
                      : const Scaffold(body: ForgetThisPhoneRow()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await c.read(authStateProvider.future);
    await tester.pumpAndSettle();
    return c;
  }

  Finder inDialog(String t) => find.textContaining(t);

  testWidgets('沒開生物辨識登入：不顯示這一列', (tester) async {
    await pump(tester, biometric: false);
    expect(find.byKey(_row), findsNothing);
  });

  testWidgets('開啟後顯示；取消不改變任何狀態', (tester) async {
    final c = await pump(tester, biometric: true);
    await tester.tap(find.byKey(_row));
    await tester.pumpAndSettle();
    expect(inDialog('賣掉或借出手機前使用：會清除'), findsOneWidget);
    expect(inDialog('其他裝置'), findsOneWidget);
    expect(inDialog('瀏覽器重新登入'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(c.read(authStateProvider).value, isNotNull);
    expect(await store.read(), isNotNull);
    expect(await keys.load(), isNotNull);
    verifyNever(revoke());
  });

  testWidgets('確認：清憑證與金鑰與標記、呼叫撤銷、回登入頁且沒有 Face ID 入口', (tester) async {
    final c = await pump(tester, biometric: true);
    await store.writeKeptAccount('ray@example.com');
    await tester.tap(find.byKey(_row));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '忘記這支手機'));
    await tester.pumpAndSettle();

    expect(c.read(authStateProvider).value, isNull);
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
    expect(find.byKey(const ValueKey('login-browser-button')), findsOneWidget);
    expect(find.byKey(_entry), findsNothing);
    expect(find.textContaining('伺服器端尚未撤銷'), findsNothing);
  });

  testWidgets('撤銷失敗：仍清掉本機並提示到網頁版確認，不卡住', (tester) async {
    final c = await pump(tester, biometric: true, revokeFails: true);
    await tester.tap(find.byKey(_row));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '忘記這支手機'));
    await tester.pumpAndSettle();

    expect(c.read(authStateProvider).value, isNull);
    expect(await store.read(), isNull);
    expect(await keys.load(), isNull);
    expect(find.byKey(_entry), findsNothing);
    expect(find.textContaining('伺服器端尚未撤銷，請到網頁版已登入裝置確認'), findsOneWidget);
  });
}
