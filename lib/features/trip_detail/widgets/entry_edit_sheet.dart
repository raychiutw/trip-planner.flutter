import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../models/day.dart';
import '../../../models/entry.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';

/// 編輯/新增停留點的模式參數。
sealed class EntryEditArgs {
  const EntryEditArgs();
}

class EntryEditExisting extends EntryEditArgs {
  const EntryEditExisting(this.entry);
  final TimelineEntry entry;
}

class EntryEditNew extends EntryEditArgs {
  const EntryEditNew(this.dayNum, {this.days = const []});
  final int dayNum;
  final List<TripDay> days;
}

/// 時間區間有效性：start/end 皆設時 end 須晚於 start;任一未設視為有效（時間選填）。
bool entryTimeRangeValid(TimeOfDay? start, TimeOfDay? end) {
  if (start == null || end == null) return true;
  return end.hour * 60 + end.minute > start.hour * 60 + start.minute;
}

/// 以 modal bottom sheet 開啟編輯/新增停留點表單。
Future<void> showEntryEditSheet(
  BuildContext context, {
  required String tripId,
  required EntryEditArgs args,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: EntryEditSheet(tripId: tripId, args: args),
    ),
  );
}

class EntryEditSheet extends ConsumerStatefulWidget {
  const EntryEditSheet({super.key, required this.tripId, required this.args});

  final String tripId;
  final EntryEditArgs args;

  @override
  ConsumerState<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends ConsumerState<EntryEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  TimeOfDay? _start;
  TimeOfDay? _end;
  int? _newDayNum;
  bool _submitting = false;

  bool get _isEdit => widget.args is EntryEditExisting;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args is EntryEditExisting) {
      _title = TextEditingController(text: args.entry.title);
      _desc = TextEditingController(text: args.entry.description ?? '');
      _start = _parseHm(args.entry.startTime);
      _end = _parseHm(args.entry.endTime);
    } else {
      _title = TextEditingController();
      _desc = TextEditingController();
      _newDayNum = (args as EntryEditNew).dayNum;
    }
    _title.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseHm(String? hm) {
    if (hm == null) return null;
    final parts = hm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _canSubmit =>
      !_submitting &&
      (_isEdit || _title.text.trim().isNotEmpty) &&
      entryTimeRangeValid(_start, _end);

  int _selectedDayNum(EntryEditNew args) {
    final dayNum = _newDayNum ?? args.dayNum;
    return args.days.isEmpty || args.days.any((d) => d.dayNum == dayNum)
        ? dayNum
        : args.dayNum;
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _recomputeDay(int dayNum) async {
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId: widget.tripId, day: '$dayNum');
    } on Exception {
      // 交通重算失敗不影響停留點新增結果。
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() => _submitting = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      switch (widget.args) {
        case EntryEditExisting(:final entry):
          await repo.updateEntry(
            tripId: widget.tripId,
            entryId: entry.id,
            expectedVersion: entry.version,
            description: description,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
          );
        case final EntryEditNew args:
          final dayNum = _selectedDayNum(args);
          await repo.addEntryToDay(
            tripId: widget.tripId,
            dayNum: dayNum,
            title: title,
            description: description,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
            source: 'custom',
          );
          await _recomputeDay(dayNum);
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      showAppNotice(context, _isEdit ? '已儲存' : '已新增');
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        ref.invalidate(tripDaysProvider(widget.tripId));
        Navigator.of(context).pop();
        showAppNotice(context, '此停留點已更新，已重新載入，請再編輯一次');
        return;
      }
      setState(() => _submitting = false);
      showAppNotice(context, '儲存失敗，請稍後再試');
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppNotice(context, '儲存失敗，請稍後再試');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeValid = entryTimeRangeValid(_start, _end);
    final args = widget.args;
    final dayOptions = args is EntryEditNew ? args.days : const <TripDay>[];
    final selectedDayNum = args is EntryEditNew ? _selectedDayNum(args) : null;
    final showDayPicker =
        dayOptions.length > 1 &&
        dayOptions.any((d) => d.dayNum == selectedDayNum);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? '編輯停留點' : '新增停留點',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: TpSpacing.s4),
            if (!_isEdit)
              TextField(
                key: const ValueKey('entry-edit-title'),
                controller: _title,
                decoration: const InputDecoration(labelText: '標題'),
                textInputAction: TextInputAction.next,
              ),
            if (showDayPicker) ...[
              const SizedBox(height: TpSpacing.s3),
              DropdownButtonFormField<int>(
                key: const ValueKey('entry-edit-day'),
                initialValue: selectedDayNum,
                decoration: const InputDecoration(labelText: '日期'),
                items: [
                  for (final day in dayOptions)
                    DropdownMenuItem(
                      value: day.dayNum,
                      child: Text('DAY ${day.dayNum} · ${day.displayTitle}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _newDayNum = value);
                },
              ),
            ],
            const SizedBox(height: TpSpacing.s3),
            _timeField(true),
            const SizedBox(height: TpSpacing.s2),
            _timeField(false),
            if (!timeValid)
              Padding(
                padding: const EdgeInsets.only(top: TpSpacing.s2),
                child: Text(
                  '結束時間需晚於開始時間',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: TpSpacing.s3),
            TextField(
              key: const ValueKey('entry-edit-desc'),
              controller: _desc,
              decoration: const InputDecoration(labelText: '描述（選填）'),
              maxLines: 2,
            ),
            if (_isEdit) ...[
              const SizedBox(height: TpSpacing.s3),
              OutlinedButton.icon(
                key: const ValueKey('entry-edit-manage-pois'),
                onPressed: () {
                  final entry = (widget.args as EntryEditExisting).entry;
                  Navigator.of(context).pop();
                  context.push(
                    '/trips/${widget.tripId}/entries/${entry.id}/pois',
                  );
                },
                icon: const Icon(Icons.place_outlined),
                label: const Text('管理地點'),
              ),
            ],
            const SizedBox(height: TpSpacing.s6),
            FilledButton(
              key: const ValueKey('entry-edit-submit'),
              onPressed: _canSubmit ? _submit : null,
              child: Text(_submitting ? '處理中…' : (_isEdit ? '儲存' : '新增')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(bool isStart) {
    final t = isStart ? _start : _end;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: ValueKey(isStart ? 'entry-edit-start' : 'entry-edit-end'),
            onPressed: () => _pick(isStart),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${isStart ? '開始' : '結束'}　${_fmt(t) ?? '未設定'}'),
            ),
          ),
        ),
        if (t != null)
          IconButton(
            key: ValueKey(
              isStart ? 'entry-edit-start-clear' : 'entry-edit-end-clear',
            ),
            tooltip: '清除',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                setState(() => isStart ? _start = null : _end = null),
          ),
      ],
    );
  }
}
