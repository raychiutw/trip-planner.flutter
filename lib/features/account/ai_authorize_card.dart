import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// 可重用的 Tripline AI owner 授權卡。
class AiAuthorizeCard extends ConsumerStatefulWidget {
  const AiAuthorizeCard({super.key, this.onAuthorized});

  final VoidCallback? onAuthorized;

  @override
  ConsumerState<AiAuthorizeCard> createState() => _AiAuthorizeCardState();
}

class _AiAuthorizeCardState extends ConsumerState<AiAuthorizeCard> {
  bool? _authorized;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final authorized = await ref
          .read(authRepositoryProvider)
          .fetchAiAuthorization();
      if (mounted) setState(() => _authorized = authorized);
    } catch (_) {
      if (mounted) setState(() => _authorized = false);
    }
  }

  Future<void> _authorize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authorized = await ref.read(authRepositoryProvider).authorizeAi();
      if (!mounted) return;
      setState(() {
        _authorized = authorized;
        if (!authorized) _error = '授權未完成，請再試一次。';
      });
      if (authorized) widget.onAuthorized?.call();
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
    return Card(
      key: const ValueKey('ai-authorize-card'),
      color: tones.accentSubtle,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TpRadius.md),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.sparkles, color: tones.accentDeep),
                const SizedBox(width: TpSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '讓 AI 幫你把行程填滿',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: TpSpacing.s1),
                      Text(
                        '授權一次，AI 就能以你的身分安排景點、餐廳、交通。',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_authorized == true) ...[
              const SizedBox(height: TpSpacing.s3),
              Row(
                key: const ValueKey('ai-authorize-on'),
                children: [
                  Icon(
                    CupertinoIcons.check_mark_circled,
                    color: tones.accentDeep,
                    size: 20,
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  const Expanded(child: Text('已授權 · 可隨時在「已連結應用」撤銷')),
                ],
              ),
            ] else if (_authorized == false) ...[
              const SizedBox(height: TpSpacing.s3),
              FilledButton(
                key: const ValueKey('ai-authorize-btn'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(TpSpacing.tapMin),
                ),
                onPressed: _busy ? null : _authorize,
                child: Text(_busy ? '授權中⋯' : '授權 AI'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(
                _error!,
                key: const ValueKey('ai-authorize-error'),
                style: TextStyle(color: colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
