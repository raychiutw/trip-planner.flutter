import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 表單內的紅底橫幅（`errorContainer`）：衝突、載入失敗等需要使用者留意的訊息。
///
/// 是 `liveRegion`，出現時輔助技術會朗讀。[action] 靠右放在文字下方（重試、另存等）。
/// 筆記、交通、停留點編輯 sheet 共用；帶邊框與圖示的頁面級面板是另一種元件，不用這個。
class TpInlineBanner extends StatelessWidget {
  const TpInlineBanner({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(TpSpacing.s3),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(TpSpacing.s3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: TextStyle(color: scheme.onErrorContainer)),
            if (action != null)
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        ),
      ),
    );
  }
}
