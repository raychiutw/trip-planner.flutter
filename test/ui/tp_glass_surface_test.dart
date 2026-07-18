import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_glass_expansion_section.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

void main() {
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
      TpColorsLight.background.withValues(alpha: 0.56),
    );
    expect(glass.settings?.blur, 22);
    expect(shape.borderRadius, 28);
  });

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
