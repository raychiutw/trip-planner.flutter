/// 離線狀態列:有未同步變更時顯示「N 筆待同步 + 立即重試」;有衝突時顯示衝突提示。
/// 放在 app shell 內容與底部導航之間;無事時不佔空間。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import 'conflict_resolve_sheet.dart';
import 'offline_sync.dart';

class OfflineStatusBanner extends ConsumerWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final conflictCount =
        ref.watch(syncConflictRecordsProvider).value?.length ?? 0;
    final pending = ref.watch(offlinePendingCountProvider).value ?? 0;
    final syncing = ref.watch(offlineSyncControllerProvider).isLoading;

    // 衝突優先:同步衝突(OCC 真衝突)需使用者逐筆解決。
    if (conflictCount > 0) {
      return _Bar(
        key: const ValueKey('offline-conflict-banner'),
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        icon: CupertinoIcons.exclamationmark_circle,
        text: '$conflictCount 筆同步衝突',
        actionLabel: '檢視',
        onAction: () => showConflictResolveSheet(context, ref),
      );
    }

    if (pending > 0) {
      return _Bar(
        key: const ValueKey('offline-pending-banner'),
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        icon: Icons.cloud_off_outlined,
        text: '$pending 筆變更待同步',
        busy: syncing,
        actionLabel: syncing ? null : '立即重試',
        onAction: () => ref.read(offlineSyncControllerProvider.notifier).sync(),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TpSpacing.s4,
            vertical: TpSpacing.s2,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: TpSpacing.s2),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: foreground),
                ),
              ),
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              else if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
