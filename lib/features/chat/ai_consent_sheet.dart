import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// 在第一次送出 AI 指令前顯示明確的 owner 授權說明。
Future<bool> showAiConsentSheet(
  BuildContext context, {
  required String message,
  required Future<bool> Function() onAuthorize,
}) async {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isApple) {
    return await showCupertinoModalPopup<bool>(
          context: context,
          barrierDismissible: true,
          builder: (sheetContext) =>
              _AiConsentSheet(message: message, onAuthorize: onAuthorize),
        ) ??
        false;
  }
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) =>
            _AiConsentSheet(message: message, onAuthorize: onAuthorize),
      ) ??
      false;
}

class _AiConsentSheet extends StatefulWidget {
  const _AiConsentSheet({required this.message, required this.onAuthorize});

  final String message;
  final Future<bool> Function() onAuthorize;

  @override
  State<_AiConsentSheet> createState() => _AiConsentSheetState();
}

class _AiConsentSheetState extends State<_AiConsentSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _authorize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authorized = await widget.onAuthorize();
      if (!mounted) return;
      if (authorized) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = '授權未完成，訊息尚未送出。');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '授權失敗，請稍後再試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tones = theme.extension<TpTones>()!;
    return PopScope(
      canPop: !_busy,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 560),
              padding: EdgeInsets.fromLTRB(
                TpSpacing.s5,
                TpSpacing.s3,
                TpSpacing.s5,
                TpSpacing.s4 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(TpRadius.xl),
                ),
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: TpSpacing.s4),
                  Row(
                    children: [
                      Container(
                        width: TpSpacing.tapMin,
                        height: TpSpacing.tapMin,
                        decoration: BoxDecoration(
                          color: tones.accentSubtle,
                          borderRadius: BorderRadius.circular(TpRadius.md),
                        ),
                        child: Icon(
                          CupertinoIcons.sparkles,
                          color: tones.accentDeep,
                        ),
                      ),
                      const SizedBox(width: TpSpacing.s3),
                      Expanded(
                        child: Text(
                          '授權 Tripline AI',
                          key: const ValueKey('ai-consent-title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TpSpacing.s3),
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
                  const SizedBox(height: TpSpacing.s4),
                  FilledButton(
                    key: const ValueKey('ai-consent-authorize'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(TpSpacing.tapMin),
                    ),
                    onPressed: _busy ? null : _authorize,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('授權並送出'),
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  TextButton(
                    key: const ValueKey('ai-consent-cancel'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(TpSpacing.tapMin),
                    ),
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
