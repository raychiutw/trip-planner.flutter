/// 就地「AI 資料同意」sheet 的入口：受管制入口被擋時在原畫面同意，同意後由呼叫端接續原操作。
///
/// 說明文字與版本全部來自 server（[aiDataConsentProvider]），App 不寫死。
/// 與「AI 操作授權」sheet（`showAiAuthorizationSheet`）是兩個獨立概念。
library;

import 'package:flutter/material.dart';

import '../../app/adaptive.dart';
import '../../models/ai_data_consent.dart';
import 'ai_data_consent_controller.dart';
import 'ai_data_consent_form.dart';

/// 旅伴被行程 owner 的缺同意擋下時的標題與說明（對齊 web）。
const kAiOwnerConsentMissingTitle = '暫時無法使用 AI 助理';
const kAiOwnerConsentMissingLead = '行程擁有者尚未同意 AI 資料處理，';

/// 回傳 true = 已同意（server 已儲存）；false／null = 使用者沒有同意。
Future<bool> showAiDataConsentSheet(
  BuildContext context, {
  required AiDataConsent initial,
  String? keptMessage,
}) async {
  final controller = AppSheetFormController();
  try {
    return await showAppFormSheet(
          context,
          title: 'AI 資料同意',
          titleKey: const ValueKey('ai-data-consent-title'),
          submitLabel: '同意並繼續',
          submitKey: const ValueKey('ai-data-consent-accept'),
          cancelKey: const ValueKey('ai-data-consent-cancel'),
          controller: controller,
          builder: (_) => AiDataConsentForm(
            controller: controller,
            initial: initial,
            keptMessage: keptMessage,
          ),
        ) ??
        false;
  } finally {
    controller.dispose();
  }
}

/// 純告知用 alert（只有一個「知道了」）：沒有「同意」動作，那是 owner 自己的決定。
Future<void> showAiOwnerConsentMissingAlert(
  BuildContext context, {
  bool inputKept = false,
}) {
  return showAppAlert(
    context,
    title: kAiOwnerConsentMissingTitle,
    message:
        '$kAiOwnerConsentMissingLead所以 AI 暫時無法處理你的要求。\n\n'
        '${inputKept ? '你的訊息已保留，沒有送出。' : '這次操作沒有執行。'}'
        '請通知擁有者到「帳號設定 → AI 與資料」同意；手動編輯、共同編輯不受影響。',
    actionLabel: '知道了',
    key: const ValueKey('ai-data-consent-owner-missing'),
  );
}
