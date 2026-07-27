import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_feedback.dart';
import '../../app/irreversible_action.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/poi_type.dart';
import '../../models/segment.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_action_item.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_horizontal_selector.dart';
import '../../ui/tp_root_scaffold.dart';
import '../../ui/tp_scope_menu.dart';
import '../../ui/swipe_to_delete.dart';
import '../trips/current_trip_provider.dart';
import '../trips/trip_title_button.dart';
import '../trips/trips_list_screen.dart';
import '../trips/audit/trip_audit_screen.dart';
import '../trips/collab/collab_screen.dart';
import '../trips/edit/edit_trip_screen.dart';
import '../trips/health/trip_health_screen.dart';
import '../trips/share/share_screen.dart';
import 'day_weather.dart';
import 'reorder_helpers.dart';
import 'selected_day_provider.dart';
import 'trip_providers.dart';
import 'trip_notes_screen.dart';
import 'trip_print_screen.dart';
import 'widgets/day_header.dart';
import 'widgets/entry_edit_sheet.dart';
import 'widgets/entry_map_links.dart';
import 'widgets/reorderable_row.dart';
import 'widgets/timeline_entry_tile.dart';
import 'widgets/travel_edit_sheet.dart';
import 'widgets/travel_pill.dart';

enum _TripMoreAction {
  editMode,
  notes,
  editInfo,
  print,
  audit,
  share,
  collab,
  health,
}

enum _EntryMoreAction { reorder, changePoi, edit, move, copy, delete }

/// 行程時間軸畫面：AppBar（可切換 trip／地圖 + 功能選單）→ DAY selector →
/// 逐日 section（day header → 天氣示意 → timeline rail + travel pill）。
class TripTimelineScreen extends ConsumerStatefulWidget {
  const TripTimelineScreen({
    super.key,
    required this.tripId,
    this.initialEntryId,
    this.initialDayNum,
  });

  final String tripId;

  /// 初始聚焦的停留點 id，用於 `/trip/:tripId/stop/:entryId` deep link。
  final int? initialEntryId;

  /// 初始聚焦的天數，用於 `/trips/:tripId?day=N` deep link。
  final int? initialDayNum;

  @override
  ConsumerState<TripTimelineScreen> createState() => _TripTimelineScreenState();
}

class _TripTimelineScreenState extends ConsumerState<TripTimelineScreen> {
  int? _activeDayNum;
  String? _editingTripId;

  bool _wasActiveBranch = true;

  @override
  void initState() {
    super.initState();
    _resolveActiveDayNum();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(currentTripIdProvider.notifier).select(widget.tripId),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant TripTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId ||
        oldWidget.initialDayNum != widget.initialDayNum) {
      _resolveActiveDayNum();
    }
    if (oldWidget.tripId != widget.tripId) {
      _editingTripId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            ref.read(currentTripIdProvider.notifier).select(widget.tripId),
          );
        }
      });
    }
  }

  /// 路由查詢參數優先；缺席時才由共用選取日供值。
  void _resolveActiveDayNum() {
    _activeDayNum =
        widget.initialDayNum ??
        ref.read(selectedDayProvider).dayNumFor(widget.tripId);
  }

  /// 只有前景分支可寫入：StatefulShellRoute 以 Offstage + TickerMode 保活，
  /// 背景分支雖然被 riverpod 暫停訂閱，仍會在「emit 落在切到背景的同一批」時以
  /// 背景身分重建一次並處理到新的 days —— 那一格會把畫面內部的退位寫進共用狀態。
  void _publishSelectedDay(int dayNum) {
    if (!TickerMode.valuesOf(context).enabled) return;
    ref
        .read(selectedDayProvider.notifier)
        .select(tripId: widget.tripId, dayNum: dayNum);
  }

  void _openActionSheet(Widget screen) {
    unawaited(showAppScreenSheet<void>(context, builder: (_) => screen));
  }

  void _handleTripAction(_TripMoreAction action, String tripId) {
    switch (action) {
      case _TripMoreAction.editMode:
        setState(() => _editingTripId = tripId);
      case _TripMoreAction.notes:
        _openActionSheet(TripNotesScreen(tripId: tripId));
      case _TripMoreAction.editInfo:
        _openActionSheet(EditTripScreen(tripId: tripId));
      case _TripMoreAction.print:
        _openActionSheet(TripPrintScreen(tripId: tripId));
      case _TripMoreAction.audit:
        _openActionSheet(TripAuditScreen(tripId: tripId));
      case _TripMoreAction.share:
        _openActionSheet(ShareScreen(tripId: tripId));
      case _TripMoreAction.collab:
        _openActionSheet(CollabScreen(tripId: tripId));
      case _TripMoreAction.health:
        _openActionSheet(TripHealthScreen(tripId: tripId));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget initiallyBelowHeader(Widget child) => Padding(
      padding: EdgeInsets.only(top: TpRootGeometry.initialContentTop(context)),
      child: child,
    );

    final trips = switch (ref.watch(myTripsProvider)) {
      AsyncData(:final value) => value,
      _ => const <TripSummary>[],
    };
    // valuesOf 會建立 InheritedWidget 相依：分支在前景／背景之間切換時本畫面會
    // 重建，才接得住其他 tab 期間變動的共用選取日（保活的分支子樹本身不重建）。
    final isActiveBranch = TickerMode.valuesOf(context).enabled;
    // 時間軸沒有「全部」：前景看到的第幾天必定已寫進共用狀態，所以切回前景時
    // 無條件接手即可，不必（也無從測出）再比對「共用值有沒有被別人改過」。
    if (isActiveBranch && !_wasActiveBranch) {
      final sharedDayNum = ref
          .read(selectedDayProvider)
          .dayNumFor(widget.tripId);
      if (sharedDayNum != null) _activeDayNum = sharedDayNum;
    }
    _wasActiveBranch = isActiveBranch;
    final selectedAsync = isActiveBranch
        ? ref.watch(currentTripIdProvider)
        : ref.read(currentTripIdProvider);
    final sharedTrip = trips
        .where((trip) => trip.tripId == selectedAsync.value)
        .firstOrNull;
    if (isActiveBranch &&
        !selectedAsync.isLoading &&
        sharedTrip != null &&
        sharedTrip.tripId != widget.tripId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final dayNum = _activeDayNum;
        GoRouter.maybeOf(context)?.go(
          '/trips/${Uri.encodeComponent(sharedTrip.tripId)}'
          '${dayNum == null ? '' : '?day=$dayNum'}',
        );
      });
    }
    final tripId = widget.tripId;
    final currentTrip = trips
        .where((trip) => trip.tripId == tripId)
        .firstOrNull;
    final isEditing = _editingTripId == tripId;
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    final trip = tripAsync.value;
    final detailTitle = trip?.title?.trim();
    final detailName = trip?.name.trim();
    final summaryTitle = currentTrip?.title?.trim();
    final summaryName = currentTrip?.name.trim();
    final tripTitle = detailTitle?.isNotEmpty ?? false
        ? detailTitle!
        : summaryTitle?.isNotEmpty ?? false
        ? summaryTitle!
        : detailName?.isNotEmpty ?? false
        ? detailName!
        : summaryName?.isNotEmpty ?? false
        ? summaryName!
        : '行程';
    final fallbackDayNum = daysAsync.value?.firstOrNull?.dayNum;

    return TpRootScaffold(
      header: TpRootHeaderConfig(
        leading: TpToolbarIconButton(
          key: const ValueKey('trip-timeline-back'),
          icon: CupertinoIcons.back,
          tooltip: '返回行程列表',
          // 返回鍵與行程名稱併成同一顆膠囊,所以它自己不再帶玻璃。
          plain: true,
          onPressed: () => context.go('/trips'),
        ),
        title: isEditing
            ? const Text('調整順序')
            : TripTitleButton(
                key: const ValueKey('trip-timeline-trip-picker'),
                currentTripId: tripId,
                currentTitle: tripTitle,
                trips: trips,
                onSelected: (selectedTripId) {
                  unawaited(
                    ref
                        .read(currentTripIdProvider.notifier)
                        .select(selectedTripId),
                  );
                  final dayNum = _activeDayNum ?? fallbackDayNum;
                  context.go(
                    '/trips/${Uri.encodeComponent(selectedTripId)}'
                    '${dayNum == null ? '' : '?day=$dayNum'}',
                  );
                },
              ),
        actions: [
          // 與 root tab「地圖」重複的 bar button 已移除，切換交由 tab 承擔；
          // 目前看的是第幾天改由共用選取日跨 tab 沿用。
          if (isEditing)
            TpToolbarTextButton(
              key: const ValueKey('tp-root-header-primary-action'),
              label: '完成',
              onPressed: () => setState(() => _editingTripId = null),
            )
          else
            TpMoreMenuButton<_TripMoreAction>(
              key: const ValueKey('trip-actions-menu'),
              onSelected: (action) => _handleTripAction(action, tripId),
              items: const [
                TpActionItem(
                  key: ValueKey('trip-edit-mode'),
                  value: _TripMoreAction.editMode,
                  icon: CupertinoIcons.line_horizontal_3,
                  label: '調整順序',
                ),
                TpActionItem(
                  key: ValueKey('trip-action-notes'),
                  value: _TripMoreAction.notes,
                  icon: CupertinoIcons.doc_text,
                  label: '筆記',
                ),
                TpActionItem(
                  key: ValueKey('trip-action-edit-info'),
                  value: _TripMoreAction.editInfo,
                  icon: CupertinoIcons.pencil,
                  label: '行程資料',
                  dividerBefore: true,
                ),
                TpActionItem(
                  key: ValueKey('trip-action-print'),
                  value: _TripMoreAction.print,
                  icon: CupertinoIcons.printer,
                  label: '列印',
                ),
                TpActionItem(
                  key: ValueKey('trip-action-audit'),
                  value: _TripMoreAction.audit,
                  icon: Icons.history_outlined,
                  label: '異動紀錄',
                ),
                TpActionItem(
                  key: ValueKey('trip-action-share'),
                  value: _TripMoreAction.share,
                  icon: Icons.ios_share_outlined,
                  label: '分享連結',
                ),
                TpActionItem(
                  key: ValueKey('trip-action-collab'),
                  value: _TripMoreAction.collab,
                  icon: Icons.group_outlined,
                  label: '共編設定',
                ),
                TpActionItem(
                  key: ValueKey('trip-action-health'),
                  value: _TripMoreAction.health,
                  icon: Icons.health_and_safety_outlined,
                  label: 'AI 健檢',
                ),
              ],
            ),
        ],
      ),
      body: daysAsync.when(
        data: (days) => days.isEmpty
            ? initiallyBelowHeader(const _EmptyTimeline())
            : _TimelineBody(
                days: days,
                tripId: tripId,
                initialEntryId: tripId == widget.tripId
                    ? widget.initialEntryId
                    : null,
                initialDayNum: _activeDayNum ?? widget.initialDayNum,
                isEditing: isEditing,
                onStartEditing: () => setState(() => _editingTripId = tripId),
                onActiveDayChanged: (dayNum) {
                  _activeDayNum = dayNum;
                  _publishSelectedDay(dayNum);
                },
              ),
        loading: () => initiallyBelowHeader(const _TimelineSkeleton()),
        error: (error, stackTrace) => initiallyBelowHeader(
          _TimelineError(
            onRetry: () {
              ref.invalidate(tripDetailProvider(tripId));
              ref.invalidate(tripDaysProvider(tripId));
            },
          ),
        ),
      ),
    );
  }
}

