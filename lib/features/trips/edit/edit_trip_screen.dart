/// 編輯行程:標題 + 目的地 + 日期/天數 + 描述 + 語言 + 發布,即時儲存(見 GLOSSARY)。
/// 只有「完成」:未送出的變更會先送完,失敗則攔截,讓使用者重試或放棄。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../app/app_feedback.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/day.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_picker_field.dart';
import '../../../ui/tp_app_bar.dart';
import '../widgets/destination_picker.dart';
import 'edit_trip_controller.dart';
import '../../../models/display_format.dart';

const _langs = {'zh-TW': '繁體中文', 'en': 'English', 'ja': '日本語'};

class EditTripScreen extends ConsumerStatefulWidget {
  const EditTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  bool _seeded = false;
  bool _discard = false;
  bool _finishing = false;

  EditTripController get _ctrl =>
      ref.read(editTripControllerProvider(widget.tripId).notifier);

  @override
  void initState() {
    super.initState();
    // 文字欄位失焦即送出;打字中不送。
    _titleFocus.addListener(_onBlur(_titleFocus));
    _descFocus.addListener(_onBlur(_descFocus));
  }

  VoidCallback _onBlur(FocusNode node) =>
      () => !node.hasFocus ? unawaited(_ctrl.save()) : null;

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  /// 載入完成後把初值灌進欄位一次;之後欄位文字由使用者主導。
  void _seed(EditTripState state) {
    if (state.loading || state.loadFailed) {
      _seeded = false;
      return;
    }
    if (_seeded) return;
    _seeded = true;
    _titleCtl.text = state.title;
    _descCtl.text = state.description;
  }

