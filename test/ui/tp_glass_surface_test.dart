import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

void main() {
  testWidgets('navigation glass separates text and visual backdrops', (
    tester,
  ) async {
    LiquidGlassSettings? textBackdrop;
    LiquidGlassSettings? visualBackdrop;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            textBackdrop = tpNavigationGlassSettings(context);
            visualBackdrop = tpNavigationGlassSettings(
              context,
              recipe: TpNavigationGlassRecipe.platformView,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(textBackdrop!.glassColor.a, closeTo(0.40, 0.01));
    expect(textBackdrop!.backerColor, isNull);
    // 媒體背景改清透玻璃加暗化層 —— 比一般背景更透，不再更不透明。
    expect(visualBackdrop!.glassColor.a, closeTo(tpMediaScrimOpacity, 0.01));
    expect(
      visualBackdrop!.glassColor.a,
      lessThan(textBackdrop!.glassColor.a),
      reason: '清透玻璃的不透明度必須低於一般背景的玻璃',
    );
    expect(visualBackdrop!.backerColor, isNull);
  });

  testWidgets('navigation glass becomes opaque when contrast is increased', (
    tester,
  ) async {
    LiquidGlassSettings? resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: Builder(
            builder: (context) {
              resolved = tpNavigationGlassSettings(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(resolved!.glassColor.a, 1);
    expect(resolved!.platformViewFallbackColor!.a, 1);
    expect(resolved!.blur, 0);
    expect(resolved!.thickness, 0);
    expect(resolved!.refractiveIndex, 1);
  });

  testWidgets(
    'navigation glass becomes opaque when Reduce Transparency is enabled',
    (tester) async {
      LiquidGlassSettings? resolved;
      bool? highContrast;
      await tester.pumpWidget(
        MaterialApp(
          home: AppAccessibilityScope(
            reduceTransparency: true,
            child: Builder(
              builder: (context) {
                highContrast = MediaQuery.highContrastOf(context);
                resolved = tpNavigationGlassSettings(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(highContrast, isFalse);
      expect(resolved!.glassColor.a, 1);
      expect(resolved!.platformViewFallbackColor!.a, 1);
      expect(resolved!.blur, 0);
      expect(resolved!.thickness, 0);
      expect(resolved!.refractiveIndex, 1);
    },
  );

  testWidgets(
    'TpGlassSurface resolves custom settings for Reduce Transparency',
    (tester) async {
      const customSettings = LiquidGlassSettings(
        glassColor: Color(0x332196F3),
        blur: 30,
        thickness: 26,
        refractiveIndex: 1.2,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppAccessibilityScope(
            reduceTransparency: true,
            child: const Scaffold(
              body: TpGlassSurface(
                glassSettings: customSettings,
                tintColor: Color(0xFF2196F3),
                child: SizedBox(width: 120, height: 44),
              ),
            ),
          ),
        ),
      );

      final settings = tester
          .widget<GlassContainer>(find.byType(GlassContainer))
          .settings!;
      const opaqueBlue = Color(0xFF2196F3);
      expect(settings.glassColor, opaqueBlue);
      expect(settings.backerColor, opaqueBlue);
      expect(settings.platformViewFallbackColor, opaqueBlue);
      expect(settings.blur, 0);
      expect(settings.thickness, 0);
      expect(settings.refractiveIndex, 1);
    },
  );

  testWidgets('淺色 glass 使用系統 surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: TpGlassSurface(child: SizedBox(width: 120, height: 44)),
        ),
      ),
    );

    final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    final shape = glass.shape as LiquidRoundedSuperellipse;

    expect(glass.quality, GlassQuality.standard);
    expect(glass.useOwnLayer, isTrue);
    expect(
      glass.settings?.glassColor,
      TpSystemColorsLight.background.withValues(alpha: 0.58),
    );
    expect(glass.settings?.blur, 22);
    expect(shape.borderRadius, 28);
    expect(shape.side.color.a, closeTo(0.88, 0.01));
  });

  testWidgets('dark glass uses elevated material with a subtle bright rim', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: TpGlassSurface(child: SizedBox(width: 120, height: 44)),
        ),
      ),
    );

    final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    final shape = glass.shape as LiquidRoundedSuperellipse;

    expect(
      glass.settings?.glassColor,
      TpSystemColorsDark.secondary.withValues(alpha: 0.68),
    );
    expect(shape.side.color.a, closeTo(0.18, 0.01));
  });

  // 媒體背景不分明暗模式都套同一層暗化 —— 地圖圖磚恆為亮色，
  // `tripMapColorScheme()` 丟棄了 brightness 參數。
  for (final brightness in [Brightness.light, Brightness.dark]) {
    final expectedTint = Colors.black.withValues(alpha: tpMediaScrimOpacity);
    testWidgets('PlatformView ${brightness.name} glass 用清透玻璃加暗化層並保留 28pt 配方', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: const Scaffold(
            body: TpGlassSurface(
              platformViewBackdrop: true,
              blurSigma: 28,
              child: SizedBox(width: 120, height: 44),
            ),
          ),
        ),
      );

      final settings = tester
          .widget<GlassContainer>(find.byType(GlassContainer))
          .settings!;
      expect(settings.blur, 28);
      expect(settings.glassColor, expectedTint);
      expect(settings.standardOpacityMultiplier, 1);
      expect(settings.platformViewFallbackColor, expectedTint);
    });
  }
}
