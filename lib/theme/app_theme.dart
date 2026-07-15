import 'package:flutter/material.dart';

import 'tokens.dart';

/// 三色系統 ThemeExtension：accent/sage/pink 各 4 階 + success/warning。
/// subtle 階沒有 ColorScheme 對應欄位，元件一律從這裡取 tone 色。
class TpTones extends ThemeExtension<TpTones> {
  const TpTones({
    required this.accent,
    required this.accentDeep,
    required this.accentSubtle,
    required this.accentBg,
    required this.sage,
    required this.sageDeep,
    required this.sageSubtle,
    required this.sageBg,
    required this.pink,
    required this.pinkDeep,
    required this.pinkSubtle,
    required this.pinkBg,
    required this.success,
    required this.warning,
  });

  final Color accent;
  final Color accentDeep;
  final Color accentSubtle;
  final Color accentBg;
  final Color sage;
  final Color sageDeep;
  final Color sageSubtle;
  final Color sageBg;
  final Color pink;
  final Color pinkDeep;
  final Color pinkSubtle;
  final Color pinkBg;
  final Color success;
  final Color warning;

  static const light = TpTones(
    accent: TpColorsLight.accent,
    accentDeep: TpColorsLight.accentDeep,
    accentSubtle: TpColorsLight.accentSubtle,
    accentBg: TpColorsLight.accentBg,
    sage: TpColorsLight.sage,
    sageDeep: TpColorsLight.sageDeep,
    sageSubtle: TpColorsLight.sageSubtle,
    sageBg: TpColorsLight.sageBg,
    pink: TpColorsLight.pink,
    pinkDeep: TpColorsLight.pinkDeep,
    pinkSubtle: TpColorsLight.pinkSubtle,
    pinkBg: TpColorsLight.pinkBg,
    success: TpColorsLight.success,
    warning: TpColorsLight.warning,
  );

  static const dark = TpTones(
    accent: TpColorsDark.accent,
    accentDeep: TpColorsDark.accentDeep,
    accentSubtle: TpColorsDark.accentSubtle,
    accentBg: TpColorsDark.accentBg,
    sage: TpColorsDark.sage,
    sageDeep: TpColorsDark.sageDeep,
    sageSubtle: TpColorsDark.sageSubtle,
    sageBg: TpColorsDark.sageBg,
    pink: TpColorsDark.pink,
    pinkDeep: TpColorsDark.pinkDeep,
    pinkSubtle: TpColorsDark.pinkSubtle,
    pinkBg: TpColorsDark.pinkBg,
    success: TpColorsDark.success,
    warning: TpColorsDark.warning,
  );

