import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _padding = EdgeInsets.symmetric(
  horizontal: TpSpacing.s5,
  vertical: TpSpacing.s2 + 2,
);
const _fontSize = 15.0;

/// 主要動作鈕,底層是 [CupertinoButton](按下淡出、無 ripple),顏色取自
/// `colorScheme`(`primary`／`onPrimary`),停用時沿用 Cupertino 的停用處理。
class TpFilledButton extends StatelessWidget {
  const TpFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tonal = false,
  });

  final String label;

  /// 為 null 時停用。
  final VoidCallback? onPressed;

  /// true 時改用 `primaryContainer` 淡底(次要選項),否則是 `primary` 實底。
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: _button(scheme),
    );
  }

  Widget _button(ColorScheme scheme) {
    return CupertinoButton(
      color: tonal ? scheme.primaryContainer : scheme.primary,
      disabledColor: scheme.onSurface.withAlpha(TpDisabled.fillAlpha),
      minimumSize: const Size(0, TpSpacing.tapMin),
      padding: _padding,
      borderRadius: BorderRadius.circular(TpRadius.md),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: onPressed == null
              ? scheme.onSurface.withAlpha(TpDisabled.contentAlpha)
              : (tonal ? scheme.onPrimaryContainer : scheme.onPrimary),
        ),
      ),
    );
  }
}
