import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../models/day.dart';
import '../../../app/app_feedback.dart';
import '../../../models/entry.dart';
import '../../../models/poi_type.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';

/// 編輯/新增停留點的模式參數。
sealed class EntryEditArgs {
  const EntryEditArgs();
}

/// 編輯既有停留點。
class EntryEditExisting extends EntryEditArgs {
  const EntryEditExisting(this.entry);
  final TimelineEntry entry;
}

/// 在指定 day 新增一筆自訂停留點。
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
}) async {
  final controller = AppSheetFormController();
  final isEdit = args is EntryEditExisting;
  try {
    await showAppFormSheet(
      context,
      title: isEdit ? '編輯停留點' : '新增停留點',
      submitLabel: isEdit ? '儲存' : '新增',
      submitKey: const ValueKey('entry-edit-submit'),
      controller: controller,
      builder: (_) => EntryEditSheet(
        tripId: tripId,
        args: args,
        formController: controller,
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// 停留點新增/編輯表單；可作為 bottom sheet 或 full-page route 內容。
class EntryEditSheet extends ConsumerStatefulWidget {
  const EntryEditSheet({
    super.key,
    required this.tripId,
    required this.args,
    this.onSaved,
    this.formController,
  });

  final String tripId;
  final EntryEditArgs args;
  final VoidCallback? onSaved;
  final AppSheetFormController? formController;

  @override
  ConsumerState<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends ConsumerState<EntryEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  TimeOfDay? _start;
  TimeOfDay? _end;
  String _poiType = 'attraction';
  int? _newDayNum;
  bool _submitting = false;
  bool _dirty = false;

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
    _lat = TextEditingController();
    _lng = TextEditingController();
    _title.addListener(_onChanged);
    _desc.addListener(_onChanged);
    _lat.addListener(_onChanged);
    _lng.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.formController?.attach(_submitForSheet);
      _syncFormState();
    });
  }

  @override
  void didUpdateWidget(covariant EntryEditSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousArgs = oldWidget.args;
    final nextArgs = widget.args;
    if (previousArgs is EntryEditNew &&
        nextArgs is EntryEditNew &&
        previousArgs.dayNum != nextArgs.dayNum) {
      _newDayNum = nextArgs.dayNum;
    }
  }

  void _onChanged() => _markChanged();

  void _markChanged() {
    _dirty = true;
    setState(() {});
    _syncFormState();
  }

  void _syncFormState() {
    widget.formController?.update(
      dirty: _dirty,
      canSubmit: _canSubmit,
      submitting: _submitting,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _lat.dispose();
    _lng.dispose();
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

  static double? _coordValue(
    String raw, {
    required double min,
    required double max,
  }) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < min || value > max) return null;
    return value;
  }

  bool get _coordsBlank => _lat.text.trim().isEmpty && _lng.text.trim().isEmpty;

  bool get _coordsComplete =>
      _lat.text.trim().isNotEmpty && _lng.text.trim().isNotEmpty;

  bool get _coordsValid {
    if (_isEdit) return true;
    if (_coordsBlank) return false;
    return _coordValue(_lat.text, min: -90, max: 90) != null &&
        _coordValue(_lng.text, min: -180, max: 180) != null;
  }

  String? get _coordErrorText {
    if (_isEdit || _title.text.trim().isEmpty) return null;
    if (!_coordsComplete) return '請填入緯度與經度';
    if (!_coordsValid) return '座標需同時填入有效緯度與經度';
    return null;
  }

  bool get _canSubmit =>
      !_submitting &&
      (_isEdit || _title.text.trim().isNotEmpty) &&
      entryTimeRangeValid(_start, _end) &&
      _coordsValid;

  int _selectedDayNum(EntryEditNew args) {
    final dayNum = _newDayNum ?? args.dayNum;
    return args.days.isEmpty || args.days.any((d) => d.dayNum == dayNum)
        ? dayNum
        : args.dayNum;
  }

  Future<void> _pick(bool isStart) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showAppTimePicker(
      context,
      initialTime:
          (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _markChanged();
    }
  }

  Future<void> _recomputeDay(int dayNum) async {
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId: widget.tripId, day: '$dayNum');
    } catch (_) {
      // 交通重算失敗不影響停留點新增結果。
    }
  }

  Future<bool> _submitForSheet() => _save();

  Future<void> _submitLegacy() async {
    final saved = await _save();
    if (!saved || !mounted || widget.onSaved != null) return;
    Navigator.of(context).pop();
  }

  Future<bool> _save() async {
    final title = _title.text.trim();
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() => _submitting = true);
    _syncFormState();
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
          try {
            await repo.recomputeTravel(tripId: widget.tripId);
          } catch (_) {
            // Entry save succeeded; travel can self-heal on the next refresh.
          }
        case final EntryEditNew args:
          final dayNum = _selectedDayNum(args);
          final lat = _coordValue(_lat.text, min: -90, max: 90);
          final lng = _coordValue(_lng.text, min: -180, max: 180);
          await repo.addEntryToDay(
            tripId: widget.tripId,
            dayNum: dayNum,
            title: title,
            description: description,
            poiType: _poiType,
            lat: lat,
            lng: lng,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
            source: 'custom',
          );
          await _recomputeDay(dayNum);
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return false;
      HapticFeedback.lightImpact();
      _dirty = false;
      _submitting = false;
      _syncFormState();
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        onSaved();
      }
      showAppNotice(context, _isEdit ? '已儲存' : '已新增');
      return true;
    } on ApiError catch (error) {
      if (!mounted) return false;
      if (error.status == 409) {
        ref.invalidate(tripDaysProvider(widget.tripId));
        showAppError(context, '此停留點已更新，已重新載入，請再編輯一次');
        setState(() => _submitting = false);
        _syncFormState();
        return false;
      }
      setState(() => _submitting = false);
      _syncFormState();
      showAppError(context, '儲存失敗，請稍後再試');
      return false;
    } on Exception {
      if (!mounted) return false;
      setState(() => _submitting = false);
      _syncFormState();
      showAppError(context, '儲存失敗，請稍後再試');
      return false;
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
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.formController == null) ...[
              Text(
                _isEdit ? '編輯停留點' : '新增停留點',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: TpSpacing.s4),
            ],
            if (!_isEdit) ...[
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
                    if (value == null) return;
                    _newDayNum = value;
                    _markChanged();
                  },
                ),
              ],
              const SizedBox(height: TpSpacing.s3),
              DropdownButtonFormField<String>(
                key: const ValueKey('entry-edit-poi-type'),
                initialValue: _poiType,
                decoration: const InputDecoration(labelText: '分類'),
                items: [
                  for (final entry in kPoiTypeLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _poiType = value;
                  _markChanged();
                },
              ),
              const SizedBox(height: TpSpacing.s3),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('entry-edit-lat'),
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: '緯度（必填）'),
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('entry-edit-lng'),
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: '經度（必填）'),
                    ),
                  ),
                ],
              ),
              if (_coordErrorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: TpSpacing.s2),
                  child: Text(
                    _coordErrorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: TpSpacing.s3),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s2,
              children: [_timeField(true), _timeField(false)],
            ),
            if (!timeValid)
              Padding(
                padding: const EdgeInsets.only(top: TpSpacing.s2),
                child: Text(
                  '結束時間需晚於開始時間',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11,
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
                icon: const Icon(CupertinoIcons.location_solid),
                label: const Text('管理地點'),
              ),
            ],
            if (widget.formController == null) ...[
              const SizedBox(height: TpSpacing.s6),
              FilledButton(
                key: const ValueKey('entry-edit-submit'),
                onPressed: _canSubmit ? _submitLegacy : null,
                child: Text(_submitting ? '處理中…' : (_isEdit ? '儲存' : '新增')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeField(bool isStart) {
    final t = isStart ? _start : _end;
    return InputChip(
      key: ValueKey(isStart ? 'entry-edit-start' : 'entry-edit-end'),
      avatar: const Icon(CupertinoIcons.clock, size: 18),
      label: Text('${isStart ? '開始' : '結束'} ${_fmt(t) ?? '未設定'}'),
      onPressed: () => _pick(isStart),
      deleteIcon: t == null
          ? null
          : Icon(
              CupertinoIcons.xmark_circle_fill,
              key: ValueKey(
                isStart ? 'entry-edit-start-clear' : 'entry-edit-end-clear',
              ),
              size: 18,
            ),
      onDeleted: t == null
          ? null
          : () {
              if (isStart) {
                _start = null;
              } else {
                _end = null;
              }
              _markChanged();
            },
    );
  }
}
