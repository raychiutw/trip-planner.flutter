import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/adaptive.dart';
import '../../theme/tokens.dart';

/// 在第一次送出 AI 指令前顯示明確的 owner 授權說明。
Future<bool> showAiConsentSheet(
  BuildContext context, {
  required String message,
  required Future<bool> Function() onAuthorize,
}) async {
  final controller = AppSheetFormController();
  try {
    return await showAppFormSheet(
          context,
          title: '授權 Tripline AI',
          titleKey: const ValueKey('ai-consent-title'),
          submitLabel: '允許',
          submitKey: const ValueKey('ai-consent-authorize'),
          cancelKey: const ValueKey('ai-consent-cancel'),
          controller: controller,
          builder: (_) => _AiConsentForm(
            controller: controller,
            message: message,
            onAuthorize: onAuthorize,
          ),
        ) ??
        false;
  } finally {
    controller.dispose();
  }
}

class _AiConsentForm extends StatefulWidget {
  const _AiConsentForm({
    required this.controller,
    required this.message,
    required this.onAuthorize,
  });

  final AppSheetFormController controller;
  final String message;
  final Future<bool> Function() onAuthorize;

  @override
  State<_AiConsentForm> createState() => _AiConsentFormState();
}

class _AiConsentFormState extends State<_AiConsentForm> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.attach(_authorize);
      widget.controller.update(dirty: false, canSubmit: true);
    });
  }

  Future<bool> _authorize() async {
    setState(() => _error = null);
    try {
      final authorized = await widget.onAuthorize();
      if (!mounted) return false;
      if (!authorized) {
        setState(() => _error = '授權未完成，訊息尚未送出。');
      }
      return authorized;
    } on Exception {
      if (mounted) setState(() => _error = '授權失敗，請稍後再試。');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s5),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: TpSpacing.tapMin,
            height: TpSpacing.tapMin,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(TpRadius.md),
            ),
            child: Icon(
              CupertinoIcons.sparkles,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: TpSpacing.s4),
        Text(
          'AI 會代表你讀取並調整這趟行程。授權後，以下訊息才會送出：',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TpSpacing.s3),
        Container(
          key: const ValueKey('ai-consent-message'),
          padding: const EdgeInsets.all(TpSpacing.s3),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(TpRadius.md),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Text(
            '「${widget.message}」',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: TpSpacing.s3),
          Text(
            _error!,
            key: const ValueKey('ai-consent-error'),
            style: TextStyle(color: colors.error),
          ),
        ],
      ],
    );
  }
}
