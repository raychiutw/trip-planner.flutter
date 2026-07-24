import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/auth/account_flow_screens.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  Future<void> pumpAuthRoutes(
    WidgetTester tester, {
    required String initialLocation,
  }) async {
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
            email: state.uri.queryParameters['email'] ?? '',
            invitationError: state.uri.queryParameters['invitationError'],
          ),
        ),
        GoRoute(
          path: '/login/forgot',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/auth/password/reset',
          builder: (context, state) => ResetPasswordScreen(
            token: state.uri.queryParameters['token'] ?? '',
          ),
        ),
        GoRoute(
          path: '/auth/verify-email',
          builder: (context, state) => VerifyEmailScreen(
            token: state.uri.queryParameters['token'] ?? '',
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('login-destination')),
        ),
        GoRoute(
          path: '/trips',
          builder: (context, state) => Scaffold(
            body: Text('trips:${state.uri.queryParameters['selected'] ?? ''}'),
          ),
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
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('註冊會帶 invitation token 並導向驗證信等待頁', (tester) async {
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).thenAnswer(
      (_) async => const SignupResult(
        userId: 'user-1',
        email: 'ray@example.com',
        requiresVerification: true,
      ),
    );
    when(
      () => mockAuthRepository.sendVerificationEmail(any()),
    ).thenAnswer((_) async => 'sent');
    await pumpAuthRoutes(tester, initialLocation: '/signup?invitation=inv-1');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      ' ray@example.com ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-display-name-field')),
      'Ray',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-privacy-consent-checkbox')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.signup(
        email: 'ray@example.com',
        password: 'password123',
        privacyConsent: true,
        displayName: 'Ray',
        invitationToken: 'inv-1',
      ),
    ).called(1);
    verify(
      () => mockAuthRepository.sendVerificationEmail('ray@example.com'),
    ).called(1);
    expect(find.byKey(const ValueKey('verify-pending-page')), findsOneWidget);
    expect(find.text('ray@example.com'), findsOneWidget);
  });

  testWidgets('Auth 流程使用 inline Header、返回鍵且不顯示 Account', (tester) async {
    for (final (location, title) in [
      ('/signup', '建立帳號'),
      ('/signup/check-email?email=traveler%40example.com', '查看你的信箱'),
      ('/login/forgot', '重設密碼'),
      ('/auth/password/reset?token=reset-token', '設定新密碼'),
      ('/auth/verify-email?token=verify-token', '確認信箱驗證'),
    ]) {
      await pumpAuthRoutes(tester, initialLocation: location);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tp-app-bar-title')),
          matching: find.text(title),
        ),
        findsOneWidget,
        reason: location,
      );
      expect(
        find.byKey(const ValueKey('tp-app-bar-back')),
        findsOneWidget,
        reason: location,
      );
      expect(
        find.byKey(const ValueKey('account-avatar-button')),
        findsNothing,
        reason: location,
      );
    }
  });

  testWidgets('Auth 表單主要動作使用 Header trailing text action', (tester) async {
    for (final (location, actionKey) in [
      ('/signup', 'signup-submit-button'),
      (
        '/signup/check-email?email=traveler%40example.com',
        'verify-pending-resend-button',
      ),
      ('/login/forgot', 'forgot-password-submit-button'),
      (
        '/auth/password/reset?token=reset-token',
        'reset-password-submit-button',
      ),
      ('/auth/verify-email?token=verify-token', 'verify-email-confirm-button'),
    ]) {
      await pumpAuthRoutes(tester, initialLocation: location);

      expect(
        find.descendant(
          of: find.byType(TpAppBar),
          matching: find.byKey(ValueKey(actionKey)),
        ),
        findsOneWidget,
        reason: location,
      );
    }
  });

  testWidgets('Auth Header 返回會回到既有 Login 入口', (tester) async {
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();

    expect(find.text('login-destination'), findsOneWidget);
  });

  testWidgets('Auth 表單在 320pt Accessibility Size 可捲動完成', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await pumpAuthRoutes(tester, initialLocation: '/signup');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('signup-privacy-consent-checkbox')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('tp-app-bar-back'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('註冊 submitting 時防止重複送出', (tester) async {
    final pending = Completer<SignupResult>();
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).thenAnswer((_) => pending.future);
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'traveler@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-privacy-consent-checkbox')),
    );
    final submit = find.byKey(const ValueKey('signup-submit-button'));
    await tester.tap(submit);
    await tester.tap(submit);

    verify(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).called(1);

    pending.complete(
      const SignupResult(
        userId: 'user-1',
        email: 'traveler@example.com',
        requiresVerification: true,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('註冊密碼有持續規則說明與顯示切換', (tester) async {
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    expect(find.text('至少 8 個字元'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('signup-privacy-policy-link')),
      findsOneWidget,
    );
    final fieldFinder = find.byKey(const ValueKey('signup-password-field'));
    TextField textField() => tester.widget<TextField>(
      find.descendant(of: fieldFinder, matching: find.byType(TextField)),
    );
    expect(textField().obscureText, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('signup-password-visibility-toggle')),
    );
    await tester.pump();

    expect(textField().obscureText, isFalse);
  });

  testWidgets('未同意個資條款不呼叫建立帳號', (tester) async {
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'traveler@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pump();

    expect(find.text('請先閱讀並同意個資條款'), findsOneWidget);
    verifyNever(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    );
  });

  testWidgets('建立帳號失敗後保留個資條款同意狀態', (tester) async {
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).thenThrow(Exception('network'));
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'traveler@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    final consent = find.byKey(
      const ValueKey('signup-privacy-consent-checkbox'),
    );
    await tester.tap(consent);
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    expect(tester.widget<CheckboxListTile>(consent).value, isTrue);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('signup-email-field')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'traveler@example.com',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('signup-password-field')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'password123',
    );
    final error = find.byKey(const ValueKey('signup-error-banner'));
    expect(error, findsOneWidget);
    expect(
      tester
          .getSemantics(error)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });

  testWidgets('後端拒絕個資同意時在勾選框旁顯示錯誤', (tester) async {
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).thenThrow(
      const ApiError(
        status: 400,
        code: 'SIGNUP_CONSENT_REQUIRED',
        message: 'consent required',
      ),
    );
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'traveler@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-privacy-consent-checkbox')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('請先閱讀並同意個資條款'), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-error-banner')), findsNothing);
  });

  testWidgets('後端拒絕 email 時在 email 欄位顯示 inline 錯誤', (tester) async {
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).thenThrow(
      const ApiError(
        status: 400,
        code: 'SIGNUP_INVALID_EMAIL',
        message: 'invalid email',
      ),
    );
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'invalid@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-privacy-consent-checkbox')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('電子郵件格式無效'), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-error-banner')), findsNothing);
  });

  testWidgets('註冊限流提示 Retry-After 秒數', (tester) async {
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).thenThrow(
      const ApiError(
        status: 429,
        code: 'SIGNUP_RATE_LIMITED',
        message: 'too many requests',
        retryAfterSeconds: 42,
      ),
    );
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'traveler@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-privacy-consent-checkbox')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('註冊請求過多，請在 42 秒後再試'), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-error-banner')), findsOneWidget);
  });

  testWidgets('註冊若已加入行程會導向行程清單 selected trip', (tester) async {
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
        privacyConsent: any(named: 'privacyConsent'),
        displayName: any(named: 'displayName'),
        invitationToken: any(named: 'invitationToken'),
      ),
    ).thenAnswer(
      (_) async => const SignupResult(
        userId: 'user-1',
        email: 'traveler@example.com',
        requiresVerification: false,
        joinedTrip: SignupJoinedTrip(id: 'trip-1', title: '沖繩'),
      ),
    );
    when(
      () => mockAuthRepository.sendVerificationEmail(any()),
    ).thenAnswer((_) async => null);
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-field')),
      'traveler@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-privacy-consent-checkbox')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('trips:trip-1'), findsOneWidget);
  });

  testWidgets('驗證信等待頁可重寄驗證信', (tester) async {
    when(
      () => mockAuthRepository.sendVerificationEmail(any()),
    ).thenAnswer((_) async => '驗證信已重新寄出');
    await pumpAuthRoutes(
      tester,
      initialLocation: '/signup/check-email?email=traveler@example.com',
    );

    await tester.tap(
      find.byKey(const ValueKey('verify-pending-resend-button')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.sendVerificationEmail('traveler@example.com'),
    ).called(1);
    expect(
      find.byKey(const ValueKey('verify-pending-message')),
      findsOneWidget,
    );
    expect(find.text('驗證信已重新寄出'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('verify-pending-message')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });

  testWidgets('重寄驗證信時防止重複送出', (tester) async {
    final pending = Completer<String?>();
    when(
      () => mockAuthRepository.sendVerificationEmail(any()),
    ).thenAnswer((_) => pending.future);
    await pumpAuthRoutes(
      tester,
      initialLocation: '/signup/check-email?email=traveler@example.com',
    );

    final submit = find.byKey(const ValueKey('verify-pending-resend-button'));
    await tester.tap(submit);
    await tester.tap(submit);

    verify(
      () => mockAuthRepository.sendVerificationEmail('traveler@example.com'),
    ).called(1);

    pending.complete('驗證信已重新寄出');
    await tester.pumpAndSettle();
  });

  testWidgets('忘記密碼會送出 reset request 並顯示成功狀態', (tester) async {
    when(
      () => mockAuthRepository.requestPasswordReset(any()),
    ).thenAnswer((_) async => null);
    await pumpAuthRoutes(tester, initialLocation: '/login/forgot');

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      'traveler@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.requestPasswordReset('traveler@example.com'),
    ).called(1);
    expect(
      find.byKey(const ValueKey('forgot-password-success')),
      findsOneWidget,
    );
  });

  testWidgets('忘記密碼 submitting 時防止重複送出', (tester) async {
    final pending = Completer<String?>();
    when(
      () => mockAuthRepository.requestPasswordReset(any()),
    ).thenAnswer((_) => pending.future);
    await pumpAuthRoutes(tester, initialLocation: '/login/forgot');

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      'traveler@example.com',
    );
    final submit = find.byKey(const ValueKey('forgot-password-submit-button'));
    await tester.tap(submit);
    await tester.tap(submit);

    verify(
      () => mockAuthRepository.requestPasswordReset('traveler@example.com'),
    ).called(1);

    pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('忘記密碼失敗時保留 Email 並顯示持續錯誤', (tester) async {
    when(
      () => mockAuthRepository.requestPasswordReset(any()),
    ).thenThrow(Exception('offline'));
    await pumpAuthRoutes(tester, initialLocation: '/login/forgot');

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      'traveler@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey('forgot-password-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('forgot-password-email-field')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'traveler@example.com',
    );
    final error = find.byKey(const ValueKey('forgot-password-error'));
    expect(error, findsOneWidget);
    expect(
      tester
          .getSemantics(error)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });

  testWidgets('重設密碼會驗證兩次輸入並呼叫 resetPassword', (tester) async {
    when(
      () => mockAuthRepository.resetPassword(
        token: any(named: 'token'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => null);
    await pumpAuthRoutes(
      tester,
      initialLocation: '/auth/password/reset?token=reset-token',
    );

    await tester.enterText(
      find.byKey(const ValueKey('reset-password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password-confirm-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('reset-password-submit-button')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.resetPassword(
        token: 'reset-token',
        password: 'password123',
      ),
    ).called(1);
    expect(
      find.byKey(const ValueKey('reset-password-success')),
      findsOneWidget,
    );
  });

  testWidgets('重設密碼 submitting 時防止重複送出', (tester) async {
    final pending = Completer<String?>();
    when(
      () => mockAuthRepository.resetPassword(
        token: any(named: 'token'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    await pumpAuthRoutes(
      tester,
      initialLocation: '/auth/password/reset?token=reset-token',
    );

    await tester.enterText(
      find.byKey(const ValueKey('reset-password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password-confirm-field')),
      'password123',
    );
    final submit = find.byKey(const ValueKey('reset-password-submit-button'));
    await tester.tap(submit);
    await tester.tap(submit);

    verify(
      () => mockAuthRepository.resetPassword(
        token: 'reset-token',
        password: 'password123',
      ),
    ).called(1);

    pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('重設密碼被後端拒絕時保留輸入並在密碼欄位顯示錯誤', (tester) async {
    when(
      () => mockAuthRepository.resetPassword(
        token: any(named: 'token'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      const ApiError(
        status: 400,
        code: 'RESET_INVALID_PASSWORD',
        message: 'invalid password',
      ),
    );
    await pumpAuthRoutes(
      tester,
      initialLocation: '/auth/password/reset?token=reset-token',
    );

    await tester.enterText(
      find.byKey(const ValueKey('reset-password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password-confirm-field')),
      'password123',
    );
    await tester.tap(
      find.byKey(const ValueKey('reset-password-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reset-password-field')),
        matching: find.text('密碼至少 8 字元'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reset-password-error')), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('reset-password-field')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'password123',
    );
  });

  testWidgets('email 驗證需使用者按鈕觸發並顯示成功狀態', (tester) async {
    when(
      () => mockAuthRepository.verifyEmail(any()),
    ).thenAnswer((_) async => true);
    await pumpAuthRoutes(
      tester,
      initialLocation: '/auth/verify-email?token=verify-token',
    );

    verifyNever(() => mockAuthRepository.verifyEmail(any()));

    await tester.tap(find.byKey(const ValueKey('verify-email-confirm-button')));
    await tester.pumpAndSettle();

    verify(() => mockAuthRepository.verifyEmail('verify-token')).called(1);
    expect(find.byKey(const ValueKey('verify-email-success')), findsOneWidget);
  });

  testWidgets('email 驗證 submitting 時防止重複送出', (tester) async {
    final pending = Completer<bool>();
    when(
      () => mockAuthRepository.verifyEmail(any()),
    ).thenAnswer((_) => pending.future);
    await pumpAuthRoutes(
      tester,
      initialLocation: '/auth/verify-email?token=verify-token',
    );

    final submit = find.byKey(const ValueKey('verify-email-confirm-button'));
    await tester.tap(submit);
    await tester.tap(submit);

    verify(() => mockAuthRepository.verifyEmail('verify-token')).called(1);

    pending.complete(true);
    await tester.pumpAndSettle();
  });
}
