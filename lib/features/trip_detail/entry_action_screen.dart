/// Entry 跨日複製 / 移動表單。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../api/trip_repository.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';

enum EntryActionKind { copy, move }

class EntryActionScreen extends ConsumerStatefulWidget {
  const EntryActionScreen({
    super.key,
    required this.tripId,
    required this.entryId,
    required this.action,
  });

  final String tripId;
  final int entryId;
  final EntryActionKind action;

  @override
  ConsumerState<EntryActionScreen> createState() => _EntryActionScreenState();
}

class _EntryActionScreenState extends ConsumerState<EntryActionScreen> {
  int? _selectedDayId;
  bool _isSubmitting = false;
  String? _submitError;

  bool get _isCopy => widget.action == EntryActionKind.copy;
  String get _verb => _isCopy ? '複製' : '移動';
  String get _title => _isCopy ? '複製到哪一天' : '移動到哪一天';

  @override
  Widget build(BuildContext context) {
    final args = (tripId: widget.tripId, entryId: widget.entryId);
    final entryAsync = ref.watch(entryDetailProvider(args));
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: switch ((entryAsync, daysAsync)) {
        (AsyncData(value: final entry), AsyncData(value: final days)) =>
          _buildForm(entry, days),
        (AsyncError(), _) || (_, AsyncError()) => _LoadErrorState(
          message: '無法取得行程資料',
          onRetry: () {
            ref.invalidate(entryDetailProvider(args));
            ref.invalidate(tripDaysProvider(widget.tripId));
          },
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildForm(TimelineEntry entry, List<TripDay> days) {
    if (days.isEmpty) {
      return const _CenteredMessage(message: '這趟行程還沒有 day 可以選擇');
    }
    final currentDay = _findDayById(days, entry.dayId);
    final selectedDay = _findDayById(days, _selectedDayId);
    final canSubmit =
        !_isSubmitting &&
        currentDay != null &&
        selectedDay != null &&
        selectedDay.id != entry.dayId;

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _EntrySummaryCard(entry: entry),
        const SizedBox(height: TpSpacing.s4),
        Text(
          _isCopy ? '選擇目標日期，會複製一份景點。' : '選擇目標日期，原本的景點會移到新日期。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: TpSpacing.s3),
        for (final day in days) ...[
          _DayChoiceTile(
            day: day,
            isCurrent: day.id == entry.dayId,
            isSelected: day.id == _selectedDayId,
            onSelect: _isSubmitting || day.id == entry.dayId
                ? null
                : () {
                    setState(() {
                      _selectedDayId = day.id;
                      _submitError = null;
                    });
                  },
          ),
          const SizedBox(height: TpSpacing.s2),
        ],
        if (currentDay == null) ...[
          const SizedBox(height: TpSpacing.s2),
          const _InlineError(message: '找不到目前所在 day，請重新整理後再試'),
        ],
        if (_submitError != null) ...[
          const SizedBox(height: TpSpacing.s2),
          _InlineError(message: _submitError!),
        ],
        const SizedBox(height: TpSpacing.s4),
        FilledButton.icon(
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isCopy ? Icons.copy_outlined : Icons.drive_file_move),
          label: Text(_verb),
          onPressed: canSubmit
              ? () => _submit(
                  entry: entry,
                  targetDay: selectedDay,
                  sourceDay: currentDay,
                )
              : null,
        ),
      ],
    );
  }

  Future<void> _submit({
    required TimelineEntry entry,
    required TripDay targetDay,
    required TripDay? sourceDay,
  }) async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      if (_isCopy) {
        await repository.copyEntry(
          tripId: widget.tripId,
          entryId: widget.entryId,
          targetDayId: targetDay.id,
        );
        _afterMutation(
          repository,
          targetDayNum: targetDay.dayNum,
          sourceDayNum: null,
        );
      } else {
        await repository.moveEntry(
          tripId: widget.tripId,
          entryId: widget.entryId,
          targetDayId: targetDay.id,
          expectedVersion: entry.version,
        );
        _afterMutation(
          repository,
          targetDayNum: targetDay.dayNum,
          sourceDayNum: sourceDay?.dayNum,
        );
      }
    } on ApiError catch (error) {
      _showSubmitError(error);
    } on Exception {
      _showSubmitError(null);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _afterMutation(
    TripRepository repository, {
    required int targetDayNum,
    required int? sourceDayNum,
  }) {
    ref.invalidate(
      entryDetailProvider((tripId: widget.tripId, entryId: widget.entryId)),
    );
    ref.invalidate(tripDaysProvider(widget.tripId));
    unawaited(
      repository
          .recomputeTravel(widget.tripId, dayNum: targetDayNum)
          .catchError((Object _) {}),
    );
    if (sourceDayNum != null && sourceDayNum != targetDayNum) {
      unawaited(
        repository
            .recomputeTravel(widget.tripId, dayNum: sourceDayNum)
            .catchError((Object _) {}),
      );
    }
    if (mounted) context.go('/trips/${widget.tripId}');
  }

  void _showSubmitError(ApiError? error) {
    if (!mounted) return;
    setState(() {
      if (error?.code == 'STALE_ENTRY') {
        _submitError = '資料已被其他操作更新，請重新進入此頁';
      } else {
        _submitError = _isCopy ? '複製失敗，請稍後再試' : '移動失敗，請稍後再試';
      }
    });
  }

  TripDay? _findDayById(List<TripDay> days, int? dayId) {
    if (dayId == null) return null;
    for (final day in days) {
      if (day.id == dayId) return day;
    }
    return null;
  }
}

class _EntrySummaryCard extends StatelessWidget {
  const _EntrySummaryCard({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = entry.master?.name ?? entry.title;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.titleMedium),
            if (entry.startTime != null || entry.endTime != null) ...[
              const SizedBox(height: TpSpacing.s1),
              Text(
                '${entry.startTime ?? '--:--'} - ${entry.endTime ?? '--:--'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayChoiceTile extends StatelessWidget {
  const _DayChoiceTile({
    required this.day,
    required this.isCurrent,
    required this.isSelected,
    required this.onSelect,
  });

  final TripDay day;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title =
        'Day ${day.dayNum} · ${day.displayTitle}${isCurrent ? '（目前）' : ''}';
    return Card(
      clipBehavior: Clip.antiAlias,
      color: isSelected ? colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(title),
        subtitle: day.date == null ? null : Text(day.date!),
        enabled: onSelect != null,
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        onTap: onSelect,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
