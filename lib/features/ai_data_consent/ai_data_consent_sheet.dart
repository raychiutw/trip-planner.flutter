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
