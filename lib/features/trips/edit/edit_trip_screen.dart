/// 編輯行程:標題 + 目的地 + 日期/天數 + 描述 + 語言 + 發布 + 明確儲存。
/// 儲存成功 → pop。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/day.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import '../widgets/destination_picker.dart';
import 'edit_trip_controller.dart';

const _langs = {'zh-TW': '繁體中文', 'en': 'English', 'ja': '日本語'};

class EditTripScreen extends ConsumerStatefulWidget {
  const EditTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen> {
  final _dismissController = AppUnsavedChangesController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editTripControllerProvider(widget.tripId));
    final ctrl = ref.read(editTripControllerProvider(widget.tripId).notifier);

    // 儲存成功 → 返回。
    ref.listen(editTripControllerProvider(widget.tripId), (prev, next) {
      if (next.saved && !(prev?.saved ?? false)) {
        HapticFeedback.lightImpact();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) context.pop();
        });
      }
    });

    return AppUnsavedChangesGuard(
      controller: _dismissController,
      hasChanges: !state.saved && ctrl.hasChanges,
      child: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: const Text('編輯行程'),
          onCancel: _dismissController.requestPop,
          primaryActionLabel: '儲存',
          primaryActionKey: const ValueKey('edit-save'),
          primaryActionEnabled: ctrl.hasChanges && !state.saving,
          onPrimaryAction: ctrl.save,
        ),
        body: state.loading
            ? const AppListLoadingSkeleton(key: ValueKey('edit-trip-loading'))
            : ListView(
                padding: const EdgeInsets.all(TpSpacing.s4),
                children: [
                  _title(context, '行程標題'),
                  TextFormField(
                    key: const ValueKey('edit-title'),
                    initialValue: state.title,
                    decoration: const InputDecoration(
                      hintText: '例如:2026 沖繩自駕',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: ctrl.setTitle,
                  ),
                  const SizedBox(height: TpSpacing.s5),
                  _title(context, '目的地'),
                  DestinationPicker(
                    destinations: state.destinations,
                    onAdd: ctrl.addDestination,
                    onRemove: ctrl.removeDestination,
                    onReorder: ctrl.reorderDestination,
                  ),
                  const SizedBox(height: TpSpacing.s5),
                  _title(context, '出發日期'),
                  _ShiftDateSection(
                    startDate: state.startDate,
                    endDate: state.endDate,
                    shifting: state.shifting,
                    onShift: () async {
                      final nextDate = await _showShiftDateDialog(
                        context,
                        state.startDate,
                      );
                      if (nextDate == null) return;
                      final ok = await ctrl.shiftStartDate(nextDate);
                      if (context.mounted && ok) {
                        _showSnackBar(context, '出發日期已變更');
                      }
                    },
                  ),
                  const SizedBox(height: TpSpacing.s5),
                  _title(context, '行程天數'),
                  _DayManagementSection(
                    days: state.days,
                    mutating: state.daysMutating,
                    onAddStart: () async {
                      final ok = await ctrl.addDay('start');
                      if (context.mounted && ok) {
                        _showSnackBar(context, '已在最前加入一天');
                      }
                    },
                    onAddEnd: () async {
                      final ok = await ctrl.addDay('end');
                      if (context.mounted && ok) {
                        _showSnackBar(context, '已在最後加入一天');
                      }
                    },
                    onRestore: (date) async {
                      final ok = await ctrl.restoreDay(date);
                      if (context.mounted && ok) {
                        _showSnackBar(context, '已加回 $date');
                      }
                    },
                    onDelete: (day) async {
                      final confirmed = await _confirmDeleteDay(context, day);
                      if (!confirmed) return;
                      final removed = await ctrl.deleteDay(day.dayNum);
                      if (context.mounted && removed != null) {
                        final message = removed > 0
                            ? 'Day ${day.dayNum} 已刪除（連同 $removed 個景點）'
                            : 'Day ${day.dayNum} 已刪除';
                        _showSnackBar(context, message);
                      }
                    },
                  ),
                  const SizedBox(height: TpSpacing.s5),
                  _title(context, '描述（用於 SEO,選填）'),
                  TextFormField(
                    key: const ValueKey('edit-desc'),
                    initialValue: state.description,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    onChanged: ctrl.setDescription,
                  ),
                  const SizedBox(height: TpSpacing.s4),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('edit-lang'),
                    initialValue: state.lang,
                    decoration: const InputDecoration(
                      labelText: '顯示語言',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final e in _langs.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) {
                      if (v != null) ctrl.setLang(v);
                    },
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  SwitchListTile.adaptive(
                    key: const ValueKey('edit-published'),
                    title: const Text('發布（公開上線）'),
                    contentPadding: EdgeInsets.zero,
                    value: state.published,
                    onChanged: ctrl.setPublished,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: TpSpacing.s2),
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: TpSpacing.s4),
                ],
              ),
      ),
    );
  }

  Widget _title(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(bottom: TpSpacing.s2),
    child: Text(t, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _DayManagementSection extends StatelessWidget {
  const _DayManagementSection({
    required this.days,
    required this.mutating,
    required this.onAddStart,
    required this.onAddEnd,
    required this.onRestore,
    required this.onDelete,
  });

  final List<TripDay> days;
  final bool mutating;
  final VoidCallback onAddStart;
  final VoidCallback onAddEnd;
  final ValueChanged<String> onRestore;
  final ValueChanged<TripDay> onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: TpSpacing.s2,
            runSpacing: TpSpacing.s2,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('edit-add-day-start'),
                onPressed: mutating ? null : onAddStart,
                icon: const Icon(Icons.first_page_outlined),
                label: const Text('加到最前'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('edit-add-day-end'),
                onPressed: mutating ? null : onAddEnd,
                icon: const Icon(Icons.last_page_outlined),
                label: const Text('加到最後'),
              ),
            ],
          ),
          const SizedBox(height: TpSpacing.s3),
          if (days.isEmpty)
            Text(
              '尚無日程資料',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < days.length; index++) ...[
                  _DaySummaryRow(
                    day: days[index],
                    mutating: mutating,
                    onDelete: () => onDelete(days[index]),
                  ),
                  for (final missingDate in _missingDatesAfter(days, index))
                    _MissingDayRow(
                      date: missingDate,
                      mutating: mutating,
                      onRestore: () => onRestore(missingDate),
                    ),
                  if (index != days.length - 1)
                    const Divider(height: TpSpacing.s4),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MissingDayRow extends StatelessWidget {
  const _MissingDayRow({
    required this.date,
    required this.mutating,
    required this.onRestore,
  });

  final String date;
  final bool mutating;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: TpSpacing.s2),
      child: Row(
        children: [
          Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant, size: 18),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Text(
              '缺少 $date',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            key: ValueKey('edit-restore-day-$date'),
            onPressed: mutating ? null : onRestore,
            icon: const Icon(Icons.add),
            label: const Text('加回'),
          ),
        ],
      ),
    );
  }
}

