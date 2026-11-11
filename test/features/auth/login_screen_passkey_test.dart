import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/passkey_login.dart';
import 'package:tripline/app/passkey_platform.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

import '../../helpers/fake_biometric.dart';
import '../../helpers/fake_oauth.dart';
import '../../helpers/fake_passkey_platform.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// 假的 passkey 登入：不碰原生層，成功時把憑證交給憑證來源。
class _FakePasskeyLogin implements PasskeyLoginService {
  _FakePasskeyLogin(this._ref, this.error);

  final Ref _ref;
  final Object? error;
  static int calls = 0;

  @override
  Future<OAuthTokens> login() async {
    calls++;
    if (error != null) throw error!;
    final tokens = OAuthTokens(
      accessToken: 'AT',
      refreshToken: 'RT',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    await _ref.read(bearerTokenSourceProvider).adopt(tokens);
    return tokens;
  }
}

void main() {
  const passkeyKey = ValueKey('login-passkey-button');
  const browserKey = ValueKey('login-browser-button');
  const unlockKey = ValueKey('login-unlock-button');
  const bannerKey = ValueKey('login-error-banner');
  const user = UserInfo(id: 'u1hex', email: 'ray@example.com');

  late _MockAuthRepository authRepo;
  late InMemorySettingsStore settings;
  late FakePasskeyPlatform platform;
  var browserLogins = 0;

  setUp(() {
    authRepo = _MockAuthRepository();
    settings = InMemorySettingsStore();
    platform = FakePasskeyPlatform();
    _FakePasskeyLogin.calls = 0;
    browserLogins = 0;
    when(() => authRepo.currentUser()).thenAnswer((_) async => null);
  });

  Future<void> pump(
    WidgetTester tester, {
    bool flag = true,
    bool supported = true,
    Object? passkeyError,
    bool signedIn = false,
  }) async {
    if (flag) await settings.write(kPasskeyLoginHintKey, '1');
    platform.supported = supported;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, _) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(),
          ),
          settingsStoreProvider.overrideWithValue(settings),
          passkeyPlatformProvider.overrideWithValue(platform),
          passkeyLoginServiceProvider.overrideWith(
            (ref) => _FakePasskeyLogin(ref, passkeyError),
          ),
          if (signedIn)
            ...signedInOverrides(), // 含不連網的 OAuthRepository，登出不會真的撤銷
          ...fakeBrowserLoginOverrides(onLogin: () => browserLogins++),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LoginScreen)));

  testWidgets('有旗標且平台支援：顯示「使用 Face ID 登入」，瀏覽器登入仍在', (tester) async {
    await pump(tester);

    expect(find.byKey(passkeyKey), findsOneWidget);
    expect(find.text('使用 Face ID 登入'), findsOneWidget);
    expect(find.byKey(browserKey), findsOneWidget);
    expect(find.byKey(unlockKey), findsNothing);
  });

  testWidgets('沒有旗標：不顯示', (tester) async {
    await pump(tester, flag: false);

    expect(find.byKey(passkeyKey), findsNothing);
    expect(find.text('使用瀏覽器登入'), findsOneWidget);
  });

  testWidgets('平台不支援 passkey：不顯示', (tester) async {
    await pump(tester, supported: false);

    expect(find.byKey(passkeyKey), findsNothing);
    expect(find.text('使用瀏覽器登入'), findsOneWidget);
  });

  testWidgets('登出後仍顯示：旗標在已登入時也存在，登出回到登入頁入口還在', (tester) async {
    await pump(tester, signedIn: true);
    when(() => authRepo.currentUser()).thenAnswer((_) async => user);
    final container = containerOf(tester);

    await container.read(authStateProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.byKey(passkeyKey), findsOneWidget);
    expect(await settings.read(kPasskeyLoginHintKey), '1');
  });

  testWidgets('成功：走 passkey 登入並解析出身分', (tester) async {
    when(() => authRepo.currentUser()).thenAnswer((_) async => user);
    await pump(tester);

    await tester.tap(find.byKey(passkeyKey));
    await tester.pumpAndSettle();

    expect(_FakePasskeyLogin.calls, 1);
    expect(containerOf(tester).read(authStateProvider).value, user);
  });

  testWidgets('失敗：留在登入頁、顯示訊息，入口與旗標保留，仍可用瀏覽器登入', (tester) async {
    await pump(
      tester,
      passkeyError: OAuthLoginException(
        'x',
        userMessage: '無法用 passkey 登入，請改用瀏覽器登入',
      ),
    );

    await tester.tap(find.byKey(passkeyKey));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(bannerKey),
        matching: find.text('無法用 passkey 登入，請改用瀏覽器登入'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(passkeyKey), findsOneWidget);
    expect(await settings.read(kPasskeyLoginHintKey), '1');
    expect(containerOf(tester).read(authStateProvider).value, isNull);

    await tester.tap(find.byKey(browserKey));
    await tester.pumpAndSettle();
    expect(browserLogins, 1);
  });

  testWidgets('取消：留在登入頁，不顯示錯誤，入口與旗標保留', (tester) async {
    await pump(
      tester,
      passkeyError: OAuthLoginException('cancel', cancelled: true),
    );

    await tester.tap(find.byKey(passkeyKey));
    await tester.pumpAndSettle();

    expect(find.byKey(bannerKey), findsNothing);
    expect(find.byKey(passkeyKey), findsOneWidget);
    expect(await settings.read(kPasskeyLoginHintKey), '1');
  });

  testWidgets('瀏覽器登入不受影響：照舊呼叫瀏覽器流程，不碰 passkey', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(browserKey));
    await tester.pumpAndSettle();

    expect(browserLogins, 1);
    expect(_FakePasskeyLogin.calls, 0);
  });
}
