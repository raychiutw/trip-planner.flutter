import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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
    return CupertinoButton(
      color: tonal ? scheme.primaryContainer : scheme.primary,
      disabledColor: scheme.onSurface.withAlpha(31),
      minimumSize: const Size(0, TpSpacing.tapMin),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      borderRadius: BorderRadius.circular(TpRadius.md),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: onPressed == null
              ? scheme.onSurface.withAlpha(97)
              : (tonal ? scheme.onPrimaryContainer : scheme.onPrimary),
        ),
      ),
    );
  }
}
