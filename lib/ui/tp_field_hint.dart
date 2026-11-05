import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 欄位下方的說明或提示字：內縮 16 對齊欄位內文，頂端留 [TpSpacing.s1]。
///
/// 表單的未填說明、同意提示共用，避免各處自己抓內縮。
class TpFieldHint extends StatelessWidget {
  const TpFieldHint(this.text, {super.key, this.textKey, this.color});

  final String text;

  /// 給測試找文字用（外層的 [key] 掛在 Padding 上）。
  final Key? textKey;

  /// 預設是 `onSurfaceVariant`；錯誤提示傳 `colorScheme.error`。
  final Color? color;

  /// 欄位文字的水平內縮（OutlineInputBorder 的 contentPadding 是 16；量過截圖，12 會比欄位內文偏左）。
  static const _inset = TpSpacing.s4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: _inset,
        top: TpSpacing.s1,
      ),
      child: Text(
        text,
        key: textKey,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color ?? scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
