import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/cupertino.dart';
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
import 'package:tripline/theme/tokens.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const emailFieldKey = ValueKey('login-email-field');
  const passwordFieldKey = ValueKey('login-password-field');
  const submitButtonKey = ValueKey('login-submit-button');
  const errorBannerKey = ValueKey('login-error-banner');
  const passwordToggleKey = ValueKey('login-password-visibility-toggle');

  const loggedInUser = UserInfo(id: 'u1hex', email: 'ray@example.com');

  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    // authStateProvider build() 會先查目前使用者；預設模擬未登入
    when(() => mockAuthRepository.currentUser()).thenAnswer((_) async => null);
  });

  /// 把 LoginScreen 包進簡單 GoRouter 假 route。
  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    String initialLocation = '/',
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
    TargetPlatform platform = TargetPlatform.iOS,
    bool boldText = false,
    bool highContrast = false,
    bool reduceMotion = false,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fakeRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: '/login/forgot',
          builder: (context, state) =>
              const Scaffold(body: Text('forgot-destination')),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) =>
              const Scaffold(body: Text('signup-destination')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: MaterialApp.router(
          theme:
              (brightness == Brightness.light
                      ? AppTheme.light(highContrast: highContrast)
                      : AppTheme.dark(highContrast: highContrast))
                  .copyWith(platform: platform),
          themeMode: ThemeMode.light,
          routerConfig: fakeRouter,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              textScaler: TextScaler.linear(textScale),
              platformBrightness: brightness,
              boldText: boldText,
              highContrast: highContrast,
              disableAnimations: reduceMotion,
              viewInsets: viewInsets,
            ),
            child: child!,
          ),
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

      final emailTextField = innerTextFieldOf(tester, emailFieldKey);
      expect(emailTextField.keyboardType, TextInputType.emailAddress);

      final passwordTextField = innerTextFieldOf(tester, passwordFieldKey);
      expect(passwordTextField.obscureText, isTrue);

      final context = tester.element(find.byKey(const ValueKey('auth-card')));
      final brand = tester.widget<Text>(find.text('Tripline'));
      expect(brand.style?.color, Theme.of(context).colorScheme.onSurface);
      expect(
        brand.style?.fontSize,
        Theme.of(context).textTheme.displaySmall?.fontSize,
      );
    });

    testWidgets('iOS／Android 的 Light／Dark 共用同一個 Login 結構', (tester) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await pumpLoginScreen(
            tester,
            platform: platform,
            brightness: brightness,
          );

          final context = tester.element(
            find.byKey(const ValueKey('auth-card')),
          );
          expect(Theme.of(context).platform, platform);
          expect(Theme.of(context).brightness, brightness);
          expect(
            Theme.of(context).colorScheme.surface,
            brightness == Brightness.light
                ? TpSystemColorsLight.background
                : TpSystemColorsDark.background,
          );
          expect(
            Theme.of(context).colorScheme.primary,
            brightness == Brightness.light
                ? TpSystemColorsLight.tint
                : TpSystemColorsDark.tint,
          );
          expect(find.byKey(emailFieldKey), findsOneWidget);
          expect(find.byKey(passwordFieldKey), findsOneWidget);
          expect(find.byKey(submitButtonKey), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('欄位與 controls 具正確 semantics 且至少 44×44pt', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpLoginScreen(tester);

      for (final key in [
        emailFieldKey,
        passwordFieldKey,
        passwordToggleKey,
        submitButtonKey,
      ]) {
        final finder = find.byKey(key);
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
      }
      expect(find.bySemanticsLabel('Email'), findsOneWidget);
      expect(find.bySemanticsLabel('密碼'), findsOneWidget);
      final passwordToggleSemantics = tester
          .getSemantics(find.byKey(passwordToggleKey))
          .getSemanticsData();
      expect(passwordToggleSemantics.label, contains('顯示密碼'));
      expect(passwordToggleSemantics.hasAction(SemanticsAction.tap), isTrue);
      expect(
        tester
            .getSemantics(find.byKey(submitButtonKey))
            .getSemanticsData()
            .label,
        contains('登入'),
      );

      semantics.dispose();
    });

    testWidgets('密碼顯示切換：點 suffix icon 後 obscureText 變 false', (tester) async {
      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(passwordToggleKey));
      await tester.pump();

      final passwordTextField = innerTextFieldOf(tester, passwordFieldKey);
      expect(passwordTextField.obscureText, isFalse);
    });

    testWidgets('verified query 顯示信箱已驗證提示', (tester) async {
      await pumpLoginScreen(
        tester,
        initialLocation: '/?verified=1',
        highContrast: true,
      );

      expect(
        find.byKey(const ValueKey('login-verified-banner')),
        findsOneWidget,
      );
      expect(find.text('信箱已驗證，請登入繼續。'), findsOneWidget);
      final context = tester.element(find.byKey(const ValueKey('auth-card')));
      final text = tester.widget<Text>(find.text('信箱已驗證，請登入繼續。'));
      expect(text.style?.color, Theme.of(context).colorScheme.onSurface);
      final surface = tester.widget<Container>(
        find.byKey(const ValueKey('login-verified-surface')),
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
      final semantics = tester
          .getSemantics(find.byKey(const ValueKey('login-verified-banner')))
          .getSemanticsData();
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
      expect(semantics.label, contains('成功'));
    });

    testWidgets('可從登入頁前往忘記密碼流程', (tester) async {
      await pumpLoginScreen(tester);

      final forgotLink = find.byKey(
        const ValueKey('login-forgot-password-link'),
      );
      await tester.ensureVisible(forgotLink);
      await tester.tap(forgotLink);
      await tester.pumpAndSettle();

      expect(find.text('forgot-destination'), findsOneWidget);
    });

    testWidgets('可從登入頁前往建立帳號流程', (tester) async {
      await pumpLoginScreen(tester);

      final signupLink = find.byKey(const ValueKey('login-signup-link'));
      await tester.ensureVisible(signupLink);
      await tester.tap(signupLink);
      await tester.pumpAndSettle();

      expect(find.text('signup-destination'), findsOneWidget);
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
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(submitButtonKey),
          matching: find.text('登入中'),
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

    testWidgets('鍵盤 Next 移到密碼，Done 送出既有 login contract', (tester) async {
      when(
        () => mockAuthRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => loggedInUser);
      await pumpLoginScreen(tester);

      await tester.enterText(find.byKey(emailFieldKey), 'ray@example.com');
      await tester.tap(find.byKey(emailFieldKey));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final passwordEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(passwordFieldKey),
          matching: find.byType(EditableText),
        ),
      );
      expect(passwordEditable.focusNode.hasFocus, isTrue);

      await tester.enterText(find.byKey(passwordFieldKey), 'secret');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(
        () => mockAuthRepository.login(
          email: 'ray@example.com',
          password: 'secret',
        ),
      ).called(1);
    });
  });

  testWidgets('Accessibility Size、Bold Text、提高對比、Reduce Motion 與鍵盤不裁切', (
    tester,
  ) async {
    await pumpLoginScreen(
      tester,
      textScale: 3.2,
      boldText: true,
      highContrast: true,
      reduceMotion: true,
      viewInsets: const EdgeInsets.only(bottom: 320),
    );

    final signupLink = find.byKey(const ValueKey('login-signup-link'));
    await tester.ensureVisible(signupLink);
    await tester.pumpAndSettle();

    final tagline = find.text('把每段旅程，安排得剛剛好');
    final richTagline = tester.widget<RichText>(
      find.descendant(of: tagline, matching: find.byType(RichText)),
    );
    expect(
      richTagline.text.style?.fontWeight?.value,
      greaterThan(AppTheme.light().textTheme.bodyLarge!.fontWeight!.value),
    );
    final context = tester.element(find.byKey(const ValueKey('auth-card')));
    expect(TpMotion.resolve(context, TpMotion.normal), Duration.zero);
    expect(
      Theme.of(context).colorScheme.outlineVariant,
      const Color(0xFF3C3C43),
    );
    expect(Theme.of(context).colorScheme.surface.a, 1);
    expect(tester.takeException(), isNull);
    expect(tester.getBottomRight(signupLink).dy, lessThanOrEqualTo(844));
  });

  testWidgets('320pt compact 與 regular width 都可完成登入流程', (tester) async {
    for (final size in const [Size(320, 568), Size(1024, 768)]) {
      await pumpLoginScreen(tester, size: size);

      final signupLink = find.byKey(const ValueKey('login-signup-link'));
      await tester.ensureVisible(signupLink);
      await tester.pumpAndSettle();

      expect(find.byKey(emailFieldKey), findsOneWidget);
      expect(find.byKey(passwordFieldKey), findsOneWidget);
      expect(find.byKey(submitButtonKey), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  group('錯誤顯示', () {
    testWidgets('首次載入目前使用者失敗時不誤顯示登入失敗', (tester) async {
      when(
        () => mockAuthRepository.currentUser(),
      ).thenAnswer((_) async => throw Exception('network unavailable'));

      await pumpLoginScreen(tester);

      expect(find.byKey(errorBannerKey), findsNothing);
    });

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
      final semantics = tester.getSemantics(find.byKey(errorBannerKey));
      expect(semantics.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
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

  group('autofill(iOS Keychain / QuickType)', () {
    testWidgets('email/密碼欄位設定 autofillHints 並包在 AutofillGroup', (tester) async {
      await pumpLoginScreen(tester);

      // 整個表單包在 AutofillGroup 內,iOS 才會把 email + 密碼視為同一組憑證。
      expect(find.byType(AutofillGroup), findsOneWidget);

      final emailField = innerTextFieldOf(tester, emailFieldKey);
      expect(emailField.autofillHints, contains(AutofillHints.username));

      final passwordField = innerTextFieldOf(tester, passwordFieldKey);
      expect(passwordField.autofillHints, contains(AutofillHints.password));
    });
  });
}
