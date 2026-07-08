import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const emailFieldKey = ValueKey('login-email-field');
  const passwordFieldKey = ValueKey('login-password-field');
  const submitButtonKey = ValueKey('login-submit-button');
  const errorBannerKey = ValueKey('login-error-banner');
  const passwordToggleKey = ValueKey('login-password-visibility-toggle');
  const signupLinkKey = ValueKey('login-signup-link');
  const forgotLinkKey = ValueKey('login-forgot-link');

  const loggedInUser = UserInfo(id: 'u1hex', email: 'ray@example.com');

  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    // authStateProvider build() 會先查目前使用者；預設模擬未登入
    when(() => mockAuthRepository.currentUser()).thenAnswer((_) async => null);
  });

  /// 把 LoginScreen 包進簡單 GoRouter 假 route（導航目的地不在此驗證）。
  Future<void> pumpLoginScreen(WidgetTester tester) async {
    final fakeRouter = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: '/signup',
          builder: (context, state) =>
              const Scaffold(body: Text('signup-probe')),
        ),
        GoRoute(
          path: '/login/forgot',
          builder: (context, state) =>
              const Scaffold(body: Text('forgot-probe')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: fakeRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextField innerTextFieldOf(WidgetTester tester, Key fieldKey) {
    return tester.widget<TextField>(
      find.descendant(
        of: find.byKey(fieldKey),
        matching: find.byType(TextField),
      ),
    );
  }

  group('渲染', () {
    testWidgets('品牌區、email 欄位、密碼欄位、登入按鈕存在', (tester) async {
      await pumpLoginScreen(tester);

      expect(find.text('Tripline'), findsOneWidget);
      expect(find.byKey(emailFieldKey), findsOneWidget);
      expect(find.byKey(passwordFieldKey), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '登入'), findsOneWidget);
      expect(find.byKey(signupLinkKey), findsOneWidget);
      expect(find.byKey(forgotLinkKey), findsOneWidget);

      final emailTextField = innerTextFieldOf(tester, emailFieldKey);
      expect(emailTextField.keyboardType, TextInputType.emailAddress);

      final passwordTextField = innerTextFieldOf(tester, passwordFieldKey);
      expect(passwordTextField.obscureText, isTrue);
    });

    testWidgets('密碼顯示切換：點 suffix icon 後 obscureText 變 false', (tester) async {
      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(passwordToggleKey));
      await tester.pump();

      final passwordTextField = innerTextFieldOf(tester, passwordFieldKey);
      expect(passwordTextField.obscureText, isFalse);
    });

    testWidgets('可前往註冊與忘記密碼流程', (tester) async {
      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(signupLinkKey));
      await tester.pumpAndSettle();
      expect(find.text('signup-probe'), findsOneWidget);

      await pumpLoginScreen(tester);
      await tester.tap(find.byKey(forgotLinkKey));
      await tester.pumpAndSettle();
      expect(find.text('forgot-probe'), findsOneWidget);
    });
  });

  group('前端驗證', () {
    testWidgets('空值 submit：顯示提示且不呼叫 login', (tester) async {
      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(submitButtonKey));
      await tester.pump();

      expect(find.text('請輸入 Email'), findsOneWidget);
      expect(find.text('請輸入密碼'), findsOneWidget);
      verifyNever(
        () => mockAuthRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });
  });

  group('submit 行為', () {
    testWidgets('以正確參數呼叫 login', (tester) async {
      when(
        () => mockAuthRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => loggedInUser);
      await pumpLoginScreen(tester);

      await tester.enterText(find.byKey(emailFieldKey), 'ray@example.com');
      await tester.enterText(find.byKey(passwordFieldKey), 'secret');
      await tester.tap(find.byKey(submitButtonKey));
      await tester.pumpAndSettle();

      verify(
        () => mockAuthRepository.login(
          email: 'ray@example.com',
          password: 'secret',
        ),
      ).called(1);
    });

    testWidgets('進行中按鈕 loading 且禁止重複 submit', (tester) async {
      final pendingLogin = Completer<UserInfo>();
      when(
        () => mockAuthRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => pendingLogin.future);
      await pumpLoginScreen(tester);

      await tester.enterText(find.byKey(emailFieldKey), 'ray@example.com');
      await tester.enterText(find.byKey(passwordFieldKey), 'secret');
      await tester.tap(find.byKey(submitButtonKey));
      await tester.pump();

      // loading 指示 + 按鈕禁用
      expect(
        find.descendant(
          of: find.byKey(submitButtonKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final submitButton = tester.widget<FilledButton>(
        find.byKey(submitButtonKey),
      );
      expect(submitButton.onPressed, isNull);

      // 再點一次不會重複呼叫
      await tester.tap(find.byKey(submitButtonKey), warnIfMissed: false);
      await tester.pump();
      verify(
        () => mockAuthRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).called(1);

      pendingLogin.complete(loggedInUser);
      await tester.pumpAndSettle();
    });
  });

  group('錯誤顯示', () {
    testWidgets('登入失敗：表單上方 destructive 色塊顯示 ApiError.message', (tester) async {
      when(
        () => mockAuthRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => throw const ApiError(
          status: 401,
          code: 'LOGIN_INVALID',
          message: '帳號或密碼錯誤',
        ),
      );
      await pumpLoginScreen(tester);

      await tester.enterText(find.byKey(emailFieldKey), 'ray@example.com');
      await tester.enterText(find.byKey(passwordFieldKey), 'wrong');
      await tester.tap(find.byKey(submitButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(errorBannerKey), findsOneWidget);
      expect(find.text('帳號或密碼錯誤'), findsOneWidget);
    });

    testWidgets('LOGIN_RATE_LIMITED 英文 message：改用繁中人話 fallback', (
      tester,
    ) async {
      when(
        () => mockAuthRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => throw const ApiError(
          status: 429,
          code: 'LOGIN_RATE_LIMITED',
          message: 'Too many login attempts',
        ),
      );
      await pumpLoginScreen(tester);

      await tester.enterText(find.byKey(emailFieldKey), 'ray@example.com');
      await tester.enterText(find.byKey(passwordFieldKey), 'secret');
      await tester.tap(find.byKey(submitButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(errorBannerKey), findsOneWidget);
      expect(find.text('登入嘗試次數過多，請稍後再試'), findsOneWidget);
    });
  });
}
