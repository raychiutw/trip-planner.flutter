import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_error.dart';
import '../../../api/cache/rebase_merge.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../models/day.dart';
import '../../../app/app_feedback.dart';
import '../../../models/entry.dart';
import '../../../models/poi_type.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_compact_time_field.dart';
import '../entry_mutations.dart';
import '../trip_providers.dart';
import 'entry_field_merge.dart';

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

  /// 起訖兩顆共用一個群組：展開其中一顆，另一顆自動收起。
  final _timeFieldGroup = TpTimeFieldGroup();

  /// 上次接受的伺服器版本的三個可編輯欄位;三方合併的 base。
  EntryFields _base = const {};

  /// 與協作者真衝突的欄位;非空就要先問「保留你的版本？」。
  Set<String> _conflicts = const {};
  String _poiType = 'attraction';
  int? _newDayNum;
  bool _submitting = false;
  bool _dirty = false;
  bool _syncingFromModel = false;
  bool _waitingForFresh = false;
  int? _staleVersion;
  TimelineEntry? _acceptedEntry;

  /// 由 entryEditSourceProvider 在 build 時寫入;404 = 已被刪除。
  bool _deleted = false;
  Object? _loadError;

  bool get _isEdit => widget.args is EntryEditExisting;
  TimelineEntry get _existingEntry =>
      _acceptedEntry ?? (widget.args as EntryEditExisting).entry;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args is EntryEditExisting) {
      _acceptedEntry = args.entry;
      _title = TextEditingController(text: args.entry.title);
      _desc = TextEditingController(text: args.entry.description ?? '');
      _start = _parseHm(args.entry.startTime);
      _end = _parseHm(args.entry.endTime);
      _base = entryFieldsOf(args.entry);
    } else {
      _title = TextEditingController();
      _desc = TextEditingController();
      _newDayNum = (args as EntryEditNew).dayNum;
    }
    _lat = TextEditingController();
    _lng = TextEditingController();
    _title.addListener(_onChanged);
    _desc.addListener(_onDescriptionChanged);
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

  /// provider 給了比已接受版本更新的停留點 → 合併進表單。
  void _acceptFresh(TimelineEntry entry) {
    final accepted = _acceptedEntry;
    if (accepted != null && !_entryChanged(accepted, entry)) return;
    _acceptedEntry = entry;
    // build 期間不能改 controller / setState,排到 frame 結束。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mergeExistingEntry(entry);
    });
  }

  static bool _entryChanged(TimelineEntry previous, TimelineEntry next) {
    return previous.id != next.id ||
        previous.version != next.version ||
        previous.title != next.title ||
        previous.description != next.description ||
        previous.startTime != next.startTime ||
        previous.endTime != next.endTime;
  }

  bool get _hasRemoteConflict => _conflicts.isNotEmpty;

  /// 表單目前的三個可編輯欄位(與 [entryFieldsOf] 同一套正規化)。
  EntryFields get _oursFromForm => {
    'description': _desc.text,
    'startTime': _fmt(_start),
    'endTime': _fmt(_end),
  };

  void _mergeExistingEntry(TimelineEntry entry) {
    final theirs = entryFieldsOf(entry);
    final merged = mergeEntryFields(
      base: _base,
      ours: _oursFromForm,
      theirs: theirs,
      previousConflicts: _conflicts,
    );
    _conflicts = merged.conflicts;

    _syncingFromModel = true;
    _title.value = TextEditingValue(
      text: entry.title,
      selection: TextSelection.collapsed(offset: entry.title.length),
    );
    if (merged.adopt.contains('description')) {
      final description = theirs['description'] as String;
      _desc.value = TextEditingValue(
        text: description,
        selection: TextSelection.collapsed(offset: description.length),
      );
    }
    if (merged.adopt.contains('startTime')) {
      _start = _parseHm(theirs['startTime'] as String?);
    }
    if (merged.adopt.contains('endTime')) {
      _end = _parseHm(theirs['endTime'] as String?);
    }
    _syncingFromModel = false;
    _base = theirs;
    _dirty = dirtyFields(_base, _oursFromForm).isNotEmpty;
    final staleVersion = _staleVersion;
    final freshAfterConflict =
        _waitingForFresh &&
        staleVersion != null &&
        entry.version > staleVersion;
    if (freshAfterConflict) {
      _waitingForFresh = false;
      _staleVersion = null;
    }
    // 這裡永遠在 frame 之外被呼叫(_acceptFresh 排到 post-frame),可以直接 setState;
    // 再排一層 post-frame 的話,沒有新 frame 它就永遠不會跑。
    if (!mounted) return;
    setState(() {});
    _syncFormState();
    if (freshAfterConflict) {
      if (_hasRemoteConflict) {
        showAppError(context, '協作者也更新了這筆資料。你的修改已保留；再次儲存前請確認是否覆蓋對方版本。');
      } else {
        showAppNotice(context, '已載入最新資料；你的修改已保留。');
      }
    }
  }

  void _onChanged() {
    if (_syncingFromModel) return;
    _markChanged();
  }

  void _onDescriptionChanged() {
    if (_syncingFromModel) return;
    if (!_isEdit) {
      _markChanged();
      return;
    }
    _fieldChanged('description');
  }

  /// 使用者把某欄改回 base 的值 → 該欄的衝突解除。
  void _fieldChanged(String field) {
    final ours = _oursFromForm;
    if (ours[field] == _base[field] && _conflicts.contains(field)) {
      _conflicts = {..._conflicts}..remove(field);
    }
    _updateEditDirty();
  }

  void _markTimeChanged(bool isStart) {
    if (!_isEdit) {
      _markChanged();
      return;
    }
    _fieldChanged(isStart ? 'startTime' : 'endTime');
  }

  void _updateEditDirty() {
    _dirty = dirtyFields(_base, _oursFromForm).isNotEmpty;
    setState(() {});
    _syncFormState();
  }

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
    _timeFieldGroup.dispose();
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
      !_waitingForFresh &&
      !_entryDeleted &&
      (_isEdit || _title.text.trim().isNotEmpty) &&
      entryTimeRangeValid(_start, _end) &&
      _coordsValid;

  bool get _entryDeleted => _deleted;

  int _selectedDayNum(EntryEditNew args) {
    final dayNum = _newDayNum ?? args.dayNum;
    return args.days.isEmpty || args.days.any((d) => d.dayNum == dayNum)
        ? dayNum
        : args.dayNum;
  }

  void _pick(bool isStart, TimeOfDay picked) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (isStart) {
      _start = picked;
    } else {
      _end = picked;
    }
    _markTimeChanged(isStart);
  }

  Future<void> _recomputeDay(int dayNum) => ref
      .read(entryMutationsProvider(widget.tripId).notifier)
      .recomputeTravel(dayNum: dayNum);

  void _retryAfterStale() {
    if (!mounted) return;
    // 重試只重新觸發載入；在 _mergeExistingEntry 真正觀察到更高 version 前，
    // 維持 submit 鎖定，避免用同一個已知 stale version 再送出必然 409 的請求。
    _invalidateEntryCaches();
  }

  Future<bool> _submitForSheet() => _save();

  void _invalidateEntryCaches() {
    ref.read(entryMutationsProvider(widget.tripId).notifier).refreshAfter({
      TripChange.days,
      if (_isEdit) TripChange.entry,
    }, entryId: _isEdit ? _existingEntry.id : null);
  }

  Future<void> _submitLegacy() async {
    final saved = await _save();
    if (!saved || !mounted || widget.onSaved != null) return;
    Navigator.of(context).pop();
  }

  Future<bool> _save() async {
    if (_hasRemoteConflict) {
      final overwrite = await showAppConfirm(
        context,
        title: '保留你的版本？',
        message: '協作者也修改了相同欄位。繼續會以你目前的內容覆蓋對方版本。',
        confirmLabel: '保留我的版本',
        cancelLabel: '繼續編輯',
        isDestructive: true,
      );
      if (!mounted || !overwrite) return false;
      _conflicts = const {};
    }
    final title = _title.text.trim();
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    int? submittedVersion;
    setState(() => _submitting = true);
    _syncFormState();
    final repo = ref.read(tripRepositoryProvider);
    try {
      switch (widget.args) {
        case EntryEditExisting():
          final entry = _existingEntry;
          submittedVersion = entry.version;
          await repo.updateEntry(
            tripId: widget.tripId,
            entryId: entry.id,
            expectedVersion: entry.version,
            description: description,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
          );
          await ref
              .read(entryMutationsProvider(widget.tripId).notifier)
              .recomputeTravel();
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
      if (!mounted) return false;
      _invalidateEntryCaches();
      HapticFeedback.lightImpact();
      _dirty = false;
      if (_isEdit) _base = _oursFromForm;
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
      if (error.status == 409 && error.code == 'STALE_ENTRY') {
        final currentVersion = _isEdit ? _existingEntry.version : null;
        final freshAlreadyLoaded =
            submittedVersion != null && currentVersion != submittedVersion;
        setState(() {
          _submitting = false;
          _waitingForFresh = !freshAlreadyLoaded;
          _staleVersion = submittedVersion;
        });
        _syncFormState();
        _invalidateEntryCaches();
        showAppError(
          context,
          '此停留點已有新版，正在重新載入；你的修改會先保留。',
          onRetry: _retryAfterStale,
        );
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
    if (args case EntryEditExisting(:final entry)) {
      final source = ref.watch(
        entryEditSourceProvider((
          tripId: widget.tripId,
          entryId: entry.id,
          seedVersion: (_acceptedEntry ?? entry).version,
        )),
      );
      final wasDeleted = _deleted;
      _deleted = source.deleted;
      _loadError = source.error;
      if (wasDeleted != _deleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncFormState();
        });
      }
      if (source.fresher case final fresh?) _acceptFresh(fresh);
    }
    final refreshError = _loadError;
    final entryDeleted = _deleted;
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
                enabled: !_submitting,
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
                  onChanged: _submitting
                      ? null
                      : (value) {
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
                onChanged: _submitting
                    ? null
                    : (value) {
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
                      enabled: !_submitting,
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
                      enabled: !_submitting,
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
            if (refreshError != null) ...[
              Container(
                key: const ValueKey('entry-edit-refresh-error'),
                padding: const EdgeInsets.all(TpSpacing.s3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(TpSpacing.s3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      entryDeleted
                          ? '此停留點已被刪除，無法再儲存；你的草稿仍保留。'
                          : '無法載入最新版本；你的草稿仍保留。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    if (!entryDeleted) ...[
                      const SizedBox(height: TpSpacing.s2),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          key: const ValueKey('entry-edit-stale-retry'),
                          onPressed: _retryAfterStale,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重試載入'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: TpSpacing.s3),
            ] else if (_waitingForFresh) ...[
              OutlinedButton.icon(
                key: const ValueKey('entry-edit-stale-retry'),
                onPressed: _retryAfterStale,
                icon: const Icon(Icons.refresh),
                label: const Text('重新載入新版'),
              ),
              const SizedBox(height: TpSpacing.s3),
            ],
            // compact picker 就地展開會把下方內容往下推，兩顆必須各佔一列；
            // 並排會讓展開的輪盤壓縮到讀不出數字。
            _timeField(true),
            const SizedBox(height: TpSpacing.s2),
            _timeField(false, errorText: timeValid ? null : '結束時間需晚於開始時間'),
            const SizedBox(height: TpSpacing.s3),
            TextField(
              key: const ValueKey('entry-edit-desc'),
              controller: _desc,
              enabled: !_submitting,
              // The backend calls this entry-level field `description`.
              // Per-POI notes are edited separately on the location screen.
              decoration: const InputDecoration(labelText: '行程備註（選填）'),
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              scrollPadding: const EdgeInsets.only(
                bottom: TpSpacing.s10 + TpSpacing.s6,
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(height: TpSpacing.s3),
              OutlinedButton.icon(
                key: const ValueKey('entry-edit-manage-pois'),
                onPressed: _submitting
                    ? null
                    : () {
                        final entry = _existingEntry;
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

  Widget _timeField(bool isStart, {String? errorText}) {
    final t = isStart ? _start : _end;
    return TpCompactTimeField(
      key: ValueKey(
        isStart ? 'entry-edit-start-group' : 'entry-edit-end-group',
      ),
      buttonKey: ValueKey(isStart ? 'entry-edit-start' : 'entry-edit-end'),
      clearKey: ValueKey(
        isStart ? 'entry-edit-start-clear' : 'entry-edit-end-clear',
      ),
      errorKey: const ValueKey('entry-edit-end-error'),
      label: isStart ? '開始' : '結束',
      value: t,
      group: _timeFieldGroup,
      enabled: !_submitting,
      errorText: errorText,
      onChanged: (picked) => _pick(isStart, picked),
      onCleared: () {
        if (isStart) {
          _start = null;
        } else {
          _end = null;
        }
        _markTimeChanged(isStart);
      },
    );
  }
}
