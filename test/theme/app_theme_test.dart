import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

void main() {
  group('HIG 系統主題', () {
    test('淺色使用 system surfaces、labels 與單一 tint', () {
      final theme = AppTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, TpSystemColorsLight.tint);
      expect(theme.colorScheme.surface, TpSystemColorsLight.background);
      expect(
        theme.colorScheme.surfaceContainerLow,
        TpSystemColorsLight.secondary,
      );
      expect(
        theme.colorScheme.surfaceContainerHigh,
        TpSystemColorsLight.tertiary,
      );
      expect(theme.colorScheme.onSurface, TpSystemColorsLight.label);
      expect(
        theme.colorScheme.onSurfaceVariant,
        TpSystemColorsLight.secondaryLabel,
      );
      expect(theme.colorScheme.error, TpSystemColorsLight.destructive);
      expect(theme.scaffoldBackgroundColor, TpSystemColorsLight.background);
      expect(theme.extensions, isEmpty);
    });

    test('深色使用 system surfaces、labels 與單一 tint', () {
      final theme = AppTheme.dark();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, TpSystemColorsDark.tint);
      expect(theme.colorScheme.surface, TpSystemColorsDark.background);
      expect(
        theme.colorScheme.surfaceContainerLow,
        TpSystemColorsDark.secondary,
      );
      expect(
        theme.colorScheme.surfaceContainerHigh,
        TpSystemColorsDark.tertiary,
      );
      expect(theme.colorScheme.onSurface, TpSystemColorsDark.label);
      expect(
        theme.colorScheme.onSurfaceVariant,
        TpSystemColorsDark.secondaryLabel,
      );
      expect(theme.colorScheme.error, TpSystemColorsDark.destructive);
      expect(theme.scaffoldBackgroundColor, TpSystemColorsDark.background);
      expect(theme.extensions, isEmpty);
    });

    test('未選取 chip 使用中性 surface，選取才使用 tint', () {
      final theme = AppTheme.dark();
      expect(theme.chipTheme.backgroundColor, TpSystemColorsDark.tertiary);
      expect(theme.chipTheme.selectedColor, TpSystemColorsDark.tintBackground);
    });

    test('淺色提高對比時提升 secondary label、separator 與 disabled', () {
      final normal = AppTheme.light();
      final highContrast = AppTheme.light(highContrast: true);

      expect(
        highContrast.colorScheme.onSurfaceVariant,
        const Color(0xFF3C3C43),
      );
      expect(highContrast.colorScheme.outlineVariant, const Color(0xFF3C3C43));
      expect(highContrast.disabledColor, const Color(0xB33C3C43));
      expect(
        highContrast.colorScheme.onSurfaceVariant.a,
        greaterThan(normal.colorScheme.onSurfaceVariant.a),
      );
    });

    test('深色提高對比時提升 secondary label、separator 與 disabled', () {
      final normal = AppTheme.dark();
      final highContrast = AppTheme.dark(highContrast: true);

      expect(
        highContrast.colorScheme.onSurfaceVariant,
        const Color(0xFFEBEBF5),
      );
      expect(highContrast.colorScheme.outlineVariant, const Color(0xFFEBEBF5));
      expect(highContrast.disabledColor, const Color(0xB3EBEBF5));
      expect(
        highContrast.colorScheme.onSurfaceVariant.a,
        greaterThan(normal.colorScheme.onSurfaceVariant.a),
      );
    });
  });

  group('元件 theme 規格', () {
    test('Card 與 AppBar 使用 hairline，互動控制使用 tint', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expect(theme.cardTheme.elevation, 0);
        expect(theme.appBarTheme.foregroundColor, theme.colorScheme.primary);
        expect(
          theme.appBarTheme.titleTextStyle?.color,
          theme.colorScheme.onSurface,
        );
        expect(
          theme.navigationBarTheme.indicatorColor,
          theme.colorScheme.primaryContainer,
        );
      }
    });

    test('NavigationBar selected label 與 icon 使用 tint，label 為 11', () {
      final theme = AppTheme.light();
      final selectedLabelStyle = theme.navigationBarTheme.labelTextStyle!
          .resolve({WidgetState.selected});
      final selectedIconTheme = theme.navigationBarTheme.iconTheme!.resolve({
        WidgetState.selected,
      });

      expect(selectedLabelStyle!.fontSize, 11);
      expect(selectedLabelStyle.color, theme.colorScheme.primary);
      expect(selectedIconTheme!.color, theme.colorScheme.primary);
    });

    test('所有按鈕至少 44pt，主要按鈕 radius 8', () {
      final theme = AppTheme.light();
      final filledStyle = theme.filledButtonTheme.style!;

      expect(filledStyle.minimumSize!.resolve({})!.height, TpSpacing.tapMin);
      expect(filledStyle.textStyle!.resolve({})!.fontSize, 15);
      final shape = filledStyle.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(TpRadius.md));
      expect(
        theme.textButtonTheme.style!.minimumSize!.resolve({})!.height,
        TpSpacing.tapMin,
      );
      expect(
        theme.outlinedButtonTheme.style!.minimumSize!.resolve({})!.height,
        TpSpacing.tapMin,
      );
      expect(
        theme.iconButtonTheme.style!.minimumSize!.resolve({}),
        const Size.square(TpSpacing.tapMin),
      );
    });

    test('Chip 為 StadiumBorder，輸入框 filled 且 radius 12', () {
      final theme = AppTheme.light();
      expect(theme.chipTheme.shape, isA<StadiumBorder>());
      expect(theme.chipTheme.labelStyle?.fontSize, 11);
      expect(theme.inputDecorationTheme.filled, isTrue);
      final enabledBorder =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(enabledBorder.borderRadius, BorderRadius.circular(TpRadius.lg));
    });

    test('AppBar 高 56 且無 elevation', () {
      final theme = AppTheme.light();
      expect(theme.appBarTheme.toolbarHeight, 56);
      expect(theme.appBarTheme.elevation, 0);
    });

    test('HIG type scale 完整映射且中文 letterSpacing 為 0', () {
      final textTheme = AppTheme.light().textTheme;
      expect(textTheme.displaySmall?.fontSize, 28);
      expect(textTheme.headlineMedium?.fontSize, 22);
      expect(textTheme.headlineSmall?.fontSize, 20);
      expect(textTheme.titleLarge?.fontSize, 17);
      expect(textTheme.titleMedium?.fontSize, 15);
      expect(textTheme.titleSmall?.fontSize, 13);
      expect(textTheme.bodyLarge?.fontSize, 15);
      expect(textTheme.bodyMedium?.fontSize, 13);
      expect(textTheme.bodySmall?.fontSize, 12);
      expect(textTheme.labelLarge?.fontSize, 15);
      expect(textTheme.labelMedium?.fontSize, 12);
      expect(textTheme.labelSmall?.fontSize, 11);
      expect(textTheme.bodyLarge?.letterSpacing, 0);
      expect(textTheme.bodyLarge?.fontFamily, isNot(contains('Inter')));
    });

    testWidgets('app 用到的字階全部有定義且 letterSpacing 為 0', (tester) async {
      late TextTheme textTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              textTheme = Theme.of(context).textTheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final roles = <String, TextStyle?>{
        'displaySmall': textTheme.displaySmall,
        'headlineMedium': textTheme.headlineMedium,
        'headlineSmall': textTheme.headlineSmall,
        'titleLarge': textTheme.titleLarge,
        'titleMedium': textTheme.titleMedium,
        'titleSmall': textTheme.titleSmall,
        'bodyLarge': textTheme.bodyLarge,
        'bodyMedium': textTheme.bodyMedium,
        'bodySmall': textTheme.bodySmall,
        'labelLarge': textTheme.labelLarge,
        'labelMedium': textTheme.labelMedium,
        'labelSmall': textTheme.labelSmall,
      };
      for (final MapEntry(key: role, value: style) in roles.entries) {
        expect(style?.letterSpacing, 0, reason: '$role 的 letterSpacing 必須為 0');
      }
    });
  });

  group('tokens', () {
    test('radius、spacing 與 motion 常數', () {
      expect(TpRadius.md, 8.0);
      expect(TpRadius.lg, 12.0);
      expect(TpSpacing.s4, 16.0);
      expect(TpSpacing.tapMin, 44.0);
      expect(TpSpacing.navHeight, 88.0);
      expect(TpMotion.normal, const Duration(milliseconds: 250));
      expect(TpMotion.appleEase, const Cubic(0.2, 0.8, 0.2, 1));
    });

    testWidgets('系統開啟減少動態效果時，motion duration 歸零', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(TpMotion.resolve(context, TpMotion.normal), Duration.zero);
    });
  });
}
