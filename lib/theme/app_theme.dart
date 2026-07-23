import 'package:flutter/material.dart';

import 'tokens.dart';

/// 共用色階 ThemeExtension。sage/pink 僅保留舊 API 相容性，實際映射中性色。
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

  static const systemLight = TpTones(
    accent: TpSystemColorsLight.tint,
    accentDeep: TpSystemColorsLight.tintDeep,
    accentSubtle: TpSystemColorsLight.tintSubtle,
    accentBg: TpSystemColorsLight.tintBackground,
    sage: TpSystemColorsLight.secondaryLabel,
    sageDeep: TpSystemColorsLight.label,
    sageSubtle: TpSystemColorsLight.tertiary,
    sageBg: TpSystemColorsLight.tertiary,
    pink: TpSystemColorsLight.secondaryLabel,
    pinkDeep: TpSystemColorsLight.label,
    pinkSubtle: TpSystemColorsLight.tertiary,
    pinkBg: TpSystemColorsLight.tertiary,
    success: TpSystemColorsLight.success,
    warning: TpSystemColorsLight.warning,
  );

  static const systemDark = TpTones(
    accent: TpSystemColorsDark.tint,
    accentDeep: TpSystemColorsDark.tintDeep,
    accentSubtle: TpSystemColorsDark.tintSubtle,
    accentBg: TpSystemColorsDark.tintBackground,
    sage: TpSystemColorsDark.secondaryLabel,
    sageDeep: TpSystemColorsDark.label,
    sageSubtle: TpSystemColorsDark.tertiary,
    sageBg: TpSystemColorsDark.tertiary,
    pink: TpSystemColorsDark.secondaryLabel,
    pinkDeep: TpSystemColorsDark.label,
    pinkSubtle: TpSystemColorsDark.tertiary,
    pinkBg: TpSystemColorsDark.tertiary,
    success: TpSystemColorsDark.success,
    warning: TpSystemColorsDark.warning,
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

/// Tripline ThemeData 工廠。
///
/// 字型不指定 fontFamily → 走各平台系統字(iOS: SF Pro、Android: Roboto,
/// CJK 由系統 PingFang/Noto 自動 fallback),最貼 HIG 且拿到真 Dynamic Type。
abstract final class AppTheme {
  /// 尚未遷移畫面使用的既有淺色主題。
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

  /// 尚未遷移畫面使用的既有深色主題。
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
      surface: TpColorsDark.background,
      surfaceContainerLow: TpColorsDark.secondary,
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

  /// Welcome／Login 參考流程使用的 HIG 淺色主題。
  static ThemeData higLight({bool highContrast = false}) {
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
      tones: TpTones.systemLight,
      hover: TpSystemColorsLight.hover,
      disabled: highContrast
          ? const Color(0xB33C3C43)
          : TpSystemColorsLight.disabled,
      scaffoldBackground: TpSystemColorsLight.background,
      systemFoundation: true,
    );
  }

  /// Welcome／Login 參考流程使用的 HIG 深色主題。
  static ThemeData higDark({bool highContrast = false}) {
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
      tones: TpTones.systemDark,
      hover: TpSystemColorsDark.hover,
      disabled: highContrast
          ? const Color(0xB3EBEBF5)
          : TpSystemColorsDark.disabled,
      scaffoldBackground: TpSystemColorsDark.background,
      systemFoundation: true,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required TpTones tones,
    required Color hover,
    required Color disabled,
    required Color scaffoldBackground,
    bool systemFoundation = false,
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: iconButtonMinSize),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 0,
        backgroundColor: systemFoundation
            ? colorScheme.surfaceContainerHigh
            : tones.accentSubtle,
        selectedColor: systemFoundation ? tones.accentSubtle : tones.accent,
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
