/// AI 資料同意 sheet 的表單本體：顯示說明、送出同意並回報錯誤。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/adaptive.dart';
import '../../models/ai_data_consent.dart';
import '../../theme/tokens.dart';
import 'ai_data_consent_controller.dart';
import 'ai_data_consent_sections.dart';

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
    final error = await aiConsentActionError(
      () => ref.read(aiDataConsentProvider.notifier).accept(),
      failure: '同意失敗，請稍後再試。',
    );
    if (mounted) setState(() => _error = error);
    return error == null;
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
