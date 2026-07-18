/// 衝突解決表單：先逐筆選擇保留版本，再一次套用。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/cache/cache_store.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../theme/tokens.dart';
import '../trip_detail/trip_providers.dart';
import 'offline_sync.dart';

enum _ConflictChoice { ours, theirs }

Future<void> showConflictResolveSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = AppSheetFormController();
  try {
    await showAppFormSheet(
      context,
      title: '同步衝突',
      submitLabel: '套用所選版本',
      submitKey: const ValueKey('conflict-apply'),
      controller: controller,
      builder: (_) => _ConflictResolveForm(controller: controller),
    );
  } finally {
    controller.dispose();
  }
}

void _invalidateTripFamilies(WidgetRef ref) {
  ref.invalidate(tripDetailProvider);
  ref.invalidate(tripDaysProvider);
  ref.invalidate(tripNotesProvider);
  ref.invalidate(tripSegmentsProvider);
  ref.invalidate(entryDetailProvider);
}

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

String _conflictTitle(ConflictRecord conflict) {
  final argTitle = conflict.args['title'];
  if (argTitle is String && argTitle.isNotEmpty) return argTitle;
  final oursTitle = conflict.ours['title'];
  if (oursTitle is String && oursTitle.isNotEmpty) return oursTitle;
  return '${conflict.type} · ${conflict.path}';
}

String _displayValue(Object? value) {
  if (value == null) return '(空)';
  final text = value.toString();
  return text.isEmpty ? '(空)' : text;
}

class _ConflictResolveForm extends ConsumerStatefulWidget {
  const _ConflictResolveForm({required this.controller});

  final AppSheetFormController controller;

  @override
  ConsumerState<_ConflictResolveForm> createState() =>
      _ConflictResolveFormState();
}

class _ConflictResolveFormState extends ConsumerState<_ConflictResolveForm> {
  final Map<String, _ConflictChoice> _choices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.attach(_apply);
      _syncFormState();
    });
  }

  void _syncFormState() {
    widget.controller.update(
      dirty: _choices.isNotEmpty,
      canSubmit: _choices.isNotEmpty,
    );
  }

  void _select(String id, _ConflictChoice choice) {
    setState(() => _choices[id] = choice);
    _syncFormState();
  }

  Future<bool> _apply() async {
    final conflicts = ref.read(syncConflictRecordsProvider).value ?? const [];
    try {
      for (final conflict in conflicts) {
        switch (_choices[conflict.id]) {
          case _ConflictChoice.ours:
            await ref.read(apiClientProvider).resolveConflictKeepOurs(conflict);
          case _ConflictChoice.theirs:
            await ref
                .read(apiClientProvider)
                .resolveConflictKeepTheirs(conflict);
          case null:
            continue;
        }
      }
      _invalidateTripFamilies(ref);
      return true;
    } on Exception {
      if (mounted) showAppNotice(context, '仍離線，稍後重試');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final conflicts = ref.watch(syncConflictRecordsProvider).value ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s2,
        TpSpacing.s4,
        TpSpacing.s4,
      ),
      children: [
        Text(
          '這些變更與雲端版本不一致，請逐筆選擇要保留的版本。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: TpSpacing.s4),
        if (conflicts.isEmpty)
          Text(
            '沒有待解決衝突',
            key: const ValueKey('conflict-empty'),
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          for (var index = 0; index < conflicts.length; index++) ...[
            if (index > 0) const SizedBox(height: TpSpacing.s3),
            _ConflictCard(
              conflict: conflicts[index],
              choice: _choices[conflicts[index].id],
              onSelected: (choice) => _select(conflicts[index].id, choice),
            ),
          ],
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.choice,
    required this.onSelected,
  });

  final ConflictRecord conflict;
  final _ConflictChoice? choice;
  final ValueChanged<_ConflictChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final conflict = this.conflict;
    return Card(
      key: ValueKey('conflict-card-${conflict.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _conflictTitle(conflict),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TpSpacing.s3),
            for (final field in conflict.conflictFields) ...[
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
                      value: _displayValue(conflict.ours[field]),
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  Expanded(
                    child: _SideValue(
                      label: '對方',
                      value: _displayValue(conflict.theirs[field]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TpSpacing.s3),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                choice == _ConflictChoice.theirs
                    ? FilledButton(
                        key: ValueKey('conflict-keep-theirs-${conflict.id}'),
                        onPressed: () => onSelected(_ConflictChoice.theirs),
                        child: const Text('用對方的'),
                      )
                    : OutlinedButton(
                        key: ValueKey('conflict-keep-theirs-${conflict.id}'),
                        onPressed: () => onSelected(_ConflictChoice.theirs),
                        child: const Text('用對方的'),
                      ),
                const SizedBox(width: TpSpacing.s2),
                choice == _ConflictChoice.ours
                    ? FilledButton(
                        key: ValueKey('conflict-keep-ours-${conflict.id}'),
                        onPressed: () => onSelected(_ConflictChoice.ours),
                        child: const Text('保留你的'),
                      )
                    : OutlinedButton(
                        key: ValueKey('conflict-keep-ours-${conflict.id}'),
                        onPressed: () => onSelected(_ConflictChoice.ours),
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
