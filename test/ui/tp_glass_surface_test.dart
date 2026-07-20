import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_glass_expansion_section.dart';
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
              visualContent: true,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(textBackdrop!.glassColor.a, closeTo(0.90, 0.01));
    expect(textBackdrop!.backerColor?.a, closeTo(0.90, 0.01));
    expect(visualBackdrop!.glassColor.a, closeTo(0.58, 0.01));
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

    expect(resolved!.glassColor.a, greaterThanOrEqualTo(0.95));
    expect(resolved!.platformViewFallbackColor!.a, greaterThanOrEqualTo(0.95));
    expect(resolved!.blur, 0);
    expect(resolved!.thickness, 0);
    expect(resolved!.refractiveIndex, 1);
  });

  testWidgets('light glass matches the final warm Liquid Glass tokens', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
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
      TpColorsLight.background.withValues(alpha: 0.58),
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
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: TpGlassSurface(child: SizedBox(width: 120, height: 44)),
        ),
      ),
    );

    final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    final shape = glass.shape as LiquidRoundedSuperellipse;

    expect(
      glass.settings?.glassColor,
      TpColorsDark.secondary.withValues(alpha: 0.68),
    );
    expect(shape.side.color.a, closeTo(0.18, 0.01));
  });

  for (final (brightness, expectedTint) in [
    (Brightness.light, TpColorsLight.background.withValues(alpha: 0.58)),
    (Brightness.dark, TpColorsDark.secondary.withValues(alpha: 0.68)),
  ]) {
    testWidgets(
      'PlatformView ${brightness.name} glass preserves the 28pt Liquid Glass recipe',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
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
      },
    );
  }

  for (final (brightness, expectedColor) in [
    (Brightness.light, TpColorsLight.background.withValues(alpha: 0.52)),
    (Brightness.dark, TpColorsDark.glass.withValues(alpha: 0.48)),
  ]) {
    testWidgets(
      'glass expansion follows Tripline ${brightness.name} color and expands',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(
              body: TpGlassExpansionSection(
                title: Text('住宿'),
                children: [Text('住宿內容')],
              ),
            ),
          ),
        );

        final glass = tester.widget<GlassContainer>(
          find.descendant(
            of: find.byType(TpGlassExpansionSection),
            matching: find.byType(GlassContainer),
          ),
        );
        expect(glass.settings?.glassColor, expectedColor);
        expect(find.text('住宿內容'), findsNothing);

        await tester.tap(find.text('住宿'));
        await tester.pumpAndSettle();
        expect(find.text('住宿內容'), findsOneWidget);
      },
    );
  }
}
