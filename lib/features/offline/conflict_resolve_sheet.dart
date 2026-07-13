/// 衝突解決 bottom sheet:逐筆同步衝突讓使用者二選一(保留你的 / 用對方的)。
/// 真相源是持久化 conflict store(syncConflictRecordsProvider);解完反應式更新。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/cache/cache_store.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../theme/tokens.dart';
import '../trip_detail/trip_providers.dart';
import 'offline_sync.dart';

/// 開啟衝突解決 bottom sheet。
Future<void> showConflictResolveSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ConflictResolveSheet(),
  );
}

/// 解完衝突後讓行程相關讀取重跑,套用 server 真相(對齊 offline_sync.dart 清單)。
void _invalidateTripFamilies(WidgetRef ref) {
  ref.invalidate(tripDetailProvider);
  ref.invalidate(tripDaysProvider);
  ref.invalidate(tripNotesProvider);
  ref.invalidate(tripSegmentsProvider);
  ref.invalidate(entryDetailProvider);
}

/// 衝突欄位 → 人話標籤;未列的原樣顯示。
String _fieldLabel(String field) {
  switch (field) {
    case 'title':
      return '標題';
    case 'description':
      return '說明';
    case 'startTime':
      return '開始時間';
    case 'endTime':
      return '結束時間';
    default:
      return field;
  }
}

/// 衝突卡標題:優先用 args/ours 的 title;否則退回 type/path 摘要。
String _conflictTitle(ConflictRecord c) {
  final argTitle = c.args['title'];
  if (argTitle is String && argTitle.isNotEmpty) return argTitle;
  final oursTitle = c.ours['title'];
  if (oursTitle is String && oursTitle.isNotEmpty) return oursTitle;
  return '${c.type} · ${c.path}';
}

String _displayValue(Object? value) {
  if (value == null) return '(空)';
  final text = value.toString();
  return text.isEmpty ? '(空)' : text;
}

class _ConflictResolveSheet extends ConsumerWidget {
  const _ConflictResolveSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final conflicts = ref.watch(syncConflictRecordsProvider).value ?? [];

    // 清單空(已全解決)→ 關閉 sheet。
    if (conflicts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Text(
          '沒有待解決衝突',
          key: const ValueKey('conflict-empty'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TpSpacing.s4,
          0,
          TpSpacing.s4,
          TpSpacing.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('同步衝突', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s1),
            Text(
              '這些變更與雲端版本不一致,請逐筆選擇要保留的版本。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: conflicts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: TpSpacing.s3),
                itemBuilder: (_, i) => _ConflictCard(conflict: conflicts[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.conflict});

  final ConflictRecord conflict;

  Future<void> _keepOurs(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).resolveConflictKeepOurs(conflict);
      _invalidateTripFamilies(ref);
    } on Exception {
      if (context.mounted) {
        showAppNotice(context, '仍離線,稍後重試');
      }
    }
  }

  Future<void> _keepTheirs(BuildContext context, WidgetRef ref) async {
    await ref.read(apiClientProvider).resolveConflictKeepTheirs(conflict);
    _invalidateTripFamilies(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final c = conflict;

    return Card(
      key: ValueKey('conflict-card-${c.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _conflictTitle(c),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TpSpacing.s3),
            for (final field in c.conflictFields) ...[
              Text(
                _fieldLabel(field),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TpSpacing.s1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SideValue(
                      label: '你的',
                      value: _displayValue(c.ours[field]),
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  Expanded(
                    child: _SideValue(
                      label: '對方',
                      value: _displayValue(c.theirs[field]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TpSpacing.s3),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: ValueKey('conflict-keep-theirs-${c.id}'),
                  onPressed: () => _keepTheirs(context, ref),
                  child: const Text('用對方的'),
                ),
                const SizedBox(width: TpSpacing.s2),
                FilledButton(
                  key: ValueKey('conflict-keep-ours-${c.id}'),
                  onPressed: () => _keepOurs(context, ref),
                  child: const Text('保留你的'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 單側(你的 / 對方)欄位值,弱化標籤 + 值。
class _SideValue extends StatelessWidget {
  const _SideValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: TpSpacing.s1),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