typedef _EntriesSnapshot = Map<int, List<TimelineEntry>>;

/// 日程主體：固定 DAY selector + 單一逐日 Sliver 捲動。
class _TimelineBody extends ConsumerStatefulWidget {
  const _TimelineBody({
    required this.days,
    required this.tripId,
    this.initialEntryId,
    this.initialDayNum,
    required this.isEditing,
    required this.onStartEditing,
    required this.onActiveDayChanged,
  });

  final List<TripDay> days;
  final String tripId;
  final int? initialEntryId;
  final int? initialDayNum;
  final bool isEditing;
  final VoidCallback onStartEditing;
  final ValueChanged<int> onActiveDayChanged;

  @override
  ConsumerState<_TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends ConsumerState<_TimelineBody> {
  Map<int, GlobalKey> _daySectionKeys = {};
  Map<int, GlobalKey> _entryKeys = {};
  late _EntriesSnapshot _visibleEntriesByDayId;
  late int _activeDayNum;
  final _scrollController = ScrollController();
  final _selectorAnchorKey = GlobalKey();
  bool _daySyncScheduled = false;
  int? _programmaticDayNum;
  var _programmaticScrollGeneration = 0;
  int? _expandedEntryId;
  var _reorderSubmitting = false;
  final _settingMasterEntryIds = <int>{};
  Timer? _autoScrollTimer;
  var _autoScrollDelta = 0.0;

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
    _visibleEntriesByDayId = _entriesFromDays(widget.days);
    _activeDayNum =
        _initialDayNum() ??
        (widget.days.isEmpty ? 1 : widget.days.first.dayNum);
    _notifyActiveDayAfterFrame();
    _scheduleInitialFocusScroll();
  }

