import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

void main() {
  group('AppTheme.light', () {
    test('可建構且使用 Material 3', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.useMaterial3, isTrue);
    });

    test('primary = 柔褐 0xFFA97A4A', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.colorScheme.primary, const Color(0xFFA97A4A));
    });

    test('background = 奶油底 0xFFFFFBF5', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.colorScheme.surface, const Color(0xFFFFFBF5));
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFFFFBF5));
    });

    test('CardTheme elevation 為 0（hairline 原則）', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.cardTheme.elevation, 0);
    });

    test('TpTones extension 可從 ThemeData 取得且色值正確', () {
      final lightTheme = AppTheme.light();
      final tones = lightTheme.extension<TpTones>();
      expect(tones, isNotNull);
      expect(tones!.accent, TpColorsLight.accent);
      expect(tones.sageDeep, TpColorsLight.sageDeep);
      expect(tones.pinkBg, TpColorsLight.pinkBg);
      expect(tones.success, TpColorsLight.success);
      expect(tones.warning, TpColorsLight.warning);
    });
  });

  group('AppTheme.dark', () {
    test('可建構且使用 Material 3', () {
      final darkTheme = AppTheme.dark();
      expect(darkTheme.useMaterial3, isTrue);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
    });

    test('primary = 調亮柔褐 0xFFCBA06E', () {
      final darkTheme = AppTheme.dark();
      expect(darkTheme.colorScheme.primary, const Color(0xFFCBA06E));
    });

    test('background = 暖褐黑 0xFF1A140F', () {
      final darkTheme = AppTheme.dark();
      expect(darkTheme.colorScheme.surface, const Color(0xFF1A140F));
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF1A140F));
    });

    test('CardTheme elevation 為 0', () {
      final darkTheme = AppTheme.dark();
      expect(darkTheme.cardTheme.elevation, 0);
    });

    test('TpTones extension 可從 ThemeData 取得且為 dark 色值', () {
      final darkTheme = AppTheme.dark();
      final tones = darkTheme.extension<TpTones>();
      expect(tones, isNotNull);
      expect(tones!.accent, TpColorsDark.accent);
      expect(tones.sage, TpColorsDark.sage);
      expect(tones.pinkSubtle, TpColorsDark.pinkSubtle);
    });
  });

  group('TpTones', () {
    test('copyWith 可覆寫單一欄位', () {
      final lightTones = AppTheme.light().extension<TpTones>()!;
      final overridden = lightTones.copyWith(accent: const Color(0xFF000000));
      expect(overridden.accent, const Color(0xFF000000));
      expect(overridden.sage, lightTones.sage);
    });

    test('lerp t=0 / t=1 回到端點', () {
      final lightTones = AppTheme.light().extension<TpTones>()!;
      final darkTones = AppTheme.dark().extension<TpTones>()!;
      expect(lightTones.lerp(darkTones, 0).accent, lightTones.accent);
      expect(lightTones.lerp(darkTones, 1).accent, darkTones.accent);
    });
  });

  group('元件 theme 規格', () {
    test('NavigationBar：active=accent、indicator=accentSubtle、label 11', () {
      final lightTheme = AppTheme.light();
      final navigationBarTheme = lightTheme.navigationBarTheme;
      expect(navigationBarTheme.indicatorColor, TpColorsLight.accentSubtle);
      final selectedLabelStyle = navigationBarTheme.labelTextStyle!.resolve({
        WidgetState.selected,
      });
      expect(selectedLabelStyle!.fontSize, 11);
      expect(selectedLabelStyle.color, TpColorsLight.accent);
      final selectedIconTheme = navigationBarTheme.iconTheme!.resolve({
        WidgetState.selected,
      });
      expect(selectedIconTheme!.color, TpColorsLight.accent);
    });

    test('FilledButton：minHeight 44、radius 8', () {
      final lightTheme = AppTheme.light();
      final filledButtonStyle = lightTheme.filledButtonTheme.style!;
      expect(filledButtonStyle.minimumSize!.resolve({})!.height, 44);
      final buttonShape =
          filledButtonStyle.shape!.resolve({}) as RoundedRectangleBorder;
      expect(buttonShape.borderRadius, BorderRadius.circular(TpRadius.md));
    });

    test('Chip 為 StadiumBorder', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.chipTheme.shape, isA<StadiumBorder>());
    });

    test('Input：filled、radius 12', () {
      final lightTheme = AppTheme.light();
      final inputTheme = lightTheme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      final enabledBorder = inputTheme.enabledBorder as OutlineInputBorder;
      expect(enabledBorder.borderRadius, BorderRadius.circular(TpRadius.lg));
    });

    test('AppBar：高 56、無 elevation', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.appBarTheme.toolbarHeight, 56);
      expect(lightTheme.appBarTheme.elevation, 0);
    });

    test('TextTheme：系統字(不打包 Inter)、body 16 letterSpacing 0', () {
      final lightTheme = AppTheme.light();
      final bodyStyle = lightTheme.textTheme.bodyLarge!;
      expect(bodyStyle.fontSize, 16);
      expect(bodyStyle.letterSpacing, 0);
      // 改用系統字:iOS→SF Pro、Android→Roboto,CJK 由系統 fallback;不再打包 Inter。
      expect(bodyStyle.fontFamily, isNot(contains('Inter')));
    });
  });

  group('tokens', () {
    test('radius / spacing / motion 常數', () {
      expect(TpRadius.md, 8.0);
      expect(TpRadius.lg, 12.0);
      expect(TpSpacing.s4, 16.0);
      expect(TpSpacing.tapMin, 44.0);
      expect(TpSpacing.navHeight, 88.0);
      expect(TpMotion.normal, const Duration(milliseconds: 250));
      expect(TpMotion.appleEase, const Cubic(0.2, 0.8, 0.2, 1));
    });
  });
}