  /// 「完成」與系統返回共用:先把未送出的變更送完;失敗就攔截讓使用者選重試或放棄。
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      final ctrl = _ctrl;
      if (ctrl.titleBlank) {
        ctrl.restoreTitle();
        _titleCtl.text = ref
            .read(editTripControllerProvider(widget.tripId))
            .title;
      }
      while (!await ctrl.flush()) {
        if (!mounted) return;
        final fields = ctrl.unsentFields.map((f) => f.label).join('、');
        final discard = await showAppDestructiveConfirm(
          context,
          source: TpDestructiveConfirmSource.direct,
          title: '有變更尚未送出',
          message: '$fields 還沒有送出成功。要再試一次，還是放棄這些變更並離開？',
          confirmLabel: '放棄變更',
          cancelLabel: '重試',
        );
        if (!mounted) return;
        if (discard) {
          setState(() => _discard = true);
          break;
        }
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      // 等 PopScope 依最新狀態重建,再真的離開。
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) closeAppRouteOrSheet(context);
    } finally {
      _finishing = false;
    }
  }

  /// 欄位旁的就地錯誤:只出現在送出失敗且仍未生效的欄位,附重試。
  Widget _fieldError(EditTripState state, EditField field) {
    final ctrl = _ctrl;
    final error = ctrl.saveError;
    if (error == null || !ctrl.unsentFields.contains(field)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: TpSpacing.s1),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            TextButton(
              key: ValueKey('edit-retry-${field.name}'),
              onPressed: state.saving ? null : () => unawaited(ctrl.save()),
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }

  /// 離散操作(切換、選擇、增減目的地):改完立刻送。
  void _commitNow(VoidCallback change) {
    change();
    unawaited(_ctrl.save());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editTripControllerProvider(widget.tripId));
    final ctrl = ref.read(editTripControllerProvider(widget.tripId).notifier);
    _seed(state);

    return PopScope(
      canPop: _discard || !ctrl.hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: Scaffold(
        appBar: TpAppBar(
          role: state.loadFailed
              ? TpAppBarRole.modalContent
              : TpAppBarRole.modalInstant,
          title: const Text('編輯行程'),
          primaryActionLabel: state.loadFailed ? null : '完成',
          primaryActionKey: const ValueKey('edit-done'),
          onPrimaryAction: state.loadFailed ? null : () => unawaited(_finish()),
        ),
        bottomNavigationBar: state.saving
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(TpSpacing.s3),
                    child: Semantics(
                      liveRegion: true,
                      child: const Text('儲存中…', textAlign: TextAlign.center),
                    ),
                  ),
                ),
              )
            : null,
        body: state.loading
            ? const AppListLoadingSkeleton(key: ValueKey('edit-trip-loading'))
            : state.loadFailed
            ? _LoadError(onRetry: ctrl.retryLoad)
            : ListView(
                padding: const EdgeInsets.all(TpSpacing.s4),
                children: [
                  const Text('標題與描述離開欄位時自動儲存；目的地、語言與發布狀態改了就會儲存。'),
                  const SizedBox(height: TpSpacing.s3),
                  _title(context, '行程標題'),
                  TextFormField(
                    key: const ValueKey('edit-title'),
                    controller: _titleCtl,
                    focusNode: _titleFocus,
                    decoration: const InputDecoration(
                      hintText: '例如:2026 沖繩自駕',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: ctrl.setTitle,
                  ),
                  if (ctrl.titleBlank)
                    Padding(
                      padding: const EdgeInsets.only(top: TpSpacing.s1),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          '標題不能是空白',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  _fieldError(state, EditField.title),
                  const SizedBox(height: TpSpacing.s5),
                  _title(context, '目的地'),
                  DestinationPicker(
                    destinations: state.destinations,
                    onAdd: (d) => _commitNow(() => ctrl.addDestination(d)),
                    onRemove: (i) =>
                        _commitNow(() => ctrl.removeDestination(i)),
                    onReorder: (o, n) =>
                        _commitNow(() => ctrl.reorderDestination(o, n)),
                  ),
                  _fieldError(state, EditField.destinations),
                  const SizedBox(height: TpSpacing.s5),
                  const Text('日期平移與天數新增、刪除會立即生效；刪除天數無法復原。'),
                  const SizedBox(height: TpSpacing.s3),
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
                        showAppNotice(context, '出發日期已變更');
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
                        showAppNotice(context, '已在最前加入一天');
                      }
                    },
                    onAddEnd: () async {
                      final ok = await ctrl.addDay('end');
                      if (context.mounted && ok) {
                        showAppNotice(context, '已在最後加入一天');
                      }
                    },
                    onCreateMissingDay: (date) async {
                      final ok = await ctrl.addMissingDay(date);
                      if (context.mounted && ok) {
                        showAppNotice(context, '已新增 $date');
                      }
                    },
                    onDelete: (day) => _deleteDay(ctrl, day),
                  ),
                  const SizedBox(height: TpSpacing.s5),
                  _title(context, '描述（用於 SEO,選填）'),
                  TextFormField(
                    key: const ValueKey('edit-desc'),
                    controller: _descCtl,
                    focusNode: _descFocus,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    onChanged: ctrl.setDescription,
                  ),
                  _fieldError(state, EditField.description),
                  const SizedBox(height: TpSpacing.s4),
                  TpPickerField<String>(
                    key: const ValueKey('edit-lang'),
                    label: '顯示語言',
                    value: state.lang,
                    options: _langs,
                    onChanged: (v) => _commitNow(() => ctrl.setLang(v)),
                  ),
                  _fieldError(state, EditField.lang),
                  const SizedBox(height: TpSpacing.s2),
                  if (state.canTogglePublished)
                    SwitchListTile.adaptive(
                      key: const ValueKey('edit-published'),
                      title: const Text('發布（公開上線）'),
                      subtitle: const Text('開啟時，任何知道網址的人都能看到完整行程，包含訂房與緊急聯絡人。'),
                      contentPadding: EdgeInsets.zero,
                      value: state.published,
                      onChanged: (v) => _commitNow(() => ctrl.setPublished(v)),
                    ),
                  _fieldError(state, EditField.published),
                  for (final error in [state.error].nonNulls) ...[
                    const SizedBox(height: TpSpacing.s2),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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

  Future<void> _deleteDay(
    EditTripController controller,
    TripDay day, {
    bool requiresConfirmation = true,
  }) async {
    final label = dayLabel(day.dayNum, title: day.displayTitle);
    if (requiresConfirmation) {
      final confirmed = await showAppDestructiveConfirm(
        context,
        source: TpDestructiveConfirmSource.direct,
        title: '刪除行程日',
        message:
            '確定要刪除「$label」嗎？'
            '這會刪除當天所有停留點，並重新編號後續行程日。此動作無法復原。',
        confirmLabel: '刪除',
      );
      if (!confirmed || !mounted) return;
    }

    final result = await controller.deleteDay(day);
    if (!mounted) return;
    if (result == null) {
      showAppError(
        context,
        '刪除「$label」失敗，請稍後再試',
        onRetry: () => unawaited(_deleteDay(controller, day)),
      );
      return;
    }
    _handleDayDeletionResult(controller, day, result);
  }

  void _handleDayDeletionResult(
    EditTripController controller,
    TripDay day,
    DayDeletionResult result,
  ) {
    final label = dayLabel(day.dayNum, title: day.displayTitle);
    switch (result.resolution) {
      case DayDeletionResolution.committed:
        showAppNotice(
          context,
          _dayDeletedMessage(day, result.removedEntryCount),
        );
        return;
      case DayDeletionResolution.targetStillPresent:
        final latestDay = controller.dayById(day.id) ?? day;
        final latestLabel = dayLabel(
          latestDay.dayNum,
          title: latestDay.displayTitle,
        );
        showAppError(
          context,
          '無法確認「$latestLabel」已刪除；重新整理後仍找到同一個行程日',
          onRetry: () =>
              unawaited(_retryDayDeletionWithFreshIdentity(controller, day.id)),
        );
        return;
      case DayDeletionResolution.verificationRequired:
        final commitKnown = result.removedEntryCount != null;
        showAppError(
          context,
          commitKnown ? '「$label」已刪除，但無法重新整理行程日' : '無法確認「$label」是否已刪除，請重試確認',
          allowDismiss: false,
          onRetry: () =>
              unawaited(_retryDayDeletionResolution(controller, day)),
        );
        return;
    }
  }

  Future<void> _retryDayDeletionResolution(
    EditTripController controller,
    TripDay day,
  ) async {
    final result = await controller.resolvePendingDayDeletion();
    if (!mounted) return;
    if (result == null) {
      showAppError(
        context,
        '無法確認行程日刪除結果，請再試一次',
        allowDismiss: false,
        onRetry: () => unawaited(_retryDayDeletionResolution(controller, day)),
      );
      return;
    }
    _handleDayDeletionResult(controller, day, result);
  }

  Future<void> _retryDayDeletionWithFreshIdentity(
    EditTripController controller,
    int targetId,
  ) async {
    final refreshed = await controller.refreshDaysForDeletionRetry();
    if (!mounted) return;
    if (!refreshed) {
      showAppError(
        context,
        '無法重新確認行程日，請再試一次',
        allowDismiss: false,
        onRetry: () =>
            unawaited(_retryDayDeletionWithFreshIdentity(controller, targetId)),
      );
      return;
    }

    final latestDay = controller.dayById(targetId);
    if (latestDay == null) {
      showAppNotice(context, '此行程日已不存在');
      return;
    }
    await _deleteDay(controller, latestDay);
  }

  String _dayDeletedMessage(TripDay day, int? removedEntryCount) =>
      removedEntryCount != null && removedEntryCount > 0
      ? '${dayLabel(day.dayNum)} 已刪除（連同 $removedEntryCount 個停留點）'
      : '${dayLabel(day.dayNum)} 已刪除';
}

class _DayManagementSection extends StatelessWidget {
  const _DayManagementSection({
    required this.days,
    required this.mutating,
    required this.onAddStart,
    required this.onAddEnd,
    required this.onCreateMissingDay,
    required this.onDelete,
  });

  final List<TripDay> days;
  final bool mutating;
  final VoidCallback onAddStart;
  final VoidCallback onAddEnd;
  final ValueChanged<String> onCreateMissingDay;
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
                icon: const Icon(CupertinoIcons.chevron_left_2),
                label: const Text('加到最前'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('edit-add-day-end'),
                onPressed: mutating ? null : onAddEnd,
                icon: const Icon(CupertinoIcons.chevron_right_2),
                label: const Text('加到最後'),
              ),
            ],
          ),
          const SizedBox(height: TpSpacing.s3),
          if (mutating) ...[
            Semantics(
              key: const ValueKey('edit-day-mutation-progress'),
              liveRegion: true,
              label: '正在更新行程日',
              child: const Row(
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                  SizedBox(width: TpSpacing.s2),
                  Text('正在更新行程日…'),
                ],
              ),
            ),
            const SizedBox(height: TpSpacing.s3),
          ],
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
                      onCreate: () => onCreateMissingDay(missingDate),
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
    required this.onCreate,
  });

  final String date;
  final bool mutating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: TpSpacing.s2),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.ellipsis,
            color: colorScheme.onSurfaceVariant,
            size: 18,
          ),
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
            key: ValueKey('edit-create-missing-day-$date'),
            onPressed: mutating ? null : onCreate,
            icon: const Icon(CupertinoIcons.add),
            label: const Text('新增缺少日期'),
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
                dayLabel(day.dayNum),
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
          icon: const Icon(CupertinoIcons.delete),
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
          Text(
            _dateRangeLabel(context, startDate, endDate),
            style: textTheme.bodyLarge,
          ),
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
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.calendar),
              label: const Text('平移日期'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showShiftDateDialog(
  BuildContext context,
  String? startDate,
) async {
  final now = DateTime.now();
  final selected = await showAppDatePicker(
    context,
    initialDate: _parseIsoDate(startDate) ?? now,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 10, 12, 31),
  );
  return selected == null ? null : _formatIsoDate(selected);
}

String _dateRangeLabel(
  BuildContext context,
  String? startDate,
  String? endDate,
) {
  if (startDate == null || startDate.isEmpty) return '尚無日期資料';
  final start = _parseIsoDate(startDate);
  final startLabel = start == null
      ? startDate
      : formatAppFullDate(context, start);
  if (endDate == null || endDate.isEmpty || endDate == startDate) {
    return startLabel;
  }
  final end = _parseIsoDate(endDate);
  final endLabel = end == null ? endDate : formatAppFullDate(context, end);
  return '$startLabel → $endLabel';
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

/// 初始載入失敗:持續可見的錯誤頁與重試,不給可儲存的空表單(儲存會用空清單覆蓋真實資料)。
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Semantics(
          key: const ValueKey('edit-trip-load-error'),
          liveRegion: true,
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('無法載入行程', style: theme.textTheme.titleMedium),
              const SizedBox(height: TpSpacing.s2),
              Text(
                '請檢查網路後再試一次。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TpSpacing.s4),
              FilledButton(onPressed: onRetry, child: const Text('重試')),
            ],
          ),
        ),
      ),
    );
  }
}
