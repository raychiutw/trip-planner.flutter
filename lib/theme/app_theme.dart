import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tripline ThemeData 工廠。
///
/// 字型不指定 fontFamily → 走各平台系統字(iOS: SF Pro、Android: Roboto,
/// CJK 由系統 PingFang/Noto 自動 fallback),最貼 HIG 且拿到真 Dynamic Type。
abstract final class AppTheme {
  /// HIG 淺色主題；暖褐 tint 只用於選取、連結與主要動作。
  static ThemeData light({bool highContrast = false}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: TpSystemColorsLight.tint,
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: TpSystemColorsLight.tintBackground,
      onPrimaryContainer: TpSystemColorsLight.tintDeep,
      secondary: TpSystemColorsLight.secondaryLabel,
      onSecondary: TpSystemColorsLight.label,
      secondaryContainer: TpSystemColorsLight.tertiary,
      onSecondaryContainer: TpSystemColorsLight.label,
      tertiary: TpSystemColorsLight.secondaryLabel,
      onTertiary: TpSystemColorsLight.label,
      tertiaryContainer: TpSystemColorsLight.tertiary,
      onTertiaryContainer: TpSystemColorsLight.label,
      surface: TpSystemColorsLight.background,
      surfaceContainerLow: TpSystemColorsLight.secondary,
      surfaceContainerHigh: TpSystemColorsLight.tertiary,
      surfaceContainerHighest: TpSystemColorsLight.quaternary,
      onSurface: TpSystemColorsLight.label,
      onSurfaceVariant: highContrast
          ? const Color(0xFF3C3C43)
          : TpSystemColorsLight.secondaryLabel,
      outline: highContrast
          ? TpSystemColorsLight.label
          : TpSystemColorsLight.opaqueSeparator,
      outlineVariant: highContrast
          ? const Color(0xFF3C3C43)
          : TpSystemColorsLight.separator,
      error: TpSystemColorsLight.destructive,
      onError: const Color(0xFFFFFFFF),
      errorContainer: TpSystemColorsLight.destructiveBackground,
      onErrorContainer: TpSystemColorsLight.destructive,
      scrim: TpSystemColorsLight.overlay,
    );
    return _buildTheme(
      colorScheme: colorScheme,
      hover: TpSystemColorsLight.hover,
      disabled: highContrast
          ? const Color(0xB33C3C43)
          : TpSystemColorsLight.disabled,
      scaffoldBackground: TpSystemColorsLight.background,
    );
  }

  /// HIG 深色主題；使用與淺色相同的系統語意層級。
  static ThemeData dark({bool highContrast = false}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: TpSystemColorsDark.tint,
      onPrimary: TpSystemColorsDark.background,
      primaryContainer: TpSystemColorsDark.tintBackground,
      onPrimaryContainer: TpSystemColorsDark.tintDeep,
      secondary: TpSystemColorsDark.secondaryLabel,
      onSecondary: TpSystemColorsDark.background,
      secondaryContainer: TpSystemColorsDark.tertiary,
      onSecondaryContainer: TpSystemColorsDark.label,
      tertiary: TpSystemColorsDark.secondaryLabel,
      onTertiary: TpSystemColorsDark.background,
      tertiaryContainer: TpSystemColorsDark.tertiary,
      onTertiaryContainer: TpSystemColorsDark.label,
      surface: TpSystemColorsDark.background,
      surfaceContainerLow: TpSystemColorsDark.secondary,
      surfaceContainerHigh: TpSystemColorsDark.tertiary,
      surfaceContainerHighest: TpSystemColorsDark.quaternary,
      onSurface: TpSystemColorsDark.label,
      onSurfaceVariant: highContrast
          ? const Color(0xFFEBEBF5)
          : TpSystemColorsDark.secondaryLabel,
      outline: highContrast
          ? TpSystemColorsDark.label
          : TpSystemColorsDark.opaqueSeparator,
      outlineVariant: highContrast
          ? const Color(0xFFEBEBF5)
          : TpSystemColorsDark.separator,
      error: TpSystemColorsDark.destructive,
      onError: TpSystemColorsDark.background,
      errorContainer: TpSystemColorsDark.destructiveBackground,
      onErrorContainer: TpSystemColorsDark.destructive,
      scrim: TpSystemColorsDark.overlay,
    );
    return _buildTheme(
      colorScheme: colorScheme,
      hover: TpSystemColorsDark.hover,
      disabled: highContrast
          ? const Color(0xB3EBEBF5)
          : TpSystemColorsDark.disabled,
      scaffoldBackground: TpSystemColorsDark.background,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color hover,
    required Color disabled,
    required Color scaffoldBackground,
  }) {
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(TpRadius.md)),
    );
    const buttonMinSize = Size(0, TpSpacing.tapMin);
    const iconButtonMinSize = Size.square(TpSpacing.tapMin);
    const buttonTextStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);

    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      hoverColor: hover,
      disabledColor: disabled,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          overlayColor: hover,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: iconButtonMinSize),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: TpSpacing.navHeight,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 20,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            letterSpacing: 0,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      appBarTheme: AppBarThemeData(
        toolbarHeight: 56,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
    );
  }

  /// 將 HIG 字階對應到 Material 角色；中文 letterSpacing 一律為 0。
  static TextTheme _textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        height: 34 / 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      // HIG title3：內容主體的 hero 標題（行程名等），不是頁面標題。
      headlineSmall: TextStyle(
        fontSize: 20,
        height: 25 / 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        height: 22 / 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      // HIG footnote：區塊小標。未定義時會 fallback 到 Material 預設的
      // 14/w500/letterSpacing 0.1 —— 那個字距違反「中文不加字距」。
      titleSmall: TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 13 / 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
