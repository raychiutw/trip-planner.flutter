import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/day.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import 'reorder_helpers.dart';
import 'trip_providers.dart';

/// Web 相容的停留點跨日操作。
enum EntryRouteAction { copy, move }

extension _EntryRouteActionX on EntryRouteAction {
  String get title => switch (this) {
    EntryRouteAction.copy => '複製停留點',
    EntryRouteAction.move => '移到其他 Day',
  };

  String get submitLabel => switch (this) {
    EntryRouteAction.copy => '複製',
    EntryRouteAction.move => '移動',
  };
}

/// Web 相容的停留點 copy/move 頁面。
class EntryActionRouteScreen extends ConsumerStatefulWidget {
  const EntryActionRouteScreen({
    super.key,
    required this.tripId,
    required this.entryId,
    required this.action,
  });

  final String tripId;
  final int entryId;
  final EntryRouteAction action;

  @override
  ConsumerState<EntryActionRouteScreen> createState() =>
      _EntryActionRouteScreenState();
}

class _EntryActionRouteScreenState
    extends ConsumerState<EntryActionRouteScreen> {
  final _dismissController = AppUnsavedChangesController();
  int? _targetDayId;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    final days = daysAsync.value ?? const <TripDay>[];
    return AppUnsavedChangesGuard(
      controller: _dismissController,
      hasChanges: _targetDayId != null,
      dismissalEnabled: !_submitting,
      child: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: Text(widget.action.title),
          onCancel: _dismissController.requestPop,
          primaryActionLabel: widget.action.submitLabel,
          primaryActionKey: const ValueKey('entry-action-submit'),
          primaryActionEnabled: _targetDayId != null && !_submitting,
          onPrimaryAction: () => _submit(days),
        ),
        body: daysAsync.when(
          loading: () => const AppListLoadingSkeleton(
            key: ValueKey('entry-action-loading'),
            itemCount: 3,
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s6),
              child: Text('載入失敗：$error', textAlign: TextAlign.center),
            ),
          ),
          data: (days) => _body(context, days),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<TripDay> days) {
    final theme = Theme.of(context);
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s6),
          child: Text(
            '此行程尚無天數',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        Text('選擇目標日期', style: theme.textTheme.titleMedium),
        const SizedBox(height: TpSpacing.s3),
        for (final day in days) _dayTile(context, day),
        if (_submitting) ...[
          const SizedBox(height: TpSpacing.s2),
          Semantics(
            key: const ValueKey('entry-action-progress'),
            liveRegion: true,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: TpSpacing.s2),
                Text('${widget.action.submitLabel}中…'),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: TpSpacing.s2),
          Semantics(
            key: const ValueKey('entry-action-error'),
            liveRegion: true,
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: TpSpacing.s4),
      ],
    );
  }

  Widget _dayTile(BuildContext context, TripDay day) {
    final selected = _targetDayId == day.id;
    final title = day.displayTitle == 'Day ${day.dayNum}'
        ? 'DAY ${day.dayNum}'
        : 'DAY ${day.dayNum} · ${day.displayTitle}';
    return ListTile(
      key: ValueKey('entry-action-day-${day.id}'),
      enabled: !_submitting,
      selected: selected,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_outlined
            : Icons.radio_button_unchecked_outlined,
      ),
      title: Text(title),
      onTap: _submitting
          ? null
          : () => setState(() {
              _targetDayId = day.id;
              _error = null;
            }),
    );
  }

  Future<void> _submit(List<TripDay> days) async {
    final targetDayId = _targetDayId;
    if (targetDayId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final repo = ref.read(tripRepositoryProvider);
    try {
      switch (widget.action) {
        case EntryRouteAction.copy:
          await repo.copyEntry(
            tripId: widget.tripId,
            entryId: widget.entryId,
            targetDayId: targetDayId,
          );
        case EntryRouteAction.move:
          final sourceDay = days
              .where(
                (day) =>
                    day.timeline.any((entry) => entry.id == widget.entryId),
              )
              .firstOrNull;
          if (sourceDay == null) {
            throw Exception('Entry is not present in the current itinerary');
          }
          final sourceIndex = sourceDay.timeline.indexWhere(
            (entry) => entry.id == widget.entryId,
          );
          final targetEntries = days
              .where((day) => day.id == targetDayId)
              .firstOrNull
              ?.timeline;
          if (targetEntries == null) {
            throw Exception('Target day is not present in the itinerary');
          }
          final plan = planEntryReorder(
            {for (final day in days) day.id: day.timeline},
            sourceDayId: sourceDay.id,
            sourceIndex: sourceIndex,
            targetDayId: targetDayId,
            targetIndex: targetEntries.length,
            idOf: (entry) => entry.id,
          );
          await repo.reorderEntries(
            tripId: widget.tripId,
            updates: plan.updates,
          );
      }
      if (!mounted) return;
      ref.invalidate(tripDaysProvider(widget.tripId));
      context.go('/trips/${Uri.encodeComponent(widget.tripId)}');
    } on Exception {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '${widget.action.submitLabel}失敗，請稍後再試';
      });
    }
  }
}