  @override
  void didUpdateWidget(covariant _TimelineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tripChanged = oldWidget.tripId != widget.tripId;
    final daysChanged = !identical(oldWidget.days, widget.days);
    if (daysChanged && !_reorderSubmitting) {
      _visibleEntriesByDayId = _entriesFromDays(widget.days);
    }
    if (tripChanged) {
      _daySectionKeys = {};
      _entryKeys = {};
      _expandedEntryId = null;
      _reorderSubmitting = false;
      _settingMasterEntryIds.clear();
      _visibleEntriesByDayId = _entriesFromDays(widget.days);
      _rebuildKeys();
      _activeDayNum =
          _initialDayNum() ??
          (widget.days.isEmpty ? 1 : widget.days.first.dayNum);
      _notifyActiveDayAfterFrame();
      _scheduleInitialFocusScroll();
      return;
    }
    if (!oldWidget.isEditing && widget.isEditing) {
      _expandedEntryId = null;
    }
    final entryFocusChanged = oldWidget.initialEntryId != widget.initialEntryId;
    final dayFocusChanged =
        oldWidget.initialDayNum != widget.initialDayNum &&
        _initialDayNum() != _activeDayNum;
    if (daysChanged || entryFocusChanged || dayFocusChanged) {
      _rebuildKeys();
      final previousActiveDayNum = _activeDayNum;
      final initialDayNum = _initialDayNum();
      if (initialDayNum != null) {
        _activeDayNum = initialDayNum;
      } else if (!widget.days.any((day) => day.dayNum == _activeDayNum)) {
        _activeDayNum = widget.days.isEmpty ? 1 : widget.days.first.dayNum;
      }
      if (_activeDayNum != previousActiveDayNum) {
        _notifyActiveDayAfterFrame();
      }
      if (entryFocusChanged || dayFocusChanged) {
        _scheduleInitialFocusScroll();
      }
    }
  }

