import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

/// 掃三條水平線，回傳「邊緣峰值與內部填色的差」。
///
/// 與模擬器截圖的量法一致：`pixelRatio: 3` 對齊 iPhone 的 @3x，1pt 的細邊在
/// 實體像素上是 3px，取最左側 8px 內偏離內部填色最遠的那一點。
Future<List<double>> _edgeDeltas(WidgetTester tester, Key boundaryKey) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  late ui.Image image;
  late ByteData pixels;
  await tester.runAsync(() async {
    image = await boundary.toImage(pixelRatio: 3);
    pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  final width = image.width;
  double lumaAt(int x, int y) {
    final offset = (y * width + x) * 4;
    return 0.299 * pixels.getUint8(offset) +
        0.587 * pixels.getUint8(offset + 1) +
        0.114 * pixels.getUint8(offset + 2);
  }

  final deltas = <double>[];
  for (final fraction in [0.35, 0.5, 0.65]) {
    final y = (image.height * fraction).round();
    final interior = lumaAt(width ~/ 2, y);
    var peak = interior;
    for (var x = 0; x < 8; x++) {
      final value = lumaAt(x, y);
      if ((value - interior).abs() > (peak - interior).abs()) peak = value;
    }
    deltas.add((peak - interior).abs());
  }
  image.dispose();
  return deltas;
}

void main() {
  testWidgets('材質邊緣光依真機量測調降：+125 → +30 的比例', (tester) async {
    // 真機（v0.13.0）量到標題膠囊／頭像圓鈕的邊緣高出內部填色 +125~+138，
    // iOS 26 是 +29~+31。這組值是 30/125 ≈ 0.24 的等比調降。
    //
    // **期望值寫死。** 拿 lib 的常數當期望值會變成恆真測試。
    late LiquidGlassSettings regular;
    late LiquidGlassSettings media;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            const tint = Color(0x661C1C1E);
            regular = tpGlassRecipe(
              context,
              tint: tint,
              onMedia: false,
              blur: 16,
            );
            media = tpGlassRecipe(context, tint: tint, onMedia: true, blur: 16);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(regular.ambientRim, closeTo(0.17, 0.0001));
    expect(regular.glowIntensity, closeTo(0.18, 0.0001));
    expect(media.ambientRim, closeTo(0.12, 0.0001));
    expect(media.glowIntensity, closeTo(0.12, 0.0001));
  });

  // 斷言**實際畫出來的像素**，不是 `BorderSide` 的 alpha —— 這個專案已經因為
  // 「參數一直是對的、畫面一直是錯的」吃過虧。取像素的作法與模擬器截圖同源：
  // 掃一條水平線，比邊緣峰值與內部填色。
  for (final (name, theme, fillOf)
      in <(String, ThemeData, Color Function(ColorScheme))>[
        ('dark', AppTheme.dark(), (scheme) => scheme.surfaceContainerLow),
        ('light', AppTheme.light(), (scheme) => scheme.surfaceContainerLow),
      ]) {
    testWidgets('$name：畫上去的細邊實際高出內部填色 30(±8)，且沿邊緣一致', (tester) async {
      final fill = fillOf(theme.colorScheme);
      const boundaryKey = ValueKey('tp-glass-edge-probe');
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            backgroundColor: fill,
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: TpGlassEdge(
                  borderRadius: 22,
                  child: ColoredBox(
                    color: fill,
                    child: const SizedBox(width: 240, height: 60),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final deltas = await _edgeDeltas(tester, boundaryKey);
      for (final delta in deltas) {
        expect(delta, closeTo(30, 8), reason: '沿邊緣每一列都要有同一條可辨識的細邊；實測 $deltas');
      }
    });
  }

  test('媒體背景的暗化層是 HIG 材質指引的約 35%', () {
    // 其餘測試以 tpMediaScrimOpacity 表達意圖；這裡釘住實際數值，
    // 否則改動常數時所有斷言會跟著一起改，變成恆真。
    expect(tpMediaScrimOpacity, closeTo(0.35, 0.001));
  });

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
    // 一般模式描一條**細邊**。原本相信「移除描邊後由材質接手」,模擬器實測
    // 材質並沒有接手:不論背後純黑或壓在內容上,邊緣與填色的差都是 0,
    // 調 ambientRim 從 0.70 到 0.07 五組值也全是 0。Apple 是 +30。
    expect(shape.side.color.a, closeTo(0.12, 0.001));
    expect(glass.settings!.ambientRim, greaterThan(0));
    expect(glass.settings!.glowIntensity, greaterThan(0));
  });

  testWidgets('dark glass 的邊緣由材質產生，不再描一圈實心線', (tester) async {
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
    // 一般模式描一條細邊(見上)。深色由 onSurface(白)導出偏亮的邊,
    // 淺色由 onSurface(黑)導出偏暗的邊 —— 淺色填色本來就接近白,
    // 再加白邊等於沒有。
    expect(shape.side.color.a, closeTo(0.12, 0.001));
    expect(glass.settings!.ambientRim, greaterThan(0));
    expect(glass.settings!.glowIntensity, greaterThan(0));
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
