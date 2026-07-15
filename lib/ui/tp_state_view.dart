import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum TpStateKind { loading, empty, noResults, offline, permission, error }

class TpStateView extends StatelessWidget {
  const TpStateView({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be provided together.',
       );

  final TpStateKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _icon => switch (kind) {
    TpStateKind.loading => CupertinoIcons.clock,
    TpStateKind.empty => CupertinoIcons.tray,
    TpStateKind.noResults => CupertinoIcons.search,
    TpStateKind.offline => CupertinoIcons.wifi_slash,
    TpStateKind.permission => CupertinoIcons.lock_shield,
    TpStateKind.error => CupertinoIcons.exclamationmark_triangle,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == TpStateKind.loading)
                const CircularProgressIndicator.adaptive()
              else
                Icon(
                  _icon,
                  size: 32,
                  color: kind == TpStateKind.error
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              const SizedBox(height: TpSpacing.s4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: TpSpacing.s2),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onAction != null) ...[
                const SizedBox(height: TpSpacing.s5),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