  void _notifyActiveDayAfterFrame() {
    final activeDayNum = _activeDayNum;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _activeDayNum == activeDayNum) {
        widget.onActiveDayChanged(activeDayNum);
      }
    });
  }

  void _rebuildKeys() {
    final oldDayKeys = _daySectionKeys;
    final oldEntryKeys = _entryKeys;
    _daySectionKeys = {
      for (final day in widget.days)
        day.dayNum: oldDayKeys[day.dayNum] ?? GlobalKey(),
    };
    _entryKeys = {
      for (final day in widget.days)
        for (final entry in day.timeline)
          entry.id: oldEntryKeys[entry.id] ?? GlobalKey(),
    };
  }

  _EntriesSnapshot _entriesFromDays(List<TripDay> days) => {
    for (final day in days) day.id: List<TimelineEntry>.of(day.timeline),
  };

  _EntriesSnapshot _snapshotEntries() => {
    for (final entry in _visibleEntriesByDayId.entries)
      entry.key: List<TimelineEntry>.of(entry.value),
  };

  void _restoreEntries(_EntriesSnapshot snapshot) {
    if (!mounted) return;
    setState(() => _visibleEntriesByDayId = snapshot);
  }

  void _toggleExpanded(int entryId) {
    setState(() {
      _expandedEntryId = _expandedEntryId == entryId ? null : entryId;
    });
  }

  Future<void> _reorderEntry(
    _EntryDragData data,
    int targetDayId,
    int targetIndex,
  ) async {
    if (_reorderSubmitting) return;
    final tripId = widget.tripId;
    final days = widget.days;
    final repository = ref.read(tripRepositoryProvider);
    final before = _snapshotEntries();
    EntryReorderPlan<TimelineEntry> plan;
    try {
      if (!before.containsKey(targetDayId)) {
        throw StateError('target Day no longer exists');
      }
      int? currentSourceDayId;
      var currentSourceIndex = -1;
      for (final day in before.entries) {
        final index = day.value.indexWhere(
          (entry) => entry.id == data.entry.id,
        );
        if (index >= 0) {
          currentSourceDayId = day.key;
          currentSourceIndex = index;
          break;
        }
      }
      if (currentSourceDayId == null) {
        throw StateError('entry no longer exists');
      }
      if (currentSourceDayId != data.sourceDayId) {
        throw StateError('entry moved to another Day');
      }
      plan = planEntryReorder<TimelineEntry>(
        before,
        sourceDayId: currentSourceDayId,
        sourceIndex: currentSourceIndex,
        targetDayId: targetDayId,
        targetIndex: targetIndex,
        idOf: (entry) => entry.id,
      );
    } on Object {
      if (mounted) {
        showAppError(context, '行程內容已更新，請重新操作');
      }
      return;
    }
    final after = plan.entriesByDayId;
    if (_sameEntryOrder(before, after)) return;
    final affected = plan.affectedDayIds;
    setState(() {
      _visibleEntriesByDayId = after;
      _reorderSubmitting = true;
    });
    try {
      await repository.reorderEntries(tripId: tripId, updates: plan.updates);
      final dayNums = [
        for (final day in days)
          if (affected.contains(day.id)) day.dayNum,
      ];
      for (final dayNum in dayNums) {
        try {
          await repository.recomputeTravel(tripId: tripId, day: '$dayNum');
        } on Exception {
          // 排序已完成；交通資料會在下一次刷新自行補齊。
        }
      }
      if (mounted) {
        ref.invalidate(tripDaysProvider(tripId));
        ref.invalidate(tripSegmentsProvider(tripId));
      }
    } on Exception {
      if (mounted) {
        ref.invalidate(tripDaysProvider(tripId));
        if (widget.tripId == tripId) {
          _restoreEntries(before);
          showAppError(context, '排序失敗，已還原原本順序');
        }
      }
    } finally {
      if (mounted && widget.tripId == tripId) {
        setState(() => _reorderSubmitting = false);
      }
    }
  }

  Future<void> _moveEntryToDay(_EntryDragData data) async {
    final tripId = widget.tripId;
    final days = widget.days;
    final targetDayId = await showAppSelectionSheet<int>(
      context,
      title: '移至其他 Day',
      builder: (sheetContext, select) => ListView(
        children: [
          for (final day in days)
            if (day.id != data.sourceDayId)
              ListTile(
                key: ValueKey('entry-move-to-day-${day.id}'),
                title: Text('DAY ${day.dayNum}・${day.displayTitle}'),
                onTap: () => select(day.id),
              ),
        ],
      ),
    );
    if (!mounted || targetDayId == null || widget.tripId != tripId) return;
    await _reorderEntry(
      data,
      targetDayId,
      _visibleEntriesByDayId[targetDayId]?.length ?? 0,
    );
  }

  Future<void> _copyEntryToDay(TimelineEntry entry, int sourceDayId) async {
    final tripId = widget.tripId;
    final days = widget.days;
    final dismissalLocked = ValueNotifier(false);
    try {
      await showAppSelectionSheet<int>(
        context,
        title: '複製到其他 Day',
        dismissalLocked: dismissalLocked,
        builder: (sheetContext, select) => _EntryCopyDaySheet(
          days: days.where((day) => day.id != sourceDayId).toList(),
          onSelected: (targetDayId) async {
            dismissalLocked.value = true;
            try {
              final stillExists = _visibleEntriesByDayId.values.any(
                (entries) => entries.any((item) => item.id == entry.id),
              );
              final targetExists = _visibleEntriesByDayId.containsKey(
                targetDayId,
              );
              if (!stillExists || !targetExists || widget.tripId != tripId) {
                return false;
              }
              await ref
                  .read(tripRepositoryProvider)
                  .copyEntry(
                    tripId: tripId,
                    entryId: entry.id,
                    targetDayId: targetDayId,
                  );
              if (!mounted) return true;
              ref.invalidate(tripDaysProvider(tripId));
              dismissalLocked.value = false;
              if (sheetContext.mounted) select(targetDayId);
              return true;
            } on Object {
              return false;
            } finally {
              dismissalLocked.value = false;
            }
          },
        ),
      );
    } finally {
      dismissalLocked.dispose();
    }
  }

  Future<void> _setMaster(
    TimelineEntry entry,
    EntryPoiInfo alternate,
    int dayNum,
  ) async {
    if (!_settingMasterEntryIds.add(entry.id)) return;
    final tripId = widget.tripId;
    final repository = ref.read(tripRepositoryProvider);
    setState(() {});
    try {
      await repository.setEntryMaster(
        tripId: tripId,
        entryId: entry.id,
        poiId: alternate.poiId,
        entryPoisVersion: entry.entryPoisVersion,
      );
      try {
        await repository.recomputeTravel(tripId: tripId, day: '$dayNum');
      } on Exception {
        // 正選已更新；交通資料可稍後重算。
      }
      if (mounted) {
        ref.invalidate(tripDaysProvider(tripId));
        ref.invalidate(tripSegmentsProvider(tripId));
      }
    } on Exception {
      if (mounted && widget.tripId == tripId) {
        showAppError(context, '設為正選失敗，請重新載入後再試');
      }
    } finally {
      _settingMasterEntryIds.remove(entry.id);
      if (mounted && widget.tripId == tripId) setState(() {});
    }
  }

  void _autoScroll(DragUpdateDetails details) {
    if (!_scrollController.hasClients) return;
    final height = MediaQuery.sizeOf(context).height;
    var delta = 0.0;
    if (details.globalPosition.dy < TpRootGeometry.headerBottom(context) + 80) {
      delta = -16;
    } else if (details.globalPosition.dy >
        height - TpRootTabGeometry.clearance(context) - 80) {
      delta = 16;
    }
    if (delta == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScrollDelta = delta;
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _autoScrollTick(),
    );
  }

  void _autoScrollTick() {
    if (!mounted || !_scrollController.hasClients) {
      _stopAutoScroll();
      return;
    }
    final position = _scrollController.position;
    final target = (position.pixels + _autoScrollDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) {
      _stopAutoScroll();
      return;
    }
    _scrollController.jumpTo(target);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollDelta = 0;
  }

  int? _initialDayNum() {
    final entryId = widget.initialEntryId;
    if (entryId != null) {
      for (final day in widget.days) {
        if (day.timeline.any((entry) => entry.id == entryId)) {
          return day.dayNum;
        }
      }
    }
    final dayNum = widget.initialDayNum;
    if (dayNum != null && widget.days.any((day) => day.dayNum == dayNum)) {
      return dayNum;
    }
    return null;
  }

  void _scheduleInitialFocusScroll() {
    final entryId = widget.initialEntryId;
    final dayNum = entryId == null ? widget.initialDayNum : null;
    if (entryId == null && dayNum == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = entryId != null
          ? _entryKeys[entryId]?.currentContext
          : _daySectionKeys[dayNum]?.currentContext;
      if (targetContext == null) return;
      final renderObject = targetContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: TpMotion.resolve(context, TpMotion.normal),
        curve: TpMotion.appleEase,
      );
    });
  }

  bool _handleTimelineScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _programmaticDayNum != null) return false;
    if (_daySyncScheduled) return false;
    _daySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _daySyncScheduled = false;
      if (mounted && _programmaticDayNum == null) {
        _syncActiveDayFromViewport();
      }
    });
    return false;
  }

  void _syncActiveDayFromViewport() {
    final selectorBox =
        _selectorAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (selectorBox == null || !selectorBox.hasSize || widget.days.isEmpty) {
      return;
    }
    final activationY = selectorBox
        .localToGlobal(Offset(0, selectorBox.size.height))
        .dy;
    final position = _scrollController.position;
    var next = widget.days.first.dayNum;
    if (position.pixels > position.minScrollExtent + 1 &&
        position.extentAfter <= 1) {
      next = widget.days.last.dayNum;
    } else {
      for (final day in widget.days) {
        final box = _daySectionKeys[day.dayNum]?.currentContext
            ?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        if (box.localToGlobal(Offset.zero).dy <= activationY + 1) {
          next = day.dayNum;
        } else {
          break;
        }
      }
    }
    if (next != _activeDayNum) {
      setState(() => _activeDayNum = next);
      widget.onActiveDayChanged(next);
    }
  }

  Future<void> _scrollToDay(int dayNum) async {
    final targetContext = _daySectionKeys[dayNum]?.currentContext;
    if (targetContext == null || !_scrollController.hasClients) return;
    final object = targetContext.findRenderObject();
    if (object == null) return;
    final viewport = RenderAbstractViewport.of(object);
    final reveal = viewport.getOffsetToReveal(object, 0).offset;
    final position = _scrollController.position;
    final target =
        (reveal - _selectorTop(targetContext) - _selectorExtent(targetContext))
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    final generation = ++_programmaticScrollGeneration;
    _programmaticDayNum = dayNum;
    setState(() => _activeDayNum = dayNum);
    widget.onActiveDayChanged(dayNum);
    final duration = TpMotion.resolve(targetContext, TpMotion.normal);
    if (duration == Duration.zero) {
      _scrollController.jumpTo(target);
    } else {
      await _scrollController.animateTo(
        target,
        duration: duration,
        curve: TpMotion.appleEase,
      );
    }
    if (!mounted || generation != _programmaticScrollGeneration) return;
    _programmaticDayNum = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleTimelineScroll,
      child: CustomScrollView(
        key: const ValueKey('trip-timeline-scroll'),
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _DaySelectorHeaderDelegate(
              extent: _selectorExtent(context),
              topInset: _selectorTop(context),
              child: KeyedSubtree(
                key: _selectorAnchorKey,
                child: _buildDaySelector(context),
              ),
            ),
          ),
          for (final day in widget.days)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
              sliver: SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: ValueKey('day-section-${day.dayNum}'),
                  child: _DaySection(
                    key: _daySectionKeys[day.dayNum],
                    day: day,
                    dayCount: widget.days.length,
                    timeline:
                        _visibleEntriesByDayId[day.id] ??
                        const <TimelineEntry>[],
                    tripId: widget.tripId,
                    entryKeys: _entryKeys,
                    focusedEntryId: widget.initialEntryId,
                    isEditing: widget.isEditing,
                    reorderSubmitting: _reorderSubmitting,
                    expandedEntryId: _expandedEntryId,
                    settingMasterEntryIds: _settingMasterEntryIds,
                    onToggleExpanded: _toggleExpanded,
                    onStartEditing: widget.onStartEditing,
                    onReorder: _reorderEntry,
                    onMoveToDay: _moveEntryToDay,
                    onCopyToDay: _copyEntryToDay,
                    onDragUpdate: _autoScroll,
                    onDragStopped: _stopAutoScroll,
                    onSetMaster: _setMaster,
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: TpRootTabGeometry.clearance(context) + TpSpacing.s4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s3,
        0,
        TpSpacing.s3,
        TpSpacing.s1,
      ),
      child: TpHorizontalSelector<int>(
        key: const ValueKey('trip-timeline-view-day-selector'),
        value: _activeDayNum,
        options: [
          for (final day in widget.days)
            TpScopeOption(
              value: day.dayNum,
              label: 'DAY ${day.dayNum}',
              semanticsLabel: '第 ${day.dayNum} 天，共 ${widget.days.length} 天',
              key: ValueKey('day-pill-${day.dayNum}'),
            ),
        ],
        onSelected: (value) {
          HapticFeedback.selectionClick();
          unawaited(_scrollToDay(value));
        },
      ),
    );
  }

  double _selectorTop(BuildContext context) =>
      TpRootGeometry.headerBottom(context) + TpSpacing.s2;

  double _selectorExtent(BuildContext context) =>
      TpHorizontalSelector.preferredHeight(context) + TpSpacing.s1;
}

