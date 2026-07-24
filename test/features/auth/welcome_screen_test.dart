import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

void main() {
  Future<void> pumpWelcome(
    WidgetTester tester, {
    required VoidCallback onLogin,
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
    TargetPlatform platform = TargetPlatform.iOS,
    bool boldText = false,
    bool highContrast = false,
    bool reduceMotion = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final theme =
        (brightness == Brightness.light
                ? AppTheme.light(highContrast: highContrast)
                : AppTheme.dark(highContrast: highContrast))
            .copyWith(platform: platform);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            platformBrightness: brightness,
            boldText: boldText,
            highContrast: highContrast,
            disableAnimations: reduceMotion,
          ),
          child: WelcomeScreen(onLogin: onLogin),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('直接顯示主訴求、三項功能與登入 CTA', (tester) async {
    var loginCount = 0;
    await pumpWelcome(tester, onLogin: () => loginCount++);

    expect(find.text('行程排壞了，講一句話就好', findRichText: true), findsOneWidget);
    expect(find.text('說一句話就改好'), findsOneWidget);
    expect(find.text('每天的路線一眼看完'), findsOneWidget);
    expect(find.text('出發前先健檢'), findsOneWidget);
    expect(find.text('隱私權政策'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    expect(loginCount, 1);
  });

  testWidgets('頁尾 CTA 可捲到並直接登入', (tester) async {
    var loginCount = 0;
    await pumpWelcome(tester, onLogin: () => loginCount++);

    final bottom = find.byKey(const ValueKey('welcome-login-bottom'));
    await tester.scrollUntilVisible(
      bottom,
      500,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('welcome-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(bottom);
    await tester.pumpAndSettle();
    await tester.tap(bottom);

    expect(loginCount, 1);
  });

  testWidgets('iOS／Android 的 Light／Dark 共用同一個 Welcome 結構', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpWelcome(
          tester,
          onLogin: () {},
          platform: platform,
          brightness: brightness,
        );

        final context = tester.element(
          find.byKey(const ValueKey('welcome-screen')),
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
        expect(find.byKey(const ValueKey('welcome-login-top')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('welcome-login-hero')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('welcome-feature-chat')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('登入入口具 button semantics、正確 label 與至少 44×44pt', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpWelcome(tester, onLogin: () {});

    for (final key in const [
      ValueKey('welcome-login-top'),
      ValueKey('welcome-login-hero'),
    ]) {
      final finder = find.byKey(key);
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue, reason: '$key semantics');
      expect(data.label, contains('登入'), reason: '$key label');
    }

    const bottomKey = ValueKey('welcome-login-bottom');
    final bottom = find.byKey(bottomKey);
    await tester.scrollUntilVisible(
      bottom,
      500,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('welcome-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    final bottomSize = tester.getSize(bottom);
    expect(bottomSize.width, greaterThanOrEqualTo(44));
    expect(bottomSize.height, greaterThanOrEqualTo(44));
    final bottomData = tester.getSemantics(bottom).getSemanticsData();
    expect(bottomData.flagsCollection.isButton, isTrue);
    expect(bottomData.label, contains('登入'));

    semantics.dispose();
  });

  testWidgets('Accessibility Size、Bold Text、提高對比與 Reduce Motion 不裁切', (
    tester,
  ) async {
    await pumpWelcome(
      tester,
      onLogin: () {},
      textScale: 3.2,
      boldText: true,
      highContrast: true,
      reduceMotion: true,
    );

    final headline = tester.widget<Text>(
      find.byKey(const ValueKey('welcome-headline')),
    );
    expect(
      headline.style?.fontSize,
      AppTheme.light().textTheme.displaySmall?.fontSize,
    );
    expect(headline.style?.letterSpacing, 0);
    final description = find.text(
      '「第二天下午排太趕」——說出來，行程自己調整，還會告訴你動了哪些點、車程差多少。不用一格一格拖。',
    );
    final richDescription = tester.widget<RichText>(
      find.descendant(of: description, matching: find.byType(RichText)),
    );
    expect(
      richDescription.text.style?.fontWeight?.value,
      greaterThan(AppTheme.light().textTheme.bodyLarge!.fontWeight!.value),
    );
    final context = tester.element(
      find.byKey(const ValueKey('welcome-screen')),
    );
    expect(TpMotion.resolve(context, TpMotion.normal), Duration.zero);
    expect(
      Theme.of(context).colorScheme.outlineVariant,
      const Color(0xFF3C3C43),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('welcome-login-bottom')),
      800,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('welcome-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Header 使用不透明 system surface', (tester) async {
    await pumpWelcome(tester, onLogin: () {});

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.backgroundColor, AppTheme.light().colorScheme.surface);
    expect(appBar.backgroundColor?.a, 1);
  });

  testWidgets('320pt compact 與 regular width 都可抵達完整 Welcome 內容', (
    tester,
  ) async {
    for (final size in const [Size(320, 568), Size(1024, 768)]) {
      await pumpWelcome(tester, onLogin: () {}, size: size);

      final bottom = find.byKey(const ValueKey('welcome-login-bottom'));
      await tester.scrollUntilVisible(
        bottom,
        600,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('welcome-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      expect(bottom, findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
