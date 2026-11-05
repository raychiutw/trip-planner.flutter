/// AI 資料同意說明的唯讀區塊：狀態橫幅與 server 提供的章節。
library;

import 'package:flutter/material.dart';

import '../../models/ai_data_consent.dart';
import '../../theme/tokens.dart';

/// 說明已更新（stale）／已撤回（withdrawn）的提示；其他狀態不顯示。
class AiDataConsentStatusBanner extends StatelessWidget {
  const AiDataConsentStatusBanner({super.key, required this.status});

  final AiDataConsentStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      AiDataConsentStatus.stale => '說明已更新：請重新確認後才能繼續使用 AI。你仍可使用不需要 AI 的功能。',
      AiDataConsentStatus.withdrawn => '你先前已撤回同意。要再使用 AI 助理，請重新同意。',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('ai-data-consent-banner'),
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Text(text),
    );
  }
}

/// server 提供的章節；第一個預設展開（對齊 web）。
class AiDataConsentSections extends StatelessWidget {
  const AiDataConsentSections({super.key, required this.consent});

  final AiDataConsent consent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (i, section) in consent.text.sections.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: TpSpacing.s2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TpRadius.md),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(section.heading, style: theme.textTheme.titleSmall),
              childrenPadding: const EdgeInsets.fromLTRB(
                TpSpacing.s4,
                0,
                TpSpacing.s4,
                TpSpacing.s3,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in section.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TpSpacing.s1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