class _DaySelectorHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DaySelectorHeaderDelegate({
    required this.extent,
    required this.topInset,
    required this.child,
  });

  final double extent;
  final double topInset;
  final Widget child;

  @override
  double get minExtent => topInset + extent;

  @override
  double get maxExtent => topInset + extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: extent,
          child: child,
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DaySelectorHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent ||
        oldDelegate.topInset != topInset ||
        oldDelegate.child != child;
  }
}

/// 單日 entry reorder 的 batch updates（同天,dayId 留 null）。共用 [reorderedSortOrders]。
List<({int id, int sortOrder, int? dayId})> computeReorderUpdates(
  List<int> entryIds,
  int oldIndex,
  int newIndex,
) {
  return [
    for (final u in reorderedSortOrders(entryIds, oldIndex, newIndex))
      (id: u.id, sortOrder: u.sortOrder, dayId: null),
  ];
}

// ponytail: process-local auto recompute UI state; move to repo helper if retries need persistence.
final _requestedTravelGapRecomputes = <String>{};
final _stalledTravelRecomputeScopes = <String>{};

/// 單日 section：day header → hotel 卡 → entries（拖曳排序 + 左滑刪除 + 點擊編輯）→ 新增鈕。
class _DaySection extends ConsumerWidget {
  const _DaySection({
    super.key,
    required this.tripId,
    required this.day,
    required this.dayCount,
    required this.timeline,
    required this.entryKeys,
    this.focusedEntryId,
    required this.isEditing,
    required this.reorderSubmitting,
    required this.expandedEntryId,
    required this.settingMasterEntryIds,
    required this.onToggleExpanded,
    required this.onStartEditing,
    required this.onReorder,
    required this.onMoveToDay,
    required this.onCopyToDay,
    required this.onDragUpdate,
    required this.onDragStopped,
    required this.onSetMaster,
  });

