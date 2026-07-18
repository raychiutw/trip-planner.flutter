import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/segment.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_account_avatar_button.dart';
import '../../ui/tp_action_item.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_horizontal_selector.dart';
import '../../ui/tp_root_scaffold.dart';
import '../../ui/tp_scope_menu.dart';
import '../trips/trip_title_button.dart';
import '../trips/trips_list_screen.dart';
import '../trips/audit/trip_audit_screen.dart';
import '../trips/collab/collab_screen.dart';
import '../trips/edit/edit_trip_screen.dart';
import '../trips/health/trip_health_screen.dart';
import '../trips/share/share_screen.dart';
import 'day_weather.dart';
import 'reorder_helpers.dart';
import 'trip_providers.dart';
import 'trip_notes_screen.dart';
import 'trip_print_screen.dart';
import 'widgets/day_header.dart';
import 'widgets/entry_edit_sheet.dart';
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

enum _EntryEditAction { moveToDay }

/// 行程時間軸畫面：AppBar（可切換 trip + 功能選單 + 帳號）→ 單層地圖／DAY selector →
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
  var _isEditing = false;

  void _openActionSheet(Widget screen) {
    unawaited(showAppScreenSheet<void>(context, builder: (_) => screen));
  }

  void _handleTripAction(_TripMoreAction action) {
    switch (action) {
      case _TripMoreAction.editMode:
        setState(() => _isEditing = true);
      case _TripMoreAction.notes:
        _openActionSheet(TripNotesScreen(tripId: widget.tripId));
      case _TripMoreAction.editInfo:
        unawaited(
          showAppLargeScreenSheet<void>(
            context,
            builder: (_) => EditTripScreen(tripId: widget.tripId),
          ),
        );
      case _TripMoreAction.print:
        _openActionSheet(TripPrintScreen(tripId: widget.tripId));
      case _TripMoreAction.audit:
        _openActionSheet(TripAuditScreen(tripId: widget.tripId));
      case _TripMoreAction.share:
        _openActionSheet(ShareScreen(tripId: widget.tripId));
      case _TripMoreAction.collab:
        _openActionSheet(CollabScreen(tripId: widget.tripId));
      case _TripMoreAction.health:
        _openActionSheet(TripHealthScreen(tripId: widget.tripId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    final trips = switch (ref.watch(myTripsProvider)) {
      AsyncData(:final value) => value,
      _ => const <TripSummary>[],
    };
    final trip = tripAsync.value;
    final tripTitle = trip?.title ?? trip?.name ?? '行程';

    return TpRootScaffold(
      showSoftEdge: true,
      header: TpRootHeaderConfig(
        title: TripTitleButton(
          key: const ValueKey('trip-timeline-trip-picker'),
          currentTripId: widget.tripId,
          currentTitle: tripTitle,
          trips: trips,
          onSelected: (tripId) =>
              context.go('/trips/${Uri.encodeComponent(tripId)}'),
        ),
        actions: [
          if (_isEditing)
            TpToolbarTextButton(
              key: const ValueKey('tp-root-header-primary-action'),
              label: '完成',
              onPressed: () => setState(() => _isEditing = false),
            )
          else
            TpMoreMenuButton<_TripMoreAction>(
              key: const ValueKey('trip-actions-menu'),
              onSelected: _handleTripAction,
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
          const TpAccountAvatarButton(),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: TpRootGeometry.initialContentTop(context),
        ),
        child: daysAsync.when(
          data: (days) => days.isEmpty
              ? const _EmptyTimeline()
              : _TimelineBody(
                  days: days,
                  tripId: widget.tripId,
                  initialEntryId: widget.initialEntryId,
                  initialDayNum: widget.initialDayNum,
                  isEditing: _isEditing,
                ),
          loading: () => const _TimelineSkeleton(),
          error: (error, stackTrace) => _TimelineError(
            onRetry: () {
              ref.invalidate(tripDetailProvider(widget.tripId));
              ref.invalidate(tripDaysProvider(widget.tripId));
            },
          ),
        ),
      ),
    );
  }
}

typedef _EntriesSnapshot = Map<int, List<TimelineEntry>>;

/// 日程主體：固定「地圖／DAY」selector + 單一逐日 Sliver 捲動。
class _TimelineBody extends StatefulWidget {
  const _TimelineBody({
    required this.days,
    required this.tripId,
    this.initialEntryId,
    this.initialDayNum,
    required this.isEditing,
  });

  final List<TripDay> days;
  final String tripId;
  final int? initialEntryId;
  final int? initialDayNum;
  final bool isEditing;

  @override
  State<_TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<_TimelineBody> {
  static const _selectorExtent = 64.0;

  Map<int, GlobalKey> _daySectionKeys = {};
  Map<int, GlobalKey> _entryKeys = {};
  late _EntriesSnapshot _visibleEntriesByDayId;
  late int _activeDayNum;
  final _scrollController = ScrollController();
  final _selectorAnchorKey = GlobalKey();
  bool _daySyncScheduled = false;
  int? _programmaticDayNum;
  var _programmaticScrollGeneration = 0;

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
    _visibleEntriesByDayId = _entriesFromDays(widget.days);
    _activeDayNum =
        _initialDayNum() ??
        (widget.days.isEmpty ? 1 : widget.days.first.dayNum);
    _scheduleInitialFocusScroll();
  }

  @override
  void didUpdateWidget(covariant _TimelineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final daysChanged = !identical(oldWidget.days, widget.days);
    if (daysChanged) {
      _visibleEntriesByDayId = _entriesFromDays(widget.days);
    }
    if (daysChanged ||
        oldWidget.initialEntryId != widget.initialEntryId ||
        oldWidget.initialDayNum != widget.initialDayNum) {
      _rebuildKeys();
      final initialDayNum = _initialDayNum();
      if (initialDayNum != null) {
        _activeDayNum = initialDayNum;
      } else if (!widget.days.any((day) => day.dayNum == _activeDayNum)) {
        _activeDayNum = widget.days.isEmpty ? 1 : widget.days.first.dayNum;
      }
      _scheduleInitialFocusScroll();
    }
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

  _EntriesSnapshot _previewReorder(int dayId, int oldIndex, int newIndex) {
    final snapshot = _snapshotEntries();
    final entries = List<TimelineEntry>.of(
      _visibleEntriesByDayId[dayId] ?? const [],
    );
    final moved = entries.removeAt(oldIndex);
    entries.insert(newIndex, moved);
    setState(() {
      _visibleEntriesByDayId = {..._visibleEntriesByDayId, dayId: entries};
    });
    return snapshot;
  }

  _EntriesSnapshot _previewCrossDayMove({
    required TimelineEntry entry,
    required int sourceDayId,
    required int targetDayId,
    int? beforeEntryId,
  }) {
    final snapshot = _snapshotEntries();
    final source = List<TimelineEntry>.of(
      _visibleEntriesByDayId[sourceDayId] ?? const [],
    )..removeWhere((item) => item.id == entry.id);
    final target = List<TimelineEntry>.of(
      _visibleEntriesByDayId[targetDayId] ?? const [],
    );
    final index = beforeEntryId == null
        ? target.length
        : target.indexWhere((item) => item.id == beforeEntryId);
    target.insert(index < 0 ? target.length : index, entry);
    setState(() {
      _visibleEntriesByDayId = {
        ..._visibleEntriesByDayId,
        sourceDayId: source,
        targetDayId: target,
      };
    });
    return snapshot;
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
    if (next != _activeDayNum) setState(() => _activeDayNum = next);
  }

  Future<void> _scrollToDay(int dayNum) async {
    final targetContext = _daySectionKeys[dayNum]?.currentContext;
    if (targetContext == null || !_scrollController.hasClients) return;
    final object = targetContext.findRenderObject();
    if (object == null) return;
    final viewport = RenderAbstractViewport.of(object);
    final reveal = viewport.getOffsetToReveal(object, 0).offset;
    final position = _scrollController.position;
    final target = (reveal - _selectorExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final generation = ++_programmaticScrollGeneration;
    _programmaticDayNum = dayNum;
    setState(() => _activeDayNum = dayNum);
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
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _DaySelectorHeaderDelegate(
              extent: _selectorExtent,
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
                    timeline:
                        _visibleEntriesByDayId[day.id] ??
                        const <TimelineEntry>[],
                    visibleEntriesByDayId: _visibleEntriesByDayId,
                    allDays: widget.days,
                    tripId: widget.tripId,
                    entryKeys: _entryKeys,
                    focusedEntryId: widget.initialEntryId,
                    scrollController: _scrollController,
                    isEditing: widget.isEditing,
                    previewReorder: _previewReorder,
                    previewCrossDayMove: _previewCrossDayMove,
                    restoreEntries: _restoreEntries,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: TpSpacing.s8)),
        ],
      ),
    );
  }

  Widget _buildDaySelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s3,
        TpSpacing.s2,
        TpSpacing.s3,
        TpSpacing.s1,
      ),
      child: TpHorizontalSelector<int>(
        key: const ValueKey('trip-timeline-view-day-selector'),
        value: _activeDayNum,
        options: [
          const TpScopeOption(
            value: -1,
            label: '地圖',
            icon: CupertinoIcons.map,
            isAction: true,
            key: ValueKey('trip-timeline-map'),
          ),
          for (final day in widget.days)
            TpScopeOption(
              value: day.dayNum,
              label: 'DAY ${day.dayNum}',
              key: ValueKey('day-pill-${day.dayNum}'),
            ),
        ],
        onSelected: (value) {
          if (value == -1) {
            final dayNum = _activeDayNum > 0
                ? _activeDayNum
                : widget.days.firstOrNull?.dayNum;
            GoRouter.maybeOf(context)?.go(
              '/map?tripId=${Uri.encodeQueryComponent(widget.tripId)}'
              '${dayNum == null ? '' : '&day=$dayNum'}',
            );
            return;
          }
          HapticFeedback.selectionClick();
          unawaited(_scrollToDay(value));
        },
      ),
    );
  }
}

