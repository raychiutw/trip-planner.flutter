import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

import '../../helpers/contrast.dart';
import '../../helpers/fake_biometric.dart';
import '../../helpers/fake_oauth.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// 受保護的憑證還沒解鎖：讀取會丟鎖定例外。
class _LockedTokenStore extends InMemoryOAuthTokenStore {
  @override
  Future<Never> read() async => throw const TokenStoreLockedException();
}

void main() {
  const browserButtonKey = ValueKey('login-browser-button');
  const unlockButtonKey = ValueKey('login-unlock-button');
  const errorBannerKey = ValueKey('login-error-banner');

  const loggedInUser = UserInfo(id: 'u1hex', email: 'ray@example.com');

  late MockAuthRepository mockAuthRepository;
  late FakeBiometricAuthenticator bio;
  FakeOAuthLoginService? loginService;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    bio = FakeBiometricAuthenticator();
    loginService = null;
    when(() => mockAuthRepository.currentUser()).thenAnswer((_) async => null);
  });

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
    OAuthTokenStore? tokenStore,
    Object? loginError,
    void Function()? onLogin,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fakeRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
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
          biometricAuthenticatorProvider.overrideWithValue(bio),
          if (tokenStore != null)
            oauthTokenStoreProvider.overrideWithValue(tokenStore),
          ...fakeBrowserLoginOverrides(
            created: (s) => loginService = s,
            onLogin: onLogin,
            error: loginError,
          ),
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

  group('渲染', () {
    testWidgets('品牌標題是 VoiceOver header', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLoginScreen(tester);

      expect(
        tester
            .getSemantics(find.text('Tripline'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('只有瀏覽器登入入口，沒有 Email／密碼欄位', (tester) async {
      await pumpLoginScreen(tester);

      expect(find.text('Tripline'), findsOneWidget);
      expect(find.byKey(browserButtonKey), findsOneWidget);
      expect(find.text('使用瀏覽器登入'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('忘記密碼？'), findsNothing);
      expect(find.byKey(unlockButtonKey), findsNothing);
    });

    testWidgets('iOS／Android 的 Light／Dark 共用同一個 Login 結構', (tester) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final brightness in Brightness.values) {
          await pumpLoginScreen(
            tester,
            platform: platform,
            brightness: brightness,
          );
          expect(find.byKey(browserButtonKey), findsOneWidget);
          expect(
            find.byKey(const ValueKey('login-signup-link')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('控制項具 semantics 且至少 44×44pt', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpLoginScreen(tester);

      final size = tester.getSize(find.byKey(browserButtonKey));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      final data = tester
          .getSemantics(find.byKey(browserButtonKey))
          .getSemanticsData();
      expect(data.label, contains('登入'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    testWidgets('verified query 顯示信箱已驗證提示', (tester) async {
      await pumpLoginScreen(tester, initialLocation: '/?verified=1');

      expect(
        find.byKey(const ValueKey('login-verified-banner')),
        findsOneWidget,
      );
      expect(find.text('信箱已驗證，請登入繼續。'), findsOneWidget);
    });

    testWidgets('可從登入頁前往建立帳號流程', (tester) async {
      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(const ValueKey('login-signup-link')));
      await tester.pumpAndSettle();

      expect(find.text('signup-destination'), findsOneWidget);
    });
  });

  group('瀏覽器登入', () {
    testWidgets('點下去啟動一次瀏覽器登入', (tester) async {
      when(
        () => mockAuthRepository.currentUser(),
      ).thenAnswer((_) async => loggedInUser);
      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(browserButtonKey));
      await tester.pumpAndSettle();

      expect(loginService!.calls, 1);
    });

    testWidgets('進行中按鈕 loading 且禁止重複觸發', (tester) async {
      final gate = Completer<void>();
      await pumpLoginScreen(tester, onLogin: () {});
      // 以會卡住的登入替換：用 onLogin 無法 await，改在 currentUser 卡住。
      when(() => mockAuthRepository.currentUser()).thenAnswer((_) async {
        await gate.future;
        return loggedInUser;
      });

      await tester.tap(find.byKey(browserButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('登入中'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(browserButtonKey));
      expect(button.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('使用者取消：回到未登入，不顯示錯誤', (tester) async {
      await pumpLoginScreen(
        tester,
        loginError: OAuthLoginException(
          '使用者取消登入',
          userMessage: '已取消登入',
          cancelled: true,
        ),
      );

      await tester.tap(find.byKey(browserButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(errorBannerKey), findsNothing);
      expect(find.byKey(browserButtonKey), findsOneWidget);
    });

    testWidgets('登入失敗：顯示繁中錯誤橫幅（live region）', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpLoginScreen(
        tester,
        loginError: OAuthLoginException('授權失敗:access_denied'),
      );

      await tester.tap(find.byKey(browserButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(errorBannerKey), findsOneWidget);
      expect(find.text('Tripline 登入失敗，請稍後再試'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(errorBannerKey))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      semantics.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('登入錯誤橫幅文字對比 ≥ 4.5:1（${brightness.name}）', (tester) async {
        await pumpLoginScreen(
          tester,
          brightness: brightness,
          loginError: OAuthLoginException('boom'),
        );
        await tester.tap(find.byKey(browserButtonKey));
        await tester.pumpAndSettle();

        final finder = find.text('Tripline 登入失敗，請稍後再試');
        final scheme = Theme.of(tester.element(finder)).colorScheme;
        expect(
          errorTextContrast(tester.widget<Text>(finder).style?.color, scheme),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    testWidgets('首次載入失敗（尚未點登入）時不誤顯示登入失敗', (tester) async {
      when(
        () => mockAuthRepository.currentUser(),
      ).thenAnswer((_) async => throw Exception('network'));
      await pumpLoginScreen(tester, tokenStore: signedInTokenStore());

      expect(find.byKey(errorBannerKey), findsNothing);
    });
  });

  group('受保護憑證解鎖', () {
    testWidgets('憑證要生物辨識才讀得到：顯示解鎖按鈕，瀏覽器登入退為次要', (tester) async {
      await pumpLoginScreen(tester, tokenStore: _LockedTokenStore());

      expect(find.byKey(unlockButtonKey), findsOneWidget);
      expect(find.text('使用 Face ID 解鎖'), findsOneWidget);
      expect(find.text('改用瀏覽器登入'), findsOneWidget);
    });

    testWidgets('點解鎖會重新讀取憑證（跳出系統驗證）', (tester) async {
      final store = _CountingLockedStore();
      await pumpLoginScreen(tester, tokenStore: store);
      final readsBefore = store.reads;

      await tester.tap(find.byKey(unlockButtonKey));
      await tester.pumpAndSettle();

      expect(store.reads, greaterThan(readsBefore));
    });
  });

  group('無障礙與版面', () {
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

      final context = tester.element(find.byKey(const ValueKey('auth-card')));
      expect(TpMotion.resolve(context, TpMotion.normal), Duration.zero);
      expect(
        Theme.of(context).colorScheme.outlineVariant,
        const Color(0xFF3C3C43),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getBottomRight(signupLink).dy, lessThanOrEqualTo(844));
    });

    testWidgets('320pt compact 與 regular width 都可登入', (tester) async {
      for (final size in const [Size(320, 568), Size(1024, 768)]) {
        await pumpLoginScreen(tester, size: size);

        final signupLink = find.byKey(const ValueKey('login-signup-link'));
        await tester.ensureVisible(signupLink);
        await tester.pumpAndSettle();

        expect(find.byKey(browserButtonKey), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });
}

class _CountingLockedStore extends InMemoryOAuthTokenStore {
  int reads = 0;

  @override
  Future<Never> read() async {
    reads++;
    throw const TokenStoreLockedException();
  }
}
