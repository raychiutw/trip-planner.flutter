/// 「保留你的版本？」覆寫確認：停留點、筆記、交通三處共用，用字與結構只在這裡定義。
library;

import 'package:flutter/widgets.dart';

import '../../../app/adaptive.dart';

/// 協作者也改了同一處時，問使用者是否以自己的版本覆蓋。
///
/// [what] 是協作者改動的對象（具體欄位名稱，與橫幅點名的同一份來源；交通是「交通設定」），是三處唯一差異的地方。
Future<bool> confirmKeepMyVersion(
  BuildContext context, {
  required String what,
}) {
  return showAppDestructiveConfirm(
    context,
    source: TpDestructiveConfirmSource.direct,
    title: '保留你的版本？',
    // 句號後固定換行：自然折行會把「你／的版本」拆在兩行。
    message: '協作者也修改了$what。\n繼續會以你的版本覆蓋對方的版本。',
    confirmLabel: '保留我的版本',
    cancelLabel: '繼續編輯',
  );
}
