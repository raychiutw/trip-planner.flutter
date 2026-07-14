import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_feedback.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/segment.dart';
import '../../theme/tokens.dart';
import 'day_weather.dart';
import 'reorder_helpers.dart';
import 'trip_providers.dart';
import 'widgets/day_header.dart';
import 'widgets/day_pills.dart';
import 'widgets/entry_edit_sheet.dart';
import 'widgets/hotel_card.dart';
import 'widgets/reorderable_row.dart';
import 'widgets/timeline_entry_tile.dart';
import 'widgets/travel_edit_sheet.dart';
import 'widgets/travel_pill.dart';

enum _TripMoreAction { map, notes, print, audit, share, collab, health }

/// 行程時間軸畫面：AppBar（trip 名 + 編輯/更多）→ 頂部 day pills →
/// 逐日 section（day header → hotel 卡 → timeline rail + travel pill）。
class TripTimelineScreen extends ConsumerWidget {
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

  void _goTo(BuildContext context, String location) {
    // 測試環境可能未掛 GoRouter，maybeOf 避免 crash
    GoRouter.maybeOf(context)?.go(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    final trip = tripAsync.value;
    final tripTitle = trip?.title ?? trip?.name ?? '行程';

    return Scaffold(
      appBar: AppBar(
        title: Text(tripTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '編輯行程',
            icon: const Icon(CupertinoIcons.pencil),
            onPressed: () => context.push('/edit-trip/$tripId'),
          ),
          PopupMenuButton<_TripMoreAction>(
            key: const ValueKey('trip-actions-menu'),
            tooltip: '更多',
            icon: const Icon(CupertinoIcons.ellipsis),
            onSelected: (action) {
              switch (action) {
                case _TripMoreAction.map:
                  _goTo(context, '/trips/$tripId/map');
                case _TripMoreAction.notes:
                  _goTo(context, '/trips/$tripId/notes');
                case _TripMoreAction.print:
                  _goTo(context, '/trips/$tripId/print');
                case _TripMoreAction.audit:
                  _goTo(context, '/trips/$tripId/audit');
                case _TripMoreAction.share:
                  _goTo(context, '/share-trip/$tripId');
                case _TripMoreAction.collab:
                  _goTo(context, '/collab/$tripId');
                case _TripMoreAction.health:
                  _goTo(context, '/trips/$tripId/health');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                key: ValueKey('trip-action-map'),
                value: _TripMoreAction.map,
                child: _TripActionMenuItem(
                  icon: Icons.map_outlined,
                  label: '地圖',
                ),
              ),
              PopupMenuItem(
                key: ValueKey('trip-action-notes'),
                value: _TripMoreAction.notes,
                child: _TripActionMenuItem(
                  icon: Icons.sticky_note_2_outlined,
                  label: '筆記',
                ),
              ),
              PopupMenuItem(
                key: ValueKey('trip-action-print'),
                value: _TripMoreAction.print,
                child: _TripActionMenuItem(
                  icon: Icons.print_outlined,
                  label: '列印',
                ),
              ),
              PopupMenuItem(
                key: ValueKey('trip-action-audit'),
                value: _TripMoreAction.audit,
                child: _TripActionMenuItem(
                  icon: Icons.history_outlined,
                  label: '異動紀錄',
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                key: ValueKey('trip-action-share'),
                value: _TripMoreAction.share,
                child: _TripActionMenuItem(
                  icon: Icons.ios_share_outlined,
                  label: '分享連結',
                ),
              ),
              PopupMenuItem(
                key: ValueKey('trip-action-collab'),
                value: _TripMoreAction.collab,
                child: _TripActionMenuItem(
                  icon: Icons.group_outlined,
                  label: '共編設定',
                ),
              ),
              PopupMenuItem(
                key: ValueKey('trip-action-health'),
                value: _TripMoreAction.health,
                child: _TripActionMenuItem(
                  icon: Icons.health_and_safety_outlined,
                  label: 'AI 健檢',
                ),
              ),
            ],
          ),
        ],
      ),
      body: daysAsync.when(
        data: (days) => days.isEmpty
            ? const _EmptyTimeline()
            : _TimelineBody(
                days: days,
                tripId: tripId,
                initialEntryId: initialEntryId,
                initialDayNum: initialDayNum,
              ),
        loading: () => const _TimelineSkeleton(),
        error: (error, stackTrace) => _TimelineError(
          onRetry: () {
            ref.invalidate(tripDetailProvider(tripId));
            ref.invalidate(tripDaysProvider(tripId));
          },
        ),
      ),
    );
  }
}

class _TripActionMenuItem extends StatelessWidget {
  const _TripActionMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: TpSpacing.s3),
        Text(label),
      ],
    );
  }
}