class _DaySelectorHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DaySelectorHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

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
        child,
        if (overlapsContent)
          const Positioned(
            left: 0,
            right: 0,
            bottom: -12,
            height: 12,
            child: _TimelineScrollEdge(),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DaySelectorHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}

class _TimelineScrollEdge extends StatelessWidget {
  const _TimelineScrollEdge();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: 0.12),
                  surface.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

List<({int id, int sortOrder, int? dayId})> computeCrossDayMoveUpdates({
  required int activeEntryId,
  required int targetDayId,
  required List<int> targetEntryIds,
  int? overEntryId,
}) {
  final ids = targetEntryIds.where((id) => id != activeEntryId).toList();
  final overIndex = overEntryId == null ? -1 : ids.indexOf(overEntryId);
  final insertIndex = overIndex >= 0 ? overIndex : ids.length;
  return [
    (id: activeEntryId, sortOrder: insertIndex, dayId: targetDayId),
    for (var i = insertIndex; i < ids.length; i++)
      (id: ids[i], sortOrder: i + 1, dayId: null),
  ];
}

class _EntryDragPayload {
  const _EntryDragPayload({
    required this.entry,
    required this.sourceDayId,
    required this.sourceDayNum,
  });

  final TimelineEntry entry;
  final int sourceDayId;
  final int sourceDayNum;
}

