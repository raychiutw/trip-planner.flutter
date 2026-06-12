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
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未啟用 OAuth → 無按鈕', (tester) async {
    await pump(tester, oauthEnabled: false);
    expect(find.byKey(const ValueKey('login-oauth-button')), findsNothing);
  });

  testWidgets('啟用 OAuth → 顯示按鈕,點擊呼叫 login()', (tester) async {
    when(() => oauthLogin.login()).thenAnswer((_) async => OAuthTokens(
          accessToken: 'AT',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ));

    await pump(tester, oauthEnabled: true);
    expect(find.byKey(const ValueKey('login-oauth-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('login-oauth-button')));
    await tester.pumpAndSettle();
    verify(() => oauthLogin.login()).called(1);
  });

  testWidgets('OAuth 登入失敗 → 顯示錯誤', (tester) async {
    when(() => oauthLogin.login()).thenThrow(OAuthLoginException('登入逾時'));

    await pump(tester, oauthEnabled: true);
    await tester.tap(find.byKey(const ValueKey('login-oauth-button')));
    await tester.pumpAndSettle();
    expect(find.text('登入逾時'), findsOneWidget);
  });
}
