import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/day.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import 'trip_providers.dart';

/// Web 相容的停留點跨日操作。
enum EntryRouteAction { copy, move }

extension _EntryRouteActionX on EntryRouteAction {
  String get title => switch (this) {
    EntryRouteAction.copy => '複製停留點',
    EntryRouteAction.move => '移動停留點',
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
  int? _targetDayId;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    return Scaffold(
      appBar: TpAppBar(
        role: TpAppBarRole.detail,
        title: Text(widget.action.title),
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
        if (_error != null) ...[
          const SizedBox(height: TpSpacing.s2),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: TpSpacing.s4),
        FilledButton(
          key: const ValueKey('entry-action-submit'),
          onPressed: _targetDayId == null || _submitting ? null : _submit,
          child: Text(_submitting ? '處理中...' : widget.action.submitLabel),
        ),
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

  Future<void> _submit() async {
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
          await repo.moveEntry(
            tripId: widget.tripId,
            entryId: widget.entryId,
            targetDayId: targetDayId,
          );
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return;
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