  final String tripId;
  final TripDay day;
  final int dayCount;
  final List<TimelineEntry> timeline;
  final Map<int, GlobalKey> entryKeys;
  final int? focusedEntryId;
  final bool isEditing;
  final bool reorderSubmitting;
  final int? expandedEntryId;
  final Set<int> settingMasterEntryIds;
  final ValueChanged<int> onToggleExpanded;
  final VoidCallback onStartEditing;
  final Future<void> Function(
    _EntryDragData data,
    int targetDayId,
    int targetIndex,
  )
  onReorder;
  final Future<void> Function(_EntryDragData data) onMoveToDay;
  final Future<void> Function(TimelineEntry entry, int sourceDayId) onCopyToDay;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragStopped;
  final Future<void> Function(
    TimelineEntry entry,
    EntryPoiInfo alternate,
    int dayNum,
  )
  onSetMaster;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) {
    return confirmAndDelete(
      context,
      title: '刪除停留點',
      message: '刪除「${entry.title}」後，相關交通時間將重新計算。此動作無法復原。',
      delete: () async {
        await ref
            .read(tripRepositoryProvider)
            .deleteEntry(tripId: tripId, entryId: entry.id);
        try {
          await _recomputeAndRefresh(ref);
        } on Object {
          // DELETE 已成功，交通重算屬於次要修復，不可因此允許再次刪除。
        }
      },
      onSuccess: () => ref.invalidate(tripDaysProvider(tripId)),
    );
  }

  /// reorder 後重算交通,完成再刷新（交通重算失敗不影響排序結果）。
  Future<void> _recomputeAndRefresh(WidgetRef ref) async {
    await _recomputeDay(ref, day.dayNum);
  }

  Future<void> _recomputeDay(
    WidgetRef ref,
    int dayNum, {
    bool auto = false,
  }) async {
    // 這裡的 ref 屬於 _DaySection 的 element。unmount 之後碰它會擲 StateError,
    // 而 StateError 不是 Exception 子類 —— 下面的 `on Exception` 攔不到,會一路
    // 逃成未捕捉例外把 App 打掛。auto 路徑由 build() 以 unawaited 觸發,和使用者
    // 離開頁面天然競速,所以每次碰 ref 前都要確認還活著。
    // (`ref.context.mounted` 正是 riverpod 內部 _assertNotDisposed 的同一條件。)
    if (!ref.context.mounted) return;
    final scope = '$tripId:$dayNum';
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId: tripId, day: '$dayNum');
      // scope 記錄是 module-level state,unmount 後仍要更新 —— 該日之後重新
      // mount 時要看到正確的「待更新」狀態。只有碰 ref 需要守衛。
      _stalledTravelRecomputeScopes.remove(scope);
      if (!ref.context.mounted) return;
      ref.invalidate(tripDaysProvider(tripId));
      ref.invalidate(tripSegmentsProvider(tripId));
    } on Exception {
      if (auto) {
        _stalledTravelRecomputeScopes.add(scope);
        if (!ref.context.mounted) return;
        ref.invalidate(tripSegmentsProvider(tripId));
      }
      // 交通重算失敗忽略
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsAsync = ref.watch(tripSegmentsProvider(tripId));
    final segments = switch (segmentsAsync) {
      AsyncData(:final value) => value,
      _ => const <TripSegment>[],
    };
    final segmentsReady = segmentsAsync is AsyncData<List<TripSegment>>;
    if (segmentsReady) {
      _requestMissingSegmentRecompute(ref, timeline, segments);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayHeader(day: day, segments: segments),
        const SizedBox(height: TpSpacing.s3),
        DayWeatherCard(day: day),
        const SizedBox(height: TpSpacing.s3),
        if (isEditing) ...[
          for (var index = 0; index < timeline.length; index++) ...[
            _EntryDropTarget(
              targetDayId: day.id,
              targetIndex: index,
              onAccept: onReorder,
            ),
            _buildEntryRow(context, ref, index, segments, segmentsReady),
          ],
          _EntryDropTarget(
            targetDayId: day.id,
            targetIndex: timeline.length,
            empty: timeline.isEmpty,
            onAccept: onReorder,
          ),
        ] else
          for (var index = 0; index < timeline.length; index++)
            _buildEntryRow(context, ref, index, segments, segmentsReady),
        const SizedBox(height: TpSpacing.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('add-entry-${day.dayNum}'),
            onPressed: () => context.push(
              '/trips/${Uri.encodeComponent(tripId)}/entries/new'
              '?day=${day.dayNum}&mode=search',
            ),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('新增停留點'),
          ),
        ),
        const SizedBox(height: TpSpacing.s6),
      ],
    );
  }

  Widget _buildEntryRow(
    BuildContext context,
    WidgetRef ref,
    int index,
    List<TripSegment> segments,
    bool segmentsReady,
  ) {
    final entry = timeline[index];
    final previous = index > 0 ? timeline[index - 1] : null;
    final travel = previous?.travel;
    final travelSegment = previous == null
        ? null
        : _findSegment(segments, previous.id, entry.id);
    final expanded = !isEditing && expandedEntryId == entry.id;
    final tile = TimelineEntryTile(
      entry: entry,
      number: index + 1,
      isFirst: index == 0,
      isFocused: entry.id == focusedEntryId,
      compact: isEditing,
      expanded: expanded,
      onTap: isEditing ? null : () => onToggleExpanded(entry.id),
      onEditTime: isEditing
          ? null
          : () => context.push(
              '/trips/${Uri.encodeComponent(tripId)}/entries/${entry.id}/edit',
            ),
      mapLinks: isEditing || entry.master == null
          ? null
          : EntryMapLinks(
              poi: entry.master!,
              onError: () => showAppError(context, '無法開啟地圖，請稍後再試'),
            ),
      expandedChild: expanded
          ? _AlternatesPanel(
              entry: entry,
              settingMaster: settingMasterEntryIds.contains(entry.id),
              onChangePoi: () => context.push(
                '/trips/${Uri.encodeComponent(tripId)}/entries/${entry.id}/pois',
              ),
              onSetMaster: (alternate) =>
                  onSetMaster(entry, alternate, day.dayNum),
              onMapError: () => showAppError(context, '無法開啟地圖，請稍後再試'),
            )
          : null,
      trailing: isEditing
          ? _EntryDragHandle(
              data: _EntryDragData(
                sourceDayId: day.id,
                sourceIndex: index,
                entry: entry,
              ),
              enabled: !reorderSubmitting,
              positionLabel:
                  'DAY ${day.dayNum}，第 ${index + 1} 項，共 ${timeline.length} 項',
              onMoveUp: index == 0
                  ? null
                  : () => unawaited(
                      onReorder(
                        _EntryDragData(
                          sourceDayId: day.id,
                          sourceIndex: index,
                          entry: entry,
                        ),
                        day.id,
                        index - 1,
                      ),
                    ),
              onMoveDown: index == timeline.length - 1
                  ? null
                  : () => unawaited(
                      onReorder(
                        _EntryDragData(
                          sourceDayId: day.id,
                          sourceIndex: index,
                          entry: entry,
                        ),
                        day.id,
                        index + 2,
                      ),
                    ),
              onMoveToDay: dayCount > 1
                  ? () => unawaited(
                      onMoveToDay(
                        _EntryDragData(
                          sourceDayId: day.id,
                          sourceIndex: index,
                          entry: entry,
                        ),
                      ),
                    )
                  : null,
              onDragUpdate: onDragUpdate,
              onDragStopped: onDragStopped,
              feedbackWidth:
                  MediaQuery.sizeOf(context).width -
                  TpSpacing.s4 * 2 -
                  kTimelineRailWidth -
                  10,
            )
          : _entryMenu(context, ref, entry, index),
    );
    final row = isEditing
        ? tile
        : SwipeToDelete(
            dismissKey: ValueKey('entry-dismiss-${entry.id}'),
            actionLabel: '刪除景點',
            onDelete: () => _confirmDelete(context, ref, entry),
            backgroundMargin: const EdgeInsets.only(bottom: TpSpacing.s3),
            child: tile,
          );
    return Container(
      key: entryKeys[entry.id],
      child: Column(
        key: ValueKey('entry-${entry.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isEditing &&
              previous != null &&
              (travel != null || segmentsReady))
            _TravelRow(
              travel: travel,
              segment: travelSegment,
              tripId: tripId,
              fromEntryId: previous.id,
              toEntryId: entry.id,
              segmentsReady: segmentsReady,
              missingSegment:
                  segmentsReady && travelSegment == null && travel != null,
              recomputeStalled: _stalledTravelRecomputeScopes.contains(
                '$tripId:${day.dayNum}',
              ),
              missingCoords: _missingTravelCoords(previous, entry),
            ),
          row,
        ],
      ),
    );
  }

  Widget _entryMenu(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
    int index,
  ) {
    final canChangeDay = dayCount > 1;
    return TpMoreMenuButton<_EntryMoreAction>(
      key: ValueKey('entry-more-${entry.id}'),
      tooltip: '景點操作',
      items: [
        TpActionItem(
          key: ValueKey('entry-reorder-${entry.id}'),
          value: _EntryMoreAction.reorder,
          label: '重新排序',
          icon: CupertinoIcons.line_horizontal_3,
        ),
        TpActionItem(
          key: ValueKey('entry-change-poi-${entry.id}'),
          value: _EntryMoreAction.changePoi,
          label: '換景點',
          icon: CupertinoIcons.arrow_2_circlepath,
        ),
        TpActionItem(
          key: ValueKey('entry-edit-${entry.id}'),
          value: _EntryMoreAction.edit,
          label: '編輯景點',
          icon: CupertinoIcons.pencil,
          dividerBefore: true,
        ),
        TpActionItem(
          key: ValueKey('entry-move-${entry.id}'),
          value: _EntryMoreAction.move,
          label: '移動到其他天',
          semanticLabel: canChangeDay ? null : '移動到其他天，目前行程只有一天，無法使用',
          icon: CupertinoIcons.arrow_right_arrow_left,
          enabled: canChangeDay,
        ),
        TpActionItem(
          key: ValueKey('entry-copy-${entry.id}'),
          value: _EntryMoreAction.copy,
          label: '複製到其他天',
          semanticLabel: canChangeDay ? null : '複製到其他天，目前行程只有一天，無法使用',
          icon: CupertinoIcons.doc_on_doc,
          dividerBefore: true,
          enabled: canChangeDay,
        ),
        TpActionItem(
          key: ValueKey('entry-delete-${entry.id}'),
          value: _EntryMoreAction.delete,
          label: '刪除景點',
          icon: CupertinoIcons.delete,
          role: TpActionRole.destructive,
        ),
      ],
      onSelected: (action) =>
          _handleEntryAction(context, ref, entry, index, action),
    );
  }

  void _handleEntryAction(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
    int index,
    _EntryMoreAction action,
  ) {
    final base = '/trips/${Uri.encodeComponent(tripId)}/entries/${entry.id}';
    switch (action) {
      case _EntryMoreAction.reorder:
        onStartEditing();
      case _EntryMoreAction.changePoi:
        context.push('$base/pois');
      case _EntryMoreAction.edit:
        unawaited(
          showEntryEditSheet(
            context,
            tripId: tripId,
            args: EntryEditExisting(entry),
          ),
        );
      case _EntryMoreAction.move:
        unawaited(
          onMoveToDay(
            _EntryDragData(
              sourceDayId: day.id,
              sourceIndex: index,
              entry: entry,
            ),
          ),
        );
      case _EntryMoreAction.copy:
        unawaited(onCopyToDay(entry, day.id));
      case _EntryMoreAction.delete:
        unawaited(_confirmDelete(context, ref, entry));
    }
  }

  void _requestMissingSegmentRecompute(
    WidgetRef ref,
    List<TimelineEntry> timeline,
    List<TripSegment> segments,
  ) {
    final gapIds = <String>[];
    for (var i = 1; i < timeline.length; i++) {
      final previous = timeline[i - 1];
      final entry = timeline[i];
      if (previous.travel == null) continue;
      if (_missingTravelCoords(previous, entry)) continue;
      final segment = _findSegment(segments, previous.id, entry.id);
      if (segment == null || segment.isStale) {
        gapIds.add('${previous.id}-${entry.id}');
      }
    }
    if (gapIds.isEmpty) return;

    final key = '$tripId:${day.dayNum}:${gapIds.join('|')}';
    if (!_requestedTravelGapRecomputes.add(key)) return;
    _stalledTravelRecomputeScopes.remove('$tripId:${day.dayNum}');
    unawaited(_recomputeDay(ref, day.dayNum, auto: true));
  }
}

