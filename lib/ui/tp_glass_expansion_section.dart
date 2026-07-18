import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';

/// 共用的可展開 Liquid Glass 區塊。
///
/// 用於「點一列後在原位置展開內容」的介面。外層材質統一委派
/// [TpGlassSurface]／套件 GlassContainer；淺色維持 Tripline 暖白，深色維持
/// 中性深色，頁面不再各自用實心 Container 包 ExpansionTile。
class TpGlassExpansionSection extends StatelessWidget {
  const TpGlassExpansionSection({
    super.key,
    required this.title,
    required this.children,
    this.leading,
    this.initiallyExpanded = false,
    this.margin = EdgeInsets.zero,
    this.tilePadding = const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
    this.childrenPadding = const EdgeInsets.fromLTRB(
      TpSpacing.s4,
      0,
      TpSpacing.s4,
      TpSpacing.s4,
    ),
    this.iconColor,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> children;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry tilePadding;
  final EdgeInsetsGeometry childrenPadding;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedIconColor = iconColor ?? theme.colorScheme.onSurfaceVariant;
    final tint = isDark
        ? TpColorsDark.glass.withValues(alpha: 0.48)
        : TpColorsLight.background.withValues(alpha: 0.52);

    return Padding(
      padding: margin,
      child: TpGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.xl)),
        tintColor: tint,
        blurSigma: 18,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            shape: const Border(),
            collapsedShape: const Border(),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            tilePadding: tilePadding,
            childrenPadding: childrenPadding,
            iconColor: resolvedIconColor,
            collapsedIconColor: resolvedIconColor,
            leading: leading,
            title: title,
            children: children,
          ),
        ),
      ),
    );
  }
}