class _DaySummaryRow extends StatelessWidget {
  const _DaySummaryRow({
    required this.day,
    required this.mutating,
    required this.onDelete,
  });

  final TripDay day;
  final bool mutating;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAY ${day.dayNum}',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TpSpacing.s1),
              Text(day.displayTitle, style: textTheme.bodyLarge),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('edit-delete-day-${day.dayNum}'),
          tooltip: '刪除 Day ${day.dayNum}',
          onPressed: mutating ? null : onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _ShiftDateSection extends StatelessWidget {
  const _ShiftDateSection({
    required this.startDate,
    required this.endDate,
    required this.shifting,
    required this.onShift,
  });

  final String? startDate;
  final String? endDate;
  final bool shifting;
  final VoidCallback onShift;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dateRangeLabel(startDate, endDate), style: textTheme.bodyLarge),
          const SizedBox(height: TpSpacing.s1),
          Text(
            '整體平移所有日程日期，停留點順序不變。',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('edit-shift-days'),
              onPressed: shifting ? null : onShift,
              icon: shifting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_repeat_outlined),
              label: const Text('平移日期'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showShiftDateDialog(BuildContext context, String? startDate) =>
    showDialog<String>(
      context: context,
      builder: (dialogContext) => _ShiftDateDialog(startDate: startDate),
    );

class _ShiftDateDialog extends StatefulWidget {
  const _ShiftDateDialog({this.startDate});

  final String? startDate;

  @override
  State<_ShiftDateDialog> createState() => _ShiftDateDialogState();
}

class _ShiftDateDialogState extends State<_ShiftDateDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.startDate ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('平移出發日期'),
      content: TextField(
        key: const ValueKey('edit-shift-start-date'),
        controller: _controller,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: '新的 Day 1 日期',
          hintText: 'YYYY-MM-DD',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('套用'),
        ),
      ],
    );
  }
}

String _dateRangeLabel(String? startDate, String? endDate) {
  if (startDate == null || startDate.isEmpty) return '尚無日期資料';
  if (endDate == null || endDate.isEmpty || endDate == startDate) {
    return startDate;
  }
  return '$startDate → $endDate';
}

List<String> _missingDatesAfter(List<TripDay> days, int index) {
  if (index >= days.length - 1) return const [];
  final current = _parseIsoDate(days[index].date);
  final next = _parseIsoDate(days[index + 1].date);
  if (current == null || next == null) return const [];
  final result = <String>[];
  var cursor = current.add(const Duration(days: 1));
  while (cursor.isBefore(next)) {
    result.add(_formatIsoDate(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return result;
}

DateTime? _parseIsoDate(String? value) {
  if (value == null || value.length != 10) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  try {
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  } on ArgumentError {
    return null;
  }
}

String _formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Future<bool> _confirmDeleteDay(BuildContext context, TripDay day) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('刪除 Day ${day.dayNum}'),
      content: const Text('這會刪除當天日程並重新編號後續天數。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('刪除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _showSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