  @override
  TpTones copyWith({
    Color? accent,
    Color? accentDeep,
    Color? accentSubtle,
    Color? accentBg,
    Color? sage,
    Color? sageDeep,
    Color? sageSubtle,
    Color? sageBg,
    Color? pink,
    Color? pinkDeep,
    Color? pinkSubtle,
    Color? pinkBg,
    Color? success,
    Color? warning,
  }) {
    return TpTones(
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      accentBg: accentBg ?? this.accentBg,
      sage: sage ?? this.sage,
      sageDeep: sageDeep ?? this.sageDeep,
      sageSubtle: sageSubtle ?? this.sageSubtle,
      sageBg: sageBg ?? this.sageBg,
      pink: pink ?? this.pink,
      pinkDeep: pinkDeep ?? this.pinkDeep,
      pinkSubtle: pinkSubtle ?? this.pinkSubtle,
      pinkBg: pinkBg ?? this.pinkBg,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  TpTones lerp(ThemeExtension<TpTones>? other, double t) {
    if (other is! TpTones) return this;
    return TpTones(
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      accentBg: Color.lerp(accentBg, other.accentBg, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      sageDeep: Color.lerp(sageDeep, other.sageDeep, t)!,
      sageSubtle: Color.lerp(sageSubtle, other.sageSubtle, t)!,
      sageBg: Color.lerp(sageBg, other.sageBg, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      pinkDeep: Color.lerp(pinkDeep, other.pinkDeep, t)!,
      pinkSubtle: Color.lerp(pinkSubtle, other.pinkSubtle, t)!,
      pinkBg: Color.lerp(pinkBg, other.pinkBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

/// Tripline ThemeData 工廠（warm editorial：hairline over shadow、radius md 8）。
///
/// 字型不指定 fontFamily → 走各平台系統字(iOS: SF Pro、Android: Roboto,
/// CJK 由系統 PingFang/Noto 自動 fallback),最貼 HIG 且拿到真 Dynamic Type。
abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: TpColorsLight.accent,
      onPrimary: TpColorsLight.accentForeground,
      primaryContainer: TpColorsLight.accentBg,
      onPrimaryContainer: TpColorsLight.accentDeep,
      secondary: TpColorsLight.sage,
      onSecondary: TpColorsLight.foreground,
      secondaryContainer: TpColorsLight.sageBg,
      onSecondaryContainer: TpColorsLight.sageDeep,
      tertiary: TpColorsLight.pink,
      onTertiary: TpColorsLight.foreground,
      tertiaryContainer: TpColorsLight.pinkBg,
      onTertiaryContainer: TpColorsLight.pinkDeep,
      surface: TpColorsLight.background,
      surfaceContainerLow: TpColorsLight.secondary,
      surfaceContainerHigh: TpColorsLight.tertiary,
      onSurface: TpColorsLight.foreground,
      onSurfaceVariant: TpColorsLight.muted,
      outline: TpColorsLight.lineStrong,
      outlineVariant: TpColorsLight.border,
      error: TpColorsLight.destructive,
      onError: Color(0xFFFFFFFF),
      errorContainer: TpColorsLight.destructiveBg,
      onErrorContainer: TpColorsLight.destructive,
      scrim: TpColorsLight.overlay,
    );
    return _buildTheme(
      colorScheme: colorScheme,
      tones: TpTones.light,
      hover: TpColorsLight.hover,
      disabled: TpColorsLight.disabled,
      scaffoldBackground: TpColorsLight.background,
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: TpColorsDark.accent,
      onPrimary: TpColorsDark.accentForeground,
      primaryContainer: TpColorsDark.accentBg,
      onPrimaryContainer: TpColorsDark.accentDeep,
      secondary: TpColorsDark.sage,
      onSecondary: TpColorsDark.background,
      secondaryContainer: TpColorsDark.sageBg,
      onSecondaryContainer: TpColorsDark.sageDeep,
      tertiary: TpColorsDark.pink,
      onTertiary: TpColorsDark.background,
      tertiaryContainer: TpColorsDark.pinkBg,
      onTertiaryContainer: TpColorsDark.pinkDeep,
      surface: TpColorsDark.secondary,
      surfaceContainerLow: TpColorsDark.tertiary,
      surfaceContainerHigh: TpColorsDark.tertiary,
      onSurface: TpColorsDark.foreground,
      onSurfaceVariant: TpColorsDark.muted,
      outline: TpColorsDark.lineStrong,
      outlineVariant: TpColorsDark.border,
      error: TpColorsDark.destructive,
      onError: TpColorsDark.background,
      errorContainer: TpColorsDark.destructiveBg,
      onErrorContainer: TpColorsDark.destructive,
      scrim: TpColorsDark.overlay,
    );
    return _buildTheme(
      colorScheme: colorScheme,
      tones: TpTones.dark,
      hover: TpColorsDark.hover,
      disabled: TpColorsDark.disabled,
      scaffoldBackground: TpColorsDark.background,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required TpTones tones,
    required Color hover,
    required Color disabled,
    required Color scaffoldBackground,
  }) {
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(TpRadius.md)),
    );
    const buttonMinSize = Size(0, TpSpacing.tapMin);
    const buttonTextStyle = TextStyle(
      fontSize: 16,
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
      extensions: [tones],
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
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 0,
        backgroundColor: tones.accentSubtle,
        selectedColor: tones.accent,
        labelStyle: TextStyle(
          fontSize: 12,
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
        indicatorColor: tones.accentSubtle,
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
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
    );
  }

  /// HIG 字級表；中文 letterSpacing 一律 0。
  static TextTheme _textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        height: 26 / 17,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 23 / 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