// ponytail: process-local auto recompute UI state; move to repo helper if retries need persistence.
final _requestedTravelGapRecomputes = <String>{};
final _stalledTravelRecomputeScopes = <String>{};
double? _capturedCrossDayDragScrollOffset;

/// 單日 section：day header → hotel 卡 → entries（拖曳排序 + 左滑刪除 + 點擊編輯）→ 新增鈕。
class _DaySection extends ConsumerWidget {
  const _DaySection({
    super.key,
    required this.tripId,
    required this.day,
    required this.timeline,
    required this.visibleEntriesByDayId,
    required this.allDays,
    required this.entryKeys,
    this.focusedEntryId,
    required this.scrollController,
    required this.isEditing,
    required this.previewReorder,
    required this.previewCrossDayMove,
    required this.restoreEntries,
  });

  final String tripId;
  final TripDay day;
  final List<TimelineEntry> timeline;
  final _EntriesSnapshot visibleEntriesByDayId;
  final List<TripDay> allDays;
  final Map<int, GlobalKey> entryKeys;
  final int? focusedEntryId;
  final ScrollController scrollController;
  final bool isEditing;
  final _EntriesSnapshot Function(int dayId, int oldIndex, int newIndex)
  previewReorder;
  final _EntriesSnapshot Function({
    required TimelineEntry entry,
    required int sourceDayId,
    required int targetDayId,
    int? beforeEntryId,
  })
  previewCrossDayMove;
  final void Function(_EntriesSnapshot snapshot) restoreEntries;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) {
    return confirmAndDelete(
      context,
      title: '刪除停留點',
      message: '確定要刪除「${entry.title}」嗎？',
      delete: () async {
        await ref
            .read(tripRepositoryProvider)
            .deleteEntry(tripId: tripId, entryId: entry.id);
        await _recomputeAndRefresh(ref);
      },
      onSuccess: () => ref.invalidate(tripDaysProvider(tripId)),
    );
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    int oldIndex,
    int newIndex,
  ) async {
    final updates = computeReorderUpdates(
      [for (final e in timeline) e.id],
      oldIndex,
      newIndex,
    );
    final snapshot = previewReorder(day.id, oldIndex, newIndex);
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.reorderEntries(tripId: tripId, updates: updates);
    } on Exception {
      restoreEntries(snapshot);
      if (context.mounted) {
        showAppNotice(context, '排序失敗，請稍後再試');
      }
      ref.invalidate(tripDaysProvider(tripId));
      return;
    }
    ref.invalidate(tripDaysProvider(tripId));
    await _recomputeAndRefresh(ref);
  }

  Future<void> _moveEntryToDay(
    BuildContext context,
    WidgetRef ref, {
    required TimelineEntry entry,
    required int sourceDayId,
    required int sourceDayNum,
    required TripDay target,
    int? targetEntryId,
  }) async {
    if (target.id == sourceDayId) return;
    final updates = computeCrossDayMoveUpdates(
      activeEntryId: entry.id,
      targetDayId: target.id,
      targetEntryIds: [
        for (final e
            in visibleEntriesByDayId[target.id] ?? const <TimelineEntry>[])
          e.id,
      ],
      overEntryId: targetEntryId,
    );
    final snapshot = previewCrossDayMove(
      entry: entry,
      sourceDayId: sourceDayId,
      targetDayId: target.id,
      beforeEntryId: targetEntryId,
    );
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.reorderEntries(tripId: tripId, updates: updates);
    } on Exception {
      restoreEntries(snapshot);
      if (context.mounted) {
        showAppNotice(context, '搬移失敗，請稍後再試');
      }
      ref.invalidate(tripDaysProvider(tripId));
      return;
    }
    ref.invalidate(tripDaysProvider(tripId));
    await _recomputeDay(ref, sourceDayNum);
    if (target.dayNum != sourceDayNum) {
      await _recomputeDay(ref, target.dayNum);
    }
    if (context.mounted) {
      HapticFeedback.selectionClick();
      showAppNotice(context, '已移到 DAY ${target.dayNum}');
    }
  }

  Future<void> _moveToDay(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) async {
    final targets = allDays.where((d) => d.dayNum != day.dayNum).toList();
    if (targets.isEmpty) return;
    final targetDayId = await showAppSelectionSheet<int>(
      context,
      title: '移到其他 Day',
      builder: (sheetContext, select) => ListView(
        children: [
          for (final target in targets)
            ListTile(
              key: ValueKey('move-day-${target.id}'),
              title: Text('DAY ${target.dayNum} · ${target.displayTitle}'),
              onTap: () => select(target.id),
            ),
        ],
      ),
    );
    if (targetDayId == null) return;
    if (!context.mounted) return;
    final target = allDays.firstWhere((d) => d.id == targetDayId);
    await _moveEntryToDay(
      context,
      ref,
      entry: entry,
      sourceDayId: day.id,
      sourceDayNum: day.dayNum,
      target: target,
    );
  }

  /// reorder/move 後重算交通,完成再刷新（交通重算失敗不影響排序結果）。
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

    return DragTarget<_EntryDragPayload>(
      key: ValueKey('day-drop-${day.id}'),
      onWillAcceptWithDetails: (details) =>
          isEditing && details.data.sourceDayId != day.id,
      onAcceptWithDetails: (details) {
        unawaited(
          _moveEntryToDay(
            context,
            ref,
            entry: details.data.entry,
            sourceDayId: details.data.sourceDayId,
            sourceDayNum: details.data.sourceDayNum,
            target: day,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayHeader(day: day, segments: segments),
            const SizedBox(height: TpSpacing.s3),
            DayWeatherCard(day: day),
            const SizedBox(height: TpSpacing.s3),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: timeline.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorder(context, ref, oldIndex, newIndex),
              itemBuilder: (context, i) {
                final entry = timeline[i];
                final previous = i > 0 ? timeline[i - 1] : null;
                final travel = previous?.travel;
                final travelSegment = previous == null
                    ? null
                    : _findSegment(segments, previous.id, entry.id);
                final tile = TimelineEntryTile(
                  entry: entry,
                  number: i + 1,
                  isFirst: i == 0,
                  isLast: i == timeline.length - 1,
                  isFocused: entry.id == focusedEntryId,
                  onTap: () => showEntryEditSheet(
                    context,
                    tripId: tripId,
                    args: EntryEditExisting(entry),
                  ),
                  trailing: isEditing
                      ? _EntryTrailing(
                          entryId: entry.id,
                          index: i,
                          onMove: () => _moveToDay(context, ref, entry),
                        )
                      : null,
                );
                final draggableTile = isEditing
                    ? LongPressDraggable<_EntryDragPayload>(
                        key: ValueKey('entry-cross-drag-${entry.id}'),
                        data: _EntryDragPayload(
                          entry: entry,
                          sourceDayId: day.id,
                          sourceDayNum: day.dayNum,
                        ),
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        onDragStarted: () {
                          HapticFeedback.mediumImpact();
                          _captureDragScroll();
                        },
                        onDragUpdate: (details) => _autoScrollDuringDrag(
                          context,
                          details.globalPosition,
                        ),
                        onDragEnd: (_) => _restoreDragScroll(),
                        onDraggableCanceled: (velocity, offset) =>
                            _restoreDragScroll(),
                        onDragCompleted: _restoreDragScroll,
                        feedback: Material(
                          key: ValueKey('entry-drag-feedback-${entry.id}'),
                          type: MaterialType.transparency,
                          child: Opacity(
                            opacity: 0.92,
                            child: Transform.scale(
                              scale: MediaQuery.disableAnimationsOf(context)
                                  ? 1
                                  : 0.98,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width:
                                    MediaQuery.sizeOf(context).width -
                                    (TpSpacing.s4 * 2) -
                                    kTimelineTimeColumnWidth -
                                    kTimelineRailWidth,
                                child: IgnorePointer(child: tile),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.35, child: tile),
                        child: tile,
                      )
                    : tile;
                final row = isEditing
                    ? SwipeToDelete(
                        dismissKey: ValueKey('entry-dismiss-${entry.id}'),
                        onDelete: () => _confirmDelete(context, ref, entry),
                        child: draggableTile,
                      )
                    : draggableTile;
                final dropRow = isEditing
                    ? DragTarget<_EntryDragPayload>(
                        key: ValueKey('entry-drop-${entry.id}'),
                        onWillAcceptWithDetails: (details) =>
                            details.data.sourceDayId != day.id,
                        onAcceptWithDetails: (details) {
                          unawaited(
                            _moveEntryToDay(
                              context,
                              ref,
                              entry: details.data.entry,
                              sourceDayId: details.data.sourceDayId,
                              sourceDayNum: details.data.sourceDayNum,
                              target: day,
                              targetEntryId: entry.id,
                            ),
                          );
                        },
                        builder: (context, candidateData, rejectedData) =>
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AnimatedSize(
                                  duration: TpMotion.resolve(
                                    context,
                                    TpMotion.fast,
                                  ),
                                  curve: TpMotion.appleEase,
                                  child: candidateData.isEmpty
                                      ? const SizedBox.shrink()
                                      : Container(
                                          key: ValueKey(
                                            'entry-drop-indicator-${entry.id}',
                                          ),
                                          height: 3,
                                          margin: const EdgeInsets.only(
                                            bottom: TpSpacing.s2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                ),
                                row,
                              ],
                            ),
                      )
                    : row;
                return Container(
                  key: entryKeys[entry.id],
                  child: Column(
                    key: ValueKey('entry-${entry.id}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (previous != null && (travel != null || segmentsReady))
                        _TravelRow(
                          travel: travel,
                          segment: travelSegment,
                          tripId: tripId,
                          fromEntryId: previous.id,
                          toEntryId: entry.id,
                          segmentsReady: segmentsReady,
                          missingSegment:
                              segmentsReady &&
                              travelSegment == null &&
                              travel != null,
                          recomputeStalled: _stalledTravelRecomputeScopes
                              .contains('$tripId:${day.dayNum}'),
                          missingCoords: _missingTravelCoords(previous, entry),
                        ),
                      dropRow,
                    ],
                  ),
                );
              },
            ),
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
      },
    );
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

  void _captureDragScroll() {
    if (!scrollController.hasClients) return;
    _capturedCrossDayDragScrollOffset = scrollController.offset;
  }

  void _restoreDragScroll() {
    final offset = _capturedCrossDayDragScrollOffset;
    _capturedCrossDayDragScrollOffset = null;
    if (offset == null || !scrollController.hasClients) return;
    final position = scrollController.position;
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      scrollController.jumpTo(target);
    }
  }

  void _autoScrollDuringDrag(BuildContext context, Offset globalPosition) {
    if (!scrollController.hasClients) return;
    final height = MediaQuery.sizeOf(context).height;
    const edge = 72.0;
    final distance = globalPosition.dy < edge
        ? globalPosition.dy - edge
        : globalPosition.dy > height - edge
        ? globalPosition.dy - (height - edge)
        : 0.0;
    if (distance == 0) return;
    final delta = (distance / edge * 48).clamp(-48.0, 48.0);

    final position = scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    // Drag updates arrive every frame. A new animateTo would cancel the
    // previous 48 ms animation before it advances, so use distance-scaled
    // frame steps for continuous, pointer-coupled scrolling.
    scrollController.jumpTo(target);
  }
}

/// tile 尾端：搬移到其他天 + 拖曳 handle（長按拖動排序）。
class _EntryTrailing extends StatelessWidget {
  const _EntryTrailing({
    required this.entryId,
    required this.index,
    required this.onMove,
  });

  final int entryId;
  final int index;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TpMoreMenuButton<_EntryEditAction>(
          key: ValueKey('entry-menu-$entryId'),
          tooltip: '停留點操作',
          triggerChild: Icon(
            CupertinoIcons.ellipsis,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          items: [
            TpActionItem(
              key: ValueKey('entry-move-to-day-$entryId'),
              value: _EntryEditAction.moveToDay,
              icon: CupertinoIcons.folder,
              label: '移到其他 Day',
            ),
          ],
          onSelected: (_) => onMove(),
        ),
        ReorderDragHandle(
          index: index,
          iconKey: ValueKey('entry-drag-$entryId'),
        ),
      ],
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

/// travel pill 列：沿用 tile 的時間欄 + rail 縮排，可編輯或補建交通 segment。
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: kTimelineTimeColumnWidth),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(
              horizontal: (kTimelineRailWidth - 1) / 2,
            ),
            color: railLineColor,
          ),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: TpSpacing.s3),
              child: Align(alignment: Alignment.centerLeft, child: pill),
            ),
          ),
        ],
      ),
    );
  }
}

/// loading skeleton：非動畫灰階條列。
class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
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

    return Center(
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
