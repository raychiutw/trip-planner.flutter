import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class TpGlassSurface extends StatelessWidget {
  const TpGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.padding = EdgeInsets.zero,
    this.tintColor,
    this.blurSigma = 22,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultTint = isDark
        ? TpColorsDark.background.withValues(alpha: highContrast ? 0.96 : 0.38)
        : Colors.white.withValues(alpha: highContrast ? 0.96 : 0.42);
    final tint = tintColor == null
        ? defaultTint
        : tintColor!.withValues(alpha: highContrast ? 0.96 : tintColor!.a);
    final border = isDark
        ? Colors.white.withValues(alpha: highContrast ? 0.64 : 0.34)
        : Colors.white.withValues(alpha: highContrast ? 1 : 0.94);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.34),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