/// 日程主體：day pills + 可捲動逐日 sections；pill 點擊 ensureVisible 捲至該日。
class _TimelineBody extends StatefulWidget {
  const _TimelineBody({
    required this.days,
    required this.tripId,
    this.initialEntryId,
    this.initialDayNum,
  });

  final List<TripDay> days;
  final String tripId;
  final int? initialEntryId;
  final int? initialDayNum;

  @override
  State<_TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<_TimelineBody> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewportKey = GlobalKey(debugLabel: 'timeline-scroll');
  Map<int, GlobalKey> _daySectionKeys = {};
  Map<int, GlobalKey> _entryKeys = {};
  late int _activeDayNum;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateActiveDayFromScroll);
    _rebuildKeys();
    _activeDayNum =
        _initialDayNum() ??
        (widget.days.isEmpty ? 1 : widget.days.first.dayNum);
    _scheduleInitialFocusScroll();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateActiveDayFromScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TimelineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.days, widget.days) ||
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
    final oldEntryKeys = _entryKeys;
    _daySectionKeys = {for (final day in widget.days) day.dayNum: GlobalKey()};
    _entryKeys = {
      for (final day in widget.days)
        for (final entry in day.timeline)
          entry.id: oldEntryKeys[entry.id] ?? GlobalKey(),
    };
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
        duration: TpMotion.resolve(targetContext, TpMotion.normal),
        curve: TpMotion.appleEase,
      );
    });
  }

  void _scrollToDay(int dayNum) {
    setState(() => _activeDayNum = dayNum);
    final sectionContext = _daySectionKeys[dayNum]?.currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        duration: TpMotion.resolve(sectionContext, TpMotion.normal),
        curve: TpMotion.appleEase,
      );
    }
  }

  void _updateActiveDayFromScroll() {
    if (!_scrollController.hasClients || widget.days.isEmpty) return;

    final position = _scrollController.position;
    var visibleDayNum = widget.days.first.dayNum;
    if (position.extentAfter <= 1) {
      visibleDayNum = widget.days.last.dayNum;
    } else {
      final viewportBox =
          _scrollViewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (viewportBox == null || !viewportBox.hasSize) return;
      final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
      for (final day in widget.days) {
        final sectionBox =
            _daySectionKeys[day.dayNum]?.currentContext?.findRenderObject()
                as RenderBox?;
        if (sectionBox == null || !sectionBox.hasSize) continue;
        final sectionTop = sectionBox.localToGlobal(Offset.zero).dy;
        if (sectionTop <= viewportTop + TpSpacing.s2) {
          visibleDayNum = day.dayNum;
        } else {
          break;
        }
      }
    }

    if (visibleDayNum != _activeDayNum && mounted) {
      setState(() => _activeDayNum = visibleDayNum);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DayPills(
          days: widget.days,
          activeDayNum: _activeDayNum,
          onDaySelected: _scrollToDay,
        ),
        Expanded(
          child: SingleChildScrollView(
            key: _scrollViewportKey,
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              TpSpacing.s4,
              TpSpacing.s4,
              TpSpacing.s4,
              TpSpacing.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in widget.days)
                  _DaySection(
                    key: _daySectionKeys[day.dayNum],
                    day: day,
                    allDays: widget.days,
                    tripId: widget.tripId,
                    entryKeys: _entryKeys,
                    focusedEntryId: widget.initialEntryId,
                    scrollController: _scrollController,
                  ),
              ],
            ),
          ),
        ),
      ],
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
    required this.allDays,
    required this.entryKeys,
    this.focusedEntryId,
    required this.scrollController,
  });

  final String tripId;
  final TripDay day;
  final List<TripDay> allDays;
  final Map<int, GlobalKey> entryKeys;
  final int? focusedEntryId;
  final ScrollController scrollController;

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
      [for (final e in day.timeline) e.id],
      oldIndex,
      newIndex,
    );
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.reorderEntries(tripId: tripId, updates: updates);
    } on Exception {
      if (context.mounted) {
        showAppError(context, '排序失敗，請稍後再試');
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
      targetEntryIds: [for (final e in target.timeline) e.id],
      overEntryId: targetEntryId,
    );
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.reorderEntries(tripId: tripId, updates: updates);
    } on Exception {
      if (context.mounted) {
        showAppError(context, '搬移失敗，請稍後再試');
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
    final targetDayId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('移到其他天')),
            for (final d in targets)
              ListTile(
                key: ValueKey('move-day-${d.id}'),
                title: Text('DAY ${d.dayNum} · ${d.displayTitle}'),
                onTap: () => Navigator.of(sheetContext).pop(d.id),
              ),
          ],
        ),
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
    final scope = '$tripId:$dayNum';
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId: tripId, day: '$dayNum');
      _stalledTravelRecomputeScopes.remove(scope);
      ref.invalidate(tripDaysProvider(tripId));
      ref.invalidate(tripSegmentsProvider(tripId));
    } on Exception {
      if (auto) {
        _stalledTravelRecomputeScopes.add(scope);
        ref.invalidate(tripSegmentsProvider(tripId));
      }
      // 交通重算失敗忽略
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = day.timeline;
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
      onWillAcceptWithDetails: (details) => details.data.sourceDayId != day.id,
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
        final highlight = candidateData.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: highlight
                ? Border.all(color: Theme.of(context).colorScheme.primary)
                : null,
            borderRadius: BorderRadius.circular(TpRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DayHeader(day: day, segments: segments),
              const SizedBox(height: TpSpacing.s3),
              if (hasWeatherDay(day)) ...[
                DayWeatherCard(day: day),
                const SizedBox(height: TpSpacing.s3),
              ],
              if (day.hotel != null) ...[
                HotelCard(hotel: day.hotel!),
                const SizedBox(height: TpSpacing.s3),
              ],
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: timeline.length,
                onReorder: (oldIndex, newIndex) =>
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
                    trailing: _EntryTrailing(
                      entryId: entry.id,
                      index: i,
                      onMove: () => _moveToDay(context, ref, entry),
                    ),
                  );
                  final draggableTile = LongPressDraggable<_EntryDragPayload>(
                    key: ValueKey('entry-cross-drag-${entry.id}'),
                    data: _EntryDragPayload(
                      entry: entry,
                      sourceDayId: day.id,
                      sourceDayNum: day.dayNum,
                    ),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    onDragStarted: _captureDragScroll,
                    onDragUpdate: (details) =>
                        _autoScrollDuringDrag(context, details.globalPosition),
                    onDragEnd: (_) => _restoreDragScroll(),
                    onDraggableCanceled: (velocity, offset) =>
                        _restoreDragScroll(),
                    onDragCompleted: _restoreDragScroll,
                    feedback: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(TpRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.all(TpSpacing.s3),
                        child: Text(entry.title),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.35, child: tile),
                    child: tile,
                  );
                  final row = SwipeToDelete(
                    dismissKey: ValueKey('entry-dismiss-${entry.id}'),
                    onDelete: () => _confirmDelete(context, ref, entry),
                    child: draggableTile,
                  );
                  final dropRow = DragTarget<_EntryDragPayload>(
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
                    builder: (context, candidateData, rejectedData) => row,
                  );
                  return Container(
                    key: entryKeys[entry.id],
                    child: Column(
                      key: ValueKey('entry-${entry.id}'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (previous != null &&
                            (travel != null || segmentsReady))
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
                            missingCoords: _missingTravelCoords(
                              previous,
                              entry,
                            ),
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
                  onPressed: () => showEntryEditSheet(
                    context,
                    tripId: tripId,
                    args: EntryEditNew(day.dayNum, days: allDays),
                  ),
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('新增停留點'),
                ),
              ),
              const SizedBox(height: TpSpacing.s6),
            ],
          ),
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
    const step = 32.0;
    final delta = globalPosition.dy < edge
        ? -step
        : globalPosition.dy > height - edge
        ? step
        : 0.0;
    if (delta == 0) return;

    final position = scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      scrollController.jumpTo(target);
    }
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
        IconButton(
          key: ValueKey('entry-menu-$entryId'),
          icon: const Icon(CupertinoIcons.folder),
          tooltip: '移到其他天',
          visualDensity: VisualDensity.compact,
          onPressed: onMove,
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
