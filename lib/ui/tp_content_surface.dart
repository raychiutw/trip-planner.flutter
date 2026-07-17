import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class TpContentSurface extends StatelessWidget {
  const TpContentSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.color,
    this.padding = const EdgeInsets.all(TpSpacing.s4),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(padding: padding, child: child);
    return Semantics(
      container: true,
      button: onTap != null || onLongPress != null,
      label: semanticLabel,
      child: Material(
        color: color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TpRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
      ),
    );
  }
}