bool _sameEntryOrder(_EntriesSnapshot a, _EntriesSnapshot b) {
  if (a.length != b.length) return false;
  for (final day in a.entries) {
    final other = b[day.key];
    if (other == null || other.length != day.value.length) return false;
    for (var index = 0; index < day.value.length; index++) {
      if (day.value[index].id != other[index].id) return false;
    }
  }
  return true;
}

class _EntryCopyDaySheet extends StatefulWidget {
  const _EntryCopyDaySheet({required this.days, required this.onSelected});

  final List<TripDay> days;
  final Future<bool> Function(int targetDayId) onSelected;

  @override
  State<_EntryCopyDaySheet> createState() => _EntryCopyDaySheetState();
}

class _EntryCopyDaySheetState extends State<_EntryCopyDaySheet> {
  var _submitting = false;
  String? _error;

  Future<void> _select(int dayId) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final succeeded = await widget.onSelected(dayId);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!succeeded) {
        _error = '複製失敗，目標 Day 已保留，請重試';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (_submitting)
          Semantics(
            liveRegion: true,
            label: '正在複製停留點',
            child: const LinearProgressIndicator(
              key: ValueKey('entry-copy-progress'),
            ),
          ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s3),
              child: Text(
                _error!,
                key: const ValueKey('entry-copy-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        for (final day in widget.days)
          ListTile(
            key: ValueKey('entry-copy-to-day-${day.id}'),
            enabled: !_submitting,
            title: Text('DAY ${day.dayNum}・${day.displayTitle}'),
            onTap: _submitting ? null : () => _select(day.id),
          ),
      ],
    );
  }
}

class _EntryDragData {
  const _EntryDragData({
    required this.sourceDayId,
    required this.sourceIndex,
    required this.entry,
  });

  final int sourceDayId;
  final int sourceIndex;
  final TimelineEntry entry;
}

class _EntryDragHandle extends StatelessWidget {
  const _EntryDragHandle({
    required this.data,
    required this.enabled,
    required this.positionLabel,
    this.onMoveUp,
    this.onMoveDown,
    this.onMoveToDay,
    required this.onDragUpdate,
    required this.onDragStopped,
    required this.feedbackWidth,
  });

  final _EntryDragData data;
  final bool enabled;
  final String positionLabel;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onMoveToDay;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragStopped;
  final double feedbackWidth;

  @override
  Widget build(BuildContext context) {
    void invoke(VoidCallback callback) {
      HapticFeedback.selectionClick();
      callback();
    }

    final handle = Semantics(
      key: ValueKey('entry-drag-${data.entry.id}'),
      button: true,
      enabled: enabled,
      liveRegion: !enabled,
      label: '拖曳調整「${data.entry.title}」順序，$positionLabel',
      value: enabled ? null : '正在更新',
      hint: enabled && onMoveToDay != null ? '按下可選擇其他 Day' : null,
      onTap: enabled && onMoveToDay != null ? () => invoke(onMoveToDay!) : null,
      customSemanticsActions: {
        if (enabled && onMoveUp != null)
          CustomSemanticsAction(label: '上移'): () => invoke(onMoveUp!),
        if (enabled && onMoveDown != null)
          CustomSemanticsAction(label: '下移'): () => invoke(onMoveDown!),
        if (enabled && onMoveToDay != null)
          CustomSemanticsAction(label: '移至其他 Day'): () => invoke(onMoveToDay!),
      },
      child: const TpInlineEditControlVisual(
        icon: CupertinoIcons.line_horizontal_3,
      ),
    );
    if (!enabled) return Opacity(opacity: 0.45, child: handle);
    final keyboardHandle = CallbackShortcuts(
      bindings: {
        if (onMoveUp != null)
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              invoke(onMoveUp!),
        if (onMoveDown != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              invoke(onMoveDown!),
        if (onMoveToDay != null)
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              invoke(onMoveToDay!),
      },
      child: Focus(child: handle),
    );
    return Draggable<_EntryDragData>(
      data: data,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: HapticFeedback.selectionClick,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => onDragStopped(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          key: ValueKey('entry-drag-feedback-${data.entry.id}'),
          width: feedbackWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s4),
              child: Text(
                data.entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.30, child: keyboardHandle),
      child: keyboardHandle,
    );
  }
}

class _EntryDropTarget extends StatelessWidget {
  const _EntryDropTarget({
    required this.targetDayId,
    required this.targetIndex,
    required this.onAccept,
    this.empty = false,
  });

