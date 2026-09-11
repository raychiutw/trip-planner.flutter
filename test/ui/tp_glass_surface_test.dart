import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

/// 掃三條水平線，回傳「邊緣峰值與內部填色的差」。
///
/// 與模擬器截圖的量法一致：`pixelRatio: 3` 對齊 iPhone 的 @3x，1pt 的細邊在
/// 實體像素上是 3px，取最左側 8px 內偏離內部填色最遠的那一點。
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

    expect(textBackdrop!.glassColor.a, lessThan(1));
    expect(textBackdrop!.backerColor, isNull);
    // 媒體背景仍需獨立暗化；一般態的透明度交由套件預設。
    expect(
      visualBackdrop!.glassColor,
      Colors.black.withValues(alpha: tpMediaScrimOpacity),
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

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('${theme.brightness.name} glass 不以品牌 tint 填滿表面，一般態不描邊', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: TpGlassSurface(child: SizedBox(width: 120, height: 44)),
          ),
        ),
      );
      final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
      final shape = glass.shape as LiquidRoundedSuperellipse;
      expect(glass.settings!.glassColor.a, lessThan(1));
      expect(
        glass.settings!.glassColor.withValues(alpha: 1),
        isNot(theme.colorScheme.primary.withValues(alpha: 1)),
      );
      expect(shape.side.color.a, 0);
    });
  }

  // 媒體背景不分明暗模式都套同一層暗化 —— 地圖圖磚恆為亮色，
  // `tripMapColorScheme()` 丟棄了 brightness 參數。
  for (final brightness in [Brightness.light, Brightness.dark]) {
    final expectedTint = Colors.black.withValues(alpha: tpMediaScrimOpacity);
    testWidgets('PlatformView ${brightness.name} glass 用清透玻璃加暗化層', (
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
              child: SizedBox(width: 120, height: 44),
            ),
          ),
        ),
      );

      final settings = tester
          .widget<GlassContainer>(find.byType(GlassContainer))
          .settings!;
      expect(settings.glassColor, expectedTint);
      expect(settings.standardOpacityMultiplier, 1);
      expect(settings.platformViewFallbackColor, expectedTint);
    });
  }

  // 材質預設與真正不透明降級由 HIG 十態的像素及操作測試驗證；
  // 不釘住 lightIntensity 與 ambientStrength 等預設值。Fresnel 是 #319 真機
  // 量測後唯一明文偏離的公開參數（見 DESIGN §16.2），其餘沿用套件預設。
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('${theme.brightness.name} 導覽玻璃把全周 Fresnel 亮環減半，其餘沿用預設', (
      tester,
    ) async {
      LiquidGlassSettings? regular;
      LiquidGlassSettings? media;
      LiquidGlassSettings? packageDefaults;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              regular = tpNavigationGlassSettings(context);
              media = tpNavigationGlassSettings(
                context,
                recipe: TpNavigationGlassRecipe.platformView,
              );
              packageDefaults = GlassThemeData.of(
                context,
              ).settingsFor(context)?.applyTo(const LiquidGlassSettings());
              return const SizedBox();
            },
          ),
        ),
      );

      // iPhone 14 Pro 實測：套件預設 1.0 在深色四邊量到 +73～+112，
      // Apple Music 參考只有頂緣 +50～+65、側邊 0。減半預期降回參考量級，待真機確認。
      expect(regular!.fresnelStrength, 0.5);
      expect(media!.fresnelStrength, 0.5);
      expect(regular!.lightIntensity, packageDefaults!.lightIntensity);
      expect(regular!.ambientStrength, packageDefaults!.ambientStrength);
      expect(regular!.ambientRim, packageDefaults!.ambientRim);
      expect(regular!.refractiveIndex, packageDefaults!.refractiveIndex);
      expect(regular!.blur, packageDefaults!.blur);
    });
  }

  group('TpMediaBackdropScope', () {
    testWidgets('缺席時預設非媒體背景;宣告後子樹讀得到', (tester) async {
      late bool outside;
      late bool inside;
      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: [
            Builder(
              builder: (context) {
                outside = TpMediaBackdropScope.of(context);
                return const SizedBox();
              },
            ),
            TpMediaBackdropScope(
              onMedia: true,
              child: Builder(
                builder: (context) {
                  inside = TpMediaBackdropScope.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      );
      expect(outside, isFalse);
      expect(inside, isTrue);
    });
  });
}
