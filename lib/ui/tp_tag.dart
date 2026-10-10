import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 非互動的資訊標籤(狀態、數量、時間、分類等唯讀小膠囊)。
///
/// 與 [TpChip] 的分界:`TpChip` 是按鈕語意(可點、可聚焦、停用時變淡),
/// 唯讀資訊不得拿它傳 `onPressed: null` 充數 —— 那會讓文字變成停用樣式
/// (對比不足),VoiceOver 也會報成「已停用的按鈕」。本元件只是一段帶底色的
/// 文字:無手勢、無焦點、語意為純文字,文字永遠是完整不透明度。
///
/// [emphasized] 為重點標籤(例如高嚴重度、已知動作),沿用 `TpChip` 選中態的
/// `primaryContainer` 底色與 `onPrimaryContainer` 文字,但不畫 `primary` 邊框,
/// 以免看起來像可選取的選項。標籤文字可換行,Dynamic Type 放大時不會溢位。
class TpTag extends StatelessWidget {
  const TpTag({super.key, required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(TpRadius.pill),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s3,
          vertical: TpSpacing.s1,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: emphasized ? scheme.onPrimaryContainer : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
