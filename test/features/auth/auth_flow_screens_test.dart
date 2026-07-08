import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/auth/email_verify_pending_screen.dart';
import 'package:tripline/features/auth/forgot_password_screen.dart';
import 'package:tripline/features/auth/reset_password_screen.dart';
import 'package:tripline/features/auth/signup_screen.dart';
import 'package:tripline/features/auth/verify_email_screen.dart';
import 'package:tripline/models/auth.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  const signupPw = 'secret123';
  const inviteCode = 'invite-token';
  const resetCode = 'reset-token';
  const signupResult = SignupResult(
    ok: true,
    userId: 'user-1',
    email: 'ray@example.com',
    requiresVerification: true,
  );

  setUp(() {
    repository = _MockAuthRepository();
    when(() => repository.currentUser()).thenAnswer((_) async => null);
    when(() => repository.sendVerificationEmail(any())).thenAnswer(
      (_) async =>
          const AuthMessageResult(ok: true, message: '若帳號需要驗證，驗證信會寄至信箱'),
    );
  });

  Widget buildApp(String initialLocation) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/signup',
          builder: (context, state) => SignupScreen(
            invitationToken: state.uri.queryParameters['invitation'],
          ),
        ),
        GoRoute(
          path: '/signup/check-email',
          builder: (context, state) => EmailVerifyPendingScreen(
            email: state.uri.queryParameters['email'],
            invitationError: state.uri.queryParameters['invitationError'],
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('login-probe')),
        ),
        GoRoute(
          path: '/login/forgot',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/auth/password/reset',
          builder: (context, state) =>
              ResetPasswordScreen(token: state.uri.queryParameters['token']),
        ),
        GoRoute(
          path: '/auth/verify-email',
          builder: (context, state) =>
              VerifyEmailScreen(token: state.uri.queryParameters['token']),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) => Scaffold(
            body: Text('trip-probe-${state.pathParameters['tripId']}'),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  group('SignupScreen', () {
    testWidgets(
      '送出 email/password/displayName 與 invitation token 後前往 check-email',
      (tester) async {
        when(
          () => repository.signup(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
            invitationToken: any(named: 'invitationToken'),
          ),
        ).thenAnswer((_) async => signupResult);
        await tester.pumpWidget(buildApp('/signup?invitation=$inviteCode'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('signup-email-field')),
          'ray@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('signup-password-field')),
          signupPw,
        );
        await tester.enterText(
          find.byKey(const ValueKey('signup-display-name-field')),
          'Ray',
        );
        await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
        await tester.pumpAndSettle();

        verify(
          () => repository.signup(
            email: 'ray@example.com',
            password: signupPw,
            displayName: 'Ray',
            invitationToken: inviteCode,
          ),
        ).called(1);
        verify(
          () => repository.sendVerificationEmail('ray@example.com'),
        ).called(1);
        expect(find.text('查看你的信箱'), findsWidgets);
        expect(find.text('ray@example.com'), findsOneWidget);
      },
    );

    testWidgets('signup 若直接加入行程，成功後導向該行程', (tester) async {
      when(
        () => repository.signup(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
          invitationToken: any(named: 'invitationToken'),
        ),
      ).thenAnswer(
        (_) async => const SignupResult(
          ok: true,
          userId: 'user-1',
          email: 'ray@example.com',
          requiresVerification: true,
          joinedTrip: SignupJoinedTrip(id: 'trip-1', title: '沖繩家族旅行'),
        ),
      );
      await tester.pumpWidget(buildApp('/signup?invitation=$inviteCode'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('signup-email-field')),
        'ray@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-password-field')),
        signupPw,
      );
      await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('trip-probe-trip-1'), findsOneWidget);
    });

    testWidgets('SIGNUP_EMAIL_TAKEN 顯示 persistent banner', (tester) async {
      when(
        () => repository.signup(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
          invitationToken: any(named: 'invitationToken'),
        ),
      ).thenAnswer(
        (_) async => throw const ApiError(
          status: 409,
          code: 'SIGNUP_EMAIL_TAKEN',
          message: 'Email already exists',
        ),
      );
      await tester.pumpWidget(buildApp('/signup'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('signup-email-field')),
        'ray@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-password-field')),
        signupPw,
      );
      await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('signup-error-banner')), findsOneWidget);
      expect(find.textContaining('此 Email 已註冊'), findsOneWidget);
    });
  });

  group('EmailVerifyPendingScreen', () {
    testWidgets('顯示 email 並可重寄驗證信', (tester) async {
      await tester.pumpWidget(
        buildApp('/signup/check-email?email=ray%40example.com'),
      );
      await tester.pumpAndSettle();

      expect(find.text('查看你的信箱'), findsWidgets);
      expect(find.text('ray@example.com'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('verify-pending-resend-button')),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.sendVerificationEmail('ray@example.com'),
      ).called(1);
      expect(find.text('已重寄。請查看信箱。'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('送出 email 後顯示 anti-enumeration 成功狀態', (tester) async {
      when(() => repository.requestPasswordReset(any())).thenAnswer(
        (_) async =>
            const AuthMessageResult(ok: true, message: '若 email 已註冊，重設連結將寄至信箱'),
      );
      await tester.pumpWidget(buildApp('/login/forgot'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot-email-field')),
        'ray@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('forgot-submit-button')));
      await tester.pumpAndSettle();

      verify(
        () => repository.requestPasswordReset('ray@example.com'),
      ).called(1);
      expect(find.text('查看你的信箱'), findsWidgets);
      expect(find.textContaining('若 ray@example.com 已註冊'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('缺 token 時顯示失效連結', (tester) async {
      await tester.pumpWidget(buildApp('/auth/password/reset'));
      await tester.pumpAndSettle();

      expect(find.text('這個連結無法使用了'), findsOneWidget);
      expect(find.byKey(const ValueKey('reset-retry-button')), findsOneWidget);
    });

    testWidgets('密碼不一致不呼叫 API', (tester) async {
      await tester.pumpWidget(
        buildApp('/auth/password/reset?token=$resetCode'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('reset-password-field')),
        signupPw,
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-field')),
        'secret124',
      );
      await tester.tap(find.byKey(const ValueKey('reset-submit-button')));
      await tester.pump();

      expect(find.text('兩次輸入的密碼不一致'), findsOneWidget);
      verifyNever(
        () => repository.resetPassword(
          token: any(named: 'token'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('成功重設後顯示前往登入', (tester) async {
      when(
        () => repository.resetPassword(
          token: any(named: 'token'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async =>
            const AuthMessageResult(ok: true, message: '密碼已更新，請用新密碼登入'),
      );
      await tester.pumpWidget(
        buildApp('/auth/password/reset?token=$resetCode'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('reset-password-field')),
        signupPw,
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-field')),
        signupPw,
      );
      await tester.tap(find.byKey(const ValueKey('reset-submit-button')));
      await tester.pumpAndSettle();

      verify(
        () => repository.resetPassword(token: resetCode, password: signupPw),
      ).called(1);
      expect(find.text('密碼已更新'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reset-go-login-button')),
        findsOneWidget,
      );
    });
  });

  group('VerifyEmailScreen', () {
    testWidgets('不自動驗證；點確認後才 POST token', (tester) async {
      final verifyCompleter = Completer<void>();
      when(
        () => repository.verifyEmail(any()),
      ).thenAnswer((_) => verifyCompleter.future);
      await tester.pumpWidget(
        buildApp('/auth/verify-email?token=verify-token'),
      );
      await tester.pumpAndSettle();

      expect(find.text('點下方按鈕完成 Email 驗證。'), findsOneWidget);
      verifyNever(() => repository.verifyEmail(any()));

      await tester.tap(
        find.byKey(const ValueKey('verify-email-confirm-button')),
      );
      await tester.pump();

      verify(() => repository.verifyEmail('verify-token')).called(1);
      expect(find.text('驗證中...'), findsOneWidget);

      verifyCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text('Email 驗證成功'), findsOneWidget);
    });

    testWidgets('缺 token 顯示 missing_token 訊息', (tester) async {
      await tester.pumpWidget(buildApp('/auth/verify-email'));
      await tester.pumpAndSettle();

      expect(find.textContaining('驗證連結缺少 token'), findsOneWidget);
      verifyNever(() => repository.verifyEmail(any()));
    });
  });
}
