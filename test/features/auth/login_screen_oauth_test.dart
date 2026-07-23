import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockOAuthLogin extends Mock implements OAuthLoginService {}

void main() {
  late _MockAuthRepo authRepo;
  late _MockOAuthLogin oauthLogin;

  setUp(() {
    authRepo = _MockAuthRepo();
    oauthLogin = _MockOAuthLogin();
    when(() => authRepo.currentUser()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester, {required bool oauthEnabled}) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const LoginScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          oauthEnabledProvider.overrideWithValue(oauthEnabled),
          oauthLoginServiceProvider.overrideWithValue(oauthLogin),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未啟用 OAuth → 無按鈕', (tester) async {
    await pump(tester, oauthEnabled: false);
    expect(find.byKey(const ValueKey('login-oauth-button')), findsNothing);
  });

  testWidgets('啟用 OAuth → 顯示按鈕,點擊呼叫 login()', (tester) async {
    when(() => oauthLogin.login()).thenAnswer(
      (_) async => OAuthTokens(
        accessToken: 'AT',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    await pump(tester, oauthEnabled: true);
    expect(find.byKey(const ValueKey('login-oauth-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('login-oauth-button')));
    await tester.pumpAndSettle();
    verify(() => oauthLogin.login()).called(1);
  });

  testWidgets('OAuth 登入中顯示 iOS progress、文字並禁止重複送出', (tester) async {
    final pending = Completer<OAuthTokens>();
    when(() => oauthLogin.login()).thenAnswer((_) => pending.future);

    await pump(tester, oauthEnabled: true);
    const buttonKey = ValueKey('login-oauth-button');
    await tester.tap(find.byKey(buttonKey));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(buttonKey),
        matching: find.byType(CupertinoActivityIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('OAuth 登入中'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(buttonKey)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('login-submit-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('login-email-field')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('login-forgot-password-link')),
          )
          .onPressed,
      isNull,
    );

    pending.complete(
      OAuthTokens(
        accessToken: 'AT',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('密碼登入中禁止啟動 OAuth', (tester) async {
    final pending = Completer<UserInfo>();
    when(
      () => authRepo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    await pump(tester, oauthEnabled: true);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'ray@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('login-oauth-button')),
          )
          .onPressed,
      isNull,
    );

    pending.complete(const UserInfo(id: 'u1', email: 'ray@example.com'));
    await tester.pumpAndSettle();
  });

  testWidgets('OAuth 登入失敗 → 顯示錯誤', (tester) async {
    when(() => oauthLogin.login()).thenThrow(OAuthLoginException('登入逾時'));

    await pump(tester, oauthEnabled: true);
    await tester.tap(find.byKey(const ValueKey('login-oauth-button')));
    await tester.pumpAndSettle();
    expect(find.text('登入逾時'), findsOneWidget);
  });
}
