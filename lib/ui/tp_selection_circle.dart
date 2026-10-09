import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 選取模式的圓形勾選鈕(iOS 清單多選樣式),取代 Material 的 `Checkbox`。
///
/// 未選是空心圓、已選是實心勾選圓(tint 色)。語意為 checked,點擊區 44pt。
/// [onChanged] 為 null 時停用。
class TpSelectionCircle extends StatelessWidget {
  const TpSelectionCircle({
    super.key,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool selected;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final color = !enabled
        ? scheme.onSurface.withAlpha(97)
        : selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return Semantics(
      label: semanticLabel,
      checked: selected,
      enabled: enabled,
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!selected) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!selected) : null,
        child: SizedBox.square(
          dimension: TpSpacing.tapMin,
          child: Center(
            child: Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 24,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
