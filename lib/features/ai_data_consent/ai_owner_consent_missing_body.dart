/// 旅伴被 owner 缺同意擋下時的說明本體（只告知，沒有同意動作）。
library;

import 'package:flutter/material.dart';

import '../../app/adaptive.dart';
import '../../theme/tokens.dart';

/// 旅伴被行程 owner 的缺同意擋下時的標題與說明（對齊 web）。
const kAiOwnerConsentMissingTitle = '暫時無法使用 AI 助理';
const kAiOwnerConsentMissingLead = '行程擁有者尚未同意 AI 資料處理。';

class AiOwnerConsentMissingBody extends StatefulWidget {
  const AiOwnerConsentMissingBody({
    super.key,
    required this.controller,
    required this.inputKept,
  });

  final AppSheetFormController controller;
  final bool inputKept;

  @override
  State<AiOwnerConsentMissingBody> createState() =>
      AiOwnerConsentMissingBodyState();
}

class AiOwnerConsentMissingBodyState extends State<AiOwnerConsentMissingBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.attach(() async => true);
      widget.controller.update(dirty: false, canSubmit: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s5),
      children: [
        Container(
          key: const ValueKey('ai-data-consent-owner-missing'),
          padding: const EdgeInsets.all(TpSpacing.s3),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(TpRadius.md),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: kAiOwnerConsentMissingLead,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: '這個行程的內容屬於擁有者，需要他同意後，AI 才能處理你的要求。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: TpSpacing.s3),
        Text(
          '${widget.inputKept ? '你的訊息已保留，沒有送出。' : '這次操作沒有執行。'}'
          '請通知行程擁有者到「帳號設定 → AI 與資料」同意；其餘功能（手動編輯、共同編輯）不受影響。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
