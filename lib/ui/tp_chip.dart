import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_tap_target.dart';

/// 膠囊選項／快捷鈕,取代 Material 的 `FilterChip`／`ChoiceChip`／`ActionChip`。
///
/// 不帶 Material 的 elevation、勾選圖示與 ripple;選中狀態以 `primaryContainer`
/// 填色加 `primary` 邊框表達(CODING_STANDARDS.md「取色與視覺階層」登記的 tint
/// 填色例外),語意為 button + selected,可聚焦、Enter／Space 啟動。點擊區固定
/// 至少 44×44,視覺膠囊較矮、置中。
class TpChip extends StatelessWidget {
  const TpChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final bool selected;

  /// 為 null 時停用。
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final textColor = enabled
        ? foreground
        : scheme.onSurface.withAlpha(TpDisabled.contentAlpha);

    return TpTapTarget(
      onTap: onPressed,
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      minWidth: TpSpacing.tapMin,
      focusRadius: TpRadius.pill,
      child: Align(
        widthFactor: 1,
        child: DecoratedBox(
          key: const ValueKey('tp-chip-surface'),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(TpRadius.pill),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s3,
              vertical: TpSpacing.s2,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
