/// 帳號設定「AI 與資料」：查看 AI 資料同意的狀態、版本與時間，重新同意或撤回。
///
/// 說明文字與版本全部來自 server（[aiDataConsentProvider]）；撤回時照 server 提供的
/// 撤回說明如實告知（已開始的工作不保證能停、已送出的資料收不回來），不寫「立即停止」。
/// 與「AI 操作授權」（已連結的應用程式裡的授權卡）是兩個獨立概念。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/adaptive.dart';
import '../../app/adaptive_content.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/ai_data_consent.dart';
import '../../models/display_format.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_settings_group.dart';
import 'ai_data_consent_controller.dart';
import 'ai_data_consent_sections.dart';
import 'ai_data_consent_sheet.dart';

String aiDataConsentHeadline(AiDataConsentStatus status) => switch (status) {
  AiDataConsentStatus.valid => 'AI 助理已開啟',
  AiDataConsentStatus.stale => 'AI 助理已暫停：說明已更新',
  AiDataConsentStatus.withdrawn => 'AI 助理已關閉',
  AiDataConsentStatus.none => 'AI 助理尚未開啟',
};

class AiDataSettingsScreen extends ConsumerStatefulWidget {
  const AiDataSettingsScreen({super.key});

  @override
  ConsumerState<AiDataSettingsScreen> createState() =>
      _AiDataSettingsScreenState();
}

class _AiDataSettingsScreenState extends ConsumerState<AiDataSettingsScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _consent(AiDataConsent consent) async {
    setState(() => _error = null);
    await showAiDataConsentSheet(context, initial: consent);
  }

  Future<void> _withdraw(AiDataConsent consent) async {
    final confirmed = await showAppDestructiveConfirm(
      context,
      source: TpDestructiveConfirmSource.direct,
      title: '撤回 AI 資料同意？',
      message: consent.text.withdrawal.join('\n'),
      confirmLabel: '撤回同意',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await aiConsentActionError(
      () => ref.read(aiDataConsentProvider.notifier).withdraw(),
      failure: '撤回失敗，請稍後再試。',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) showAppNotice(context, '已撤回 AI 資料同意');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aiDataConsentProvider);
    return Scaffold(
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('AI 與資料')),
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.form,
        child: async.when(
          loading: () => const AppListLoadingSkeleton(
            key: ValueKey('ai-data-settings-loading'),
            itemCount: 3,
          ),
          error: (_, _) => _Unavailable(onRetry: _retry),
          data: (consent) => consent == null
              ? _Unavailable(onRetry: _retry)
              : _Body(
                  consent: consent,
                  busy: _busy,
                  error: _error,
                  onConsent: () => unawaited(_consent(consent)),
                  onWithdraw: () => unawaited(_withdraw(consent)),
                ),
        ),
      ),
    );
  }

  void _retry() => ref.invalidate(aiDataConsentProvider);
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('ai-data-settings-unavailable'),
    child: Padding(
      padding: const EdgeInsets.all(TpSpacing.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('暫時無法取得 AI 資料同意的狀態。', textAlign: TextAlign.center),
          const SizedBox(height: TpSpacing.s3),
          TextButton(
            key: const ValueKey('ai-data-settings-retry'),
            onPressed: onRetry,
            child: const Text('重試'),
          ),
        ],
      ),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.consent,
    required this.busy,
    required this.error,
    required this.onConsent,
    required this.onWithdraw,
  });

  final AiDataConsent consent;
  final bool busy;
  final String? error;
  final VoidCallback onConsent;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final valid = consent.status == AiDataConsentStatus.valid;
    final acceptedAt = consent.acceptedAt;
    final lead = valid && acceptedAt != null
        ? '你在 ${formatUtcTimestamp(acceptedAt)} 同意了這個版本。'
        : '同意前，AI 聊天、行程健檢與 AI 筆記無法使用；其餘功能不受影響。';
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            aiDataConsentHeadline(consent.status),
            key: const ValueKey('ai-data-settings-status'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (valid)
          Text(
            '版本 ${consent.acceptedVersion}',
            key: const ValueKey('ai-data-settings-accepted-version'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: TpSpacing.s2),
        Text(
          lead,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TpSpacing.s4),
        Text(
          '目前的說明（版本 ${consent.currentVersion}）',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: TpSpacing.s2),
        Text(consent.text.intro),
        const SizedBox(height: TpSpacing.s3),
        AiDataConsentSections(consent: consent),
        const SizedBox(height: TpSpacing.s3),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: TpSpacing.s3),
            child: Text(
              error!,
              key: const ValueKey('ai-data-settings-error'),
              style: TextStyle(color: colors.error),
            ),
          ),
        TpGroupedSurface(
          children: [
            if (valid)
              TpSettingsRow(
                key: const ValueKey('ai-data-settings-withdraw'),
                title: '撤回同意',
                destructive: true,
                // 動作列（跳確認框／開 sheet）不是導航，不畫「往下一層」的 chevron。
                trailing: const SizedBox.shrink(),
                onTap: busy ? null : onWithdraw,
              )
            else
              TpSettingsRow(
                key: const ValueKey('ai-data-settings-consent'),
                title: '查看說明並同意',
                trailing: const SizedBox.shrink(),
                onTap: busy ? null : onConsent,
              ),
          ],
        ),
      ],
    );
  }
}
