/// 就地「AI 資料同意」sheet：受管制入口被擋時在原畫面同意，同意後由呼叫端接續原操作。
///
/// 說明文字與版本全部來自 server（[aiDataConsentProvider]），App 不寫死。
/// 與「AI 操作授權」sheet（`showAiConsentSheet`）是兩個獨立概念。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../app/adaptive.dart';
import '../../models/ai_data_consent.dart';
import '../../theme/tokens.dart';
import 'ai_data_consent_controller.dart';

/// 旅伴被行程 owner 的缺同意擋下時的標題與說明（對齊 web）。
const kAiOwnerConsentMissingTitle = '暫時無法使用 AI 助理';
const kAiOwnerConsentMissingLead = '行程擁有者尚未同意 AI 資料處理。';

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

/// 沒有「同意」動作：那是 owner 自己的決定，旅伴只被告知。
Future<void> showAiOwnerConsentMissingSheet(
  BuildContext context, {
  bool inputKept = false,
}) async {
  final controller = AppSheetFormController();
  try {
    await showAppFormSheet(
      context,
      title: kAiOwnerConsentMissingTitle,
      titleKey: const ValueKey('ai-data-consent-owner-title'),
      submitLabel: '知道了',
      submitKey: const ValueKey('ai-data-consent-owner-ok'),
      cancelKey: const ValueKey('ai-data-consent-owner-cancel'),
      controller: controller,
      builder: (_) =>
          _OwnerMissingBody(controller: controller, inputKept: inputKept),
    );
  } finally {
    controller.dispose();
  }
}

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

class AiDataConsentForm extends ConsumerStatefulWidget {
  const AiDataConsentForm({
    super.key,
    required this.controller,
    required this.initial,
    this.keptMessage,
  });

  final AppSheetFormController controller;
  final AiDataConsent initial;
  final String? keptMessage;

  @override
  ConsumerState<AiDataConsentForm> createState() => _AiDataConsentFormState();
}

class _AiDataConsentFormState extends ConsumerState<AiDataConsentForm> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.attach(_accept);
      widget.controller.update(dirty: false, canSubmit: true);
    });
  }

  Future<bool> _accept() async {
    setState(() => _error = null);
    try {
      await ref.read(aiDataConsentProvider.notifier).accept();
      return true;
    } on ApiError catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'AI_CONSENT_VERSION_MISMATCH'
              ? '說明已更新，請確認新版內容後再同意。'
              : '同意失敗，請稍後再試。',
        );
      }
      return false;
    } on Exception {
      if (mounted) setState(() => _error = '同意失敗，請稍後再試。');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 版本被更新後共用狀態會換成新說明；沒有時退回開 sheet 當下看到的那一份。
    final consent = ref.watch(aiDataConsentProvider).value ?? widget.initial;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s5),
      children: [
        // 標題放內文而不放 sheet 標題列：版本被更新後要能跟著換成新版文字。
        Text(
          consent.text.title,
          key: const ValueKey('ai-data-consent-text-title'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: TpSpacing.s2),
        AiDataConsentStatusBanner(status: consent.status),
        Text(
          consent.text.intro,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TpSpacing.s3),
        AiDataConsentSections(consent: consent),
        if (widget.keptMessage != null) ...[
          const SizedBox(height: TpSpacing.s2),
          Text(
            '你輸入的內容已保留，同意後會自動接續送出',
            key: const ValueKey('ai-data-consent-kept'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: TpSpacing.s2),
        Text(
          '版本 ${consent.currentVersion}',
          key: const ValueKey('ai-data-consent-version'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: TpSpacing.s3),
          Text(
            _error!,
            key: const ValueKey('ai-data-consent-error'),
            style: TextStyle(color: colors.error),
          ),
        ],
      ],
    );
  }
}

class _OwnerMissingBody extends StatefulWidget {
  const _OwnerMissingBody({required this.controller, required this.inputKept});

  final AppSheetFormController controller;
  final bool inputKept;

  @override
  State<_OwnerMissingBody> createState() => _OwnerMissingBodyState();
}

class _OwnerMissingBodyState extends State<_OwnerMissingBody> {
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