  final int targetDayId;
  final int targetIndex;
  final bool empty;
  final Future<void> Function(
    _EntryDragData data,
    int targetDayId,
    int targetIndex,
  )
  onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_EntryDragData>(
      key: ValueKey('entry-drop-$targetDayId-$targetIndex'),
      onWillAcceptWithDetails: (_) {
        HapticFeedback.selectionClick();
        return true;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.lightImpact();
        unawaited(onAccept(details.data, targetDayId, targetIndex));
      },
      builder: (context, candidates, rejected) => SizedBox(
        height: empty ? TpSpacing.tapMin : 12,
        child: AnimatedContainer(
          duration: TpMotion.resolve(context, TpMotion.fast),
          margin: const EdgeInsets.symmetric(horizontal: kTimelineRailWidth),
          decoration: BoxDecoration(
            color: candidates.isEmpty
                ? Colors.transparent
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: candidates.isEmpty
                ? null
                : Border.all(color: Theme.of(context).colorScheme.primary),
          ),
          alignment: Alignment.center,
          child: candidates.isNotEmpty
              ? Text(
                  '放到這裡',
                  key: ValueKey('entry-drop-label-$targetDayId-$targetIndex'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : empty
              ? Text(
                  '拖曳景點到 DAY',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _AlternatesPanel extends StatelessWidget {
  const _AlternatesPanel({
    required this.entry,
    required this.settingMaster,
    required this.onChangePoi,
    required this.onSetMaster,
    required this.onMapError,
  });

  final TimelineEntry entry;
  final bool settingMaster;
  final VoidCallback onChangePoi;
  final Future<void> Function(EntryPoiInfo alternate) onSetMaster;
  final VoidCallback onMapError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('entry-alternates-${entry.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('備選景點', style: theme.textTheme.titleSmall),
          const SizedBox(height: TpSpacing.s2),
          if (entry.alternates.isEmpty) ...[
            Text(
              '尚無備選景點',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton.icon(
              key: ValueKey('entry-change-poi-empty-${entry.id}'),
              onPressed: onChangePoi,
              icon: const Icon(CupertinoIcons.arrow_2_circlepath),
              label: const Text('換景點'),
            ),
          ] else
            for (final alternate in entry.alternates)
              Padding(
                padding: const EdgeInsets.only(bottom: TpSpacing.s2),
                child: _AlternateCard(
                  alternate: alternate,
                  settingMaster: settingMaster,
                  onSetMaster: () => onSetMaster(alternate),
                  onMapError: onMapError,
                ),
              ),
        ],
      ),
    );
  }
}

class _AlternateCard extends StatelessWidget {
  const _AlternateCard({
    required this.alternate,
    required this.settingMaster,
    required this.onSetMaster,
    required this.onMapError,
  });

  final EntryPoiInfo alternate;
  final bool settingMaster;
  final Future<void> Function() onSetMaster;
  final VoidCallback onMapError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category =
        poiCategoryLabel(alternate.category) ?? kPoiTypeLabels[alternate.type];
    final facts = <String>[
      if (alternate.rating != null) '★ ${alternate.rating!.toStringAsFixed(1)}',
      if (alternate.price?.trim().isNotEmpty ?? false) alternate.price!.trim(),
      if (alternate.hours?.trim().isNotEmpty ?? false) alternate.hours!.trim(),
      if (alternate.reservation?.trim().isNotEmpty ?? false)
        alternate.reservation!.trim(),
    ];
    return Container(
      key: ValueKey('alternate-${alternate.poiId}'),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: TpSpacing.s2,
            runSpacing: TpSpacing.s1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                alternate.name?.trim().isNotEmpty ?? false
                    ? alternate.name!.trim()
                    : '未命名景點',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (category != null)
                Text(
                  category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TpSpacing.s1),
          EntryMapLinks(poi: alternate, onError: onMapError),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: TpSpacing.s1),
            Text(
              facts.join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (alternate.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: TpSpacing.s1),
            Text(alternate.description!.trim()),
          ],
          if (alternate.note?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: TpSpacing.s1),
            Text('備註：${alternate.note!.trim()}'),
          ],
          const SizedBox(height: TpSpacing.s2),
          FilledButton.tonalIcon(
            key: ValueKey('alternate-set-master-${alternate.poiId}'),
            onPressed: settingMaster ? null : () => unawaited(onSetMaster()),
            icon: settingMaster
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.arrow_turn_down_left),
            label: const Text('設為正選'),
          ),
        ],
      ),
    );
  }
}

/// 依相鄰兩端 entry id 比對 travel pill 對應的 segment。
TripSegment? _findSegment(List<TripSegment> segments, int fromId, int toId) {
  for (final s in segments) {
    if (s.fromEntryId == fromId && s.toEntryId == toId) return s;
  }
  return null;
}

bool _missingTravelCoords(TimelineEntry from, TimelineEntry to) {
  bool missing(TimelineEntry entry) {
    final master = entry.master;
    return master?.lat == null || master?.lng == null;
  }

  return missing(from) || missing(to);
}

/// travel pill 列：沿用 D1 的固定 rail + 內容起點，可編輯或補建交通 segment。
class _TravelRow extends StatelessWidget {
  const _TravelRow({
    required this.travel,
    required this.fromEntryId,
    required this.toEntryId,
    required this.segmentsReady,
    this.segment,
    this.tripId,
    this.missingSegment = false,
    this.recomputeStalled = false,
    this.missingCoords = false,
  });

  final Travel? travel;
  final int fromEntryId;
  final int toEntryId;
  final bool segmentsReady;
  final TripSegment? segment;
  final String? tripId;
  final bool missingSegment;
  final bool recomputeStalled;
  final bool missingCoords;

  @override
  Widget build(BuildContext context) {
    final railLineColor = Theme.of(context).colorScheme.outlineVariant;
    final seg = segment;
    final needsStatus = missingSegment || seg?.isStale == true;
    Widget pill = TravelPill(
      travel: travel,
      segment: seg,
      missing: seg == null && travel == null,
      statusLabel: needsStatus
          ? (missingCoords
                ? '缺座標，無法計算車程'
                : recomputeStalled
                ? '車程待更新'
                : '車程重新計算中')
          : null,
    );
    final id = tripId;
    final canEdit = seg != null || segmentsReady;
    if (id != null && canEdit) {
      pill = InkWell(
        key: seg != null
            ? ValueKey('travel-edit-${seg.id}')
            : ValueKey('travel-create-$fromEntryId-$toEntryId'),
        onTap: () => showTravelEditSheet(
          context,
          tripId: id,
          segment: seg,
          fromEntryId: fromEntryId,
          toEntryId: toEntryId,
          initialMode: travel?.type,
          initialSubmode: travel?.submode,
          initialMin: travel?.min,
          initialSource: travel?.source,
          initialNoTravel: travel?.sameplace ?? false,
        ),
        borderRadius: BorderRadius.circular(TpRadius.md),
        child: pill,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: kTimelineRailWidth,
              child: Center(child: Container(width: 1, color: railLineColor)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: pill),
            ),
          ],
        ),
      ),
    );
  }
}

/// loading skeleton：非動畫灰階條列。
class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('timeline-loading-state'),
      liveRegion: true,
      label: '正在載入行程時間軸',
      child: ListView(
        key: const ValueKey('timeline-skeleton'),
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: const [
          _SkeletonBlock(width: 120, height: 14),
          SizedBox(height: TpSpacing.s3),
          _SkeletonBlock(height: 72),
          SizedBox(height: TpSpacing.s3),
          _SkeletonBlock(height: 72),
          SizedBox(height: TpSpacing.s3),
          _SkeletonBlock(height: 72),
          SizedBox(height: TpSpacing.s6),
          _SkeletonBlock(width: 120, height: 14),
          SizedBox(height: TpSpacing.s3),
          _SkeletonBlock(height: 72),
          SizedBox(height: TpSpacing.s3),
          _SkeletonBlock(height: 72),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
    );
  }
}

/// 載入失敗：訊息 + 重試。
class _TimelineError extends StatelessWidget {
  const _TimelineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      key: const ValueKey('timeline-error-state'),
      liveRegion: true,
      label: '行程時間軸載入失敗',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '行程載入失敗，請檢查網路後再試',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

/// 尚無日程資料的空狀態。
class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        '這趟行程還沒有任何安排',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
