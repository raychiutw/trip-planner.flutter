/// 旅伴被 owner 缺同意擋下時的純告知 alert（沒有同意動作，那是 owner 自己的決定）。
library;

import 'package:flutter/widgets.dart';

import '../../app/adaptive.dart';

/// 標題與說明對齊 web。
const _title = '暫時無法使用 AI 助理';
const _lead = '行程擁有者尚未同意 AI 資料處理，';

/// 純告知用 alert（只有一個「知道了」）：沒有「同意」動作，那是 owner 自己的決定。
Future<void> showAiOwnerConsentMissingAlert(
  BuildContext context, {
  bool inputKept = false,
}) {
  return showAppAlert(
    context,
    title: _title,
    message:
        '$_lead所以 AI 暫時無法處理你的要求。\n\n'
        '${inputKept ? '你的訊息已保留，沒有送出。' : '這次操作沒有執行。'}'
        '請通知擁有者到「帳號設定 → AI 與資料」同意；手動編輯、共同編輯不受影響。',
    actionLabel: '知道了',
    key: const ValueKey('ai-data-consent-owner-missing'),
  );
}
