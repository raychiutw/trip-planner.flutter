import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/auth/account_flow_screens.dart';
import 'package:tripline/theme/app_theme.dart';

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
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.signup(
        email: 'ray@example.com',
        password: 'password123',
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

  testWidgets('註冊密碼有持續規則說明與顯示切換', (tester) async {
    await pumpAuthRoutes(tester, initialLocation: '/signup');

    expect(find.text('至少 8 個字元'), findsOneWidget);
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

  testWidgets('註冊若已加入行程會導向行程清單 selected trip', (tester) async {
    when(
      () => mockAuthRepository.signup(
        email: any(named: 'email'),
        password: any(named: 'password'),
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
}
