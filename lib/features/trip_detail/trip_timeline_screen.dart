import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/segment.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';
import 'widgets/day_header.dart';
import 'widgets/day_pills.dart';
import 'widgets/entry_edit_sheet.dart';
import 'widgets/hotel_card.dart';
import 'widgets/reorderable_row.dart';
import 'widgets/timeline_entry_tile.dart';
import 'widgets/travel_edit_sheet.dart';
import 'widgets/travel_pill.dart';

/// 行程時間軸畫面：AppBar（trip 名 + 地圖/筆記 actions）→ 頂部 day pills →
/// 逐日 section（day header → hotel 卡 → timeline rail + travel pill）。
class TripTimelineScreen extends ConsumerWidget {
  const TripTimelineScreen({super.key, required this.tripId});

  final String tripId;

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
          IconButton(
            tooltip: '地圖',
            icon: const Icon(CupertinoIcons.map),
            onPressed: () => _goTo(context, '/trips/$tripId/map'),
          ),
          IconButton(
            tooltip: '筆記',
            icon: const Icon(CupertinoIcons.doc_text),
            onPressed: () => _goTo(context, '/trips/$tripId/notes'),
          ),
          IconButton(
            tooltip: '列印',
            icon: const Icon(CupertinoIcons.printer),
            onPressed: () => _goTo(context, '/trips/$tripId/print'),
          ),
        ],
      ),
      body: daysAsync.when(
        data: (days) => days.isEmpty
            ? const _EmptyTimeline()
            : _TimelineBody(days: days, tripId: tripId),
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

/// 日程主體：day pills + 可捲動逐日 sections；pill 點擊 ensureVisible 捲至該日。
class _TimelineBody extends StatefulWidget {
  const _TimelineBody({required this.days, required this.tripId});

  final List<TripDay> days;
  final String tripId;

  @override
  State<_TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<_TimelineBody> {
  late Map<int, GlobalKey> _daySectionKeys;
  late int _activeDayNum;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _rebuildDaySectionKeys();
    _activeDayNum = widget.days.isEmpty ? 1 : widget.days.first.dayNum;
  }

  @override
  void didUpdateWidget(covariant _TimelineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.days, widget.days)) {
      _rebuildDaySectionKeys();
    }
  }

  void _rebuildDaySectionKeys() {
    _daySectionKeys = {for (final day in widget.days) day.dayNum: GlobalKey()};
  }

  void _scrollToDay(int dayNum) {
    setState(() => _activeDayNum = dayNum);
    final sectionContext = _daySectionKeys[dayNum]?.currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        duration: TpMotion.normal,
        curve: TpMotion.appleEase,
      );
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

/// 統一拖放排序(同日重排 + 跨日移動共用一套):把 [activeEntryId] 放進 [targetDayId]
/// 的 [targetEntryIds] 中 [overEntryId] 的位置(drop 在某 entry 上 → 插其前;
/// [overEntryId]==null → 放到最後)。target day 全員重編連續 sortOrder。
///
/// - 同日([sameDay]=true):active 已在 targetEntryIds 中,先移除再插入;dayId 全 null。
/// - 跨日([sameDay]=false):active 帶 [targetDayId](換天),其餘 dayId null。
///
/// 對應 web:單一拖曳依 drop 目標決定「原地重排」或「移到別天」,不需分兩套手勢。
List<({int id, int sortOrder, int? dayId})> computeDropReorderUpdates({
  required int activeEntryId,
  required int targetDayId,
  required List<int> targetEntryIds,
  required bool sameDay,
  int? overEntryId,
}) {
  final ids = targetEntryIds.where((id) => id != activeEntryId).toList();
  final overIndex = overEntryId == null ? -1 : ids.indexOf(overEntryId);
  final insertIndex = overIndex >= 0 ? overIndex : ids.length;
  ids.insert(insertIndex, activeEntryId);
  return [
    for (var i = 0; i < ids.length; i++)
      (
        id: ids[i],
        sortOrder: i,
        dayId: (!sameDay && ids[i] == activeEntryId) ? targetDayId : null,
      ),
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
    required this.scrollController,
  });

  final String tripId;
  final TripDay day;
  final List<TripDay> allDays;
  final ScrollController scrollController;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) {
    // 在 mounted 時先讀 repo：confirmAndDelete 會先 await 確認框，才呼叫 delete()，
    // 期間背景刷新 days 可能 remount _DaySection、使此 ref 失效（見 _reorder/_moveEntryToDay 同法）。
    final repo = ref.read(tripRepositoryProvider);
    return confirmAndDelete(
      context,
      title: '刪除停留點',
      message: '確定要刪除「${entry.title}」嗎？',
      delete: () async {
        await repo.deleteEntry(tripId: tripId, entryId: entry.id);
        await _recomputeAndRefresh(ref);
      },
      onSuccess: () {
        if (ref.context.mounted) ref.invalidate(tripDaysProvider(tripId));
      },
    );
  }

  /// 統一拖放處理:同日 = 原地重排、跨日 = 移到 [targetDay]。[overEntryId] 為 drop
  /// 目標 entry(插其前),null = 放到該天末尾。以 [computeDropReorderUpdates] 算
  /// batch updates;失敗提示並重抓,成功後重算相關日交通。單一手勢依 drop 目標分流,
  /// 取代原本「重排 handle」與「跨日長按拖曳」兩套會互搶的手勢。
  Future<void> _handleDrop(
    BuildContext context,
    WidgetRef ref, {
    required _EntryDragPayload payload,
    required TripDay targetDay,
    int? overEntryId,
  }) async {
    final sameDay = payload.sourceDayId == targetDay.id;
    final currentIds = [for (final e in targetDay.timeline) e.id];
    final updates = computeDropReorderUpdates(
      activeEntryId: payload.entry.id,
      targetDayId: targetDay.id,
      targetEntryIds: currentIds,
      sameDay: sameDay,
      overEntryId: overEntryId,
    );
    // 同日且順序沒變 → 不打 API(避免無謂重排/重算)。
    if (sameDay && listEquals([for (final u in updates) u.id], currentIds)) {
      return;
    }
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.reorderEntries(tripId: tripId, updates: updates);
    } on Exception {
      if (context.mounted) {
        showAppNotice(context, sameDay ? '排序失敗，請稍後再試' : '搬移失敗，請稍後再試');
      }
      if (ref.context.mounted) ref.invalidate(tripDaysProvider(tripId));
      return;
    }
    if (ref.context.mounted) ref.invalidate(tripDaysProvider(tripId));
    await _recomputeDay(ref, payload.sourceDayNum);
    if (!sameDay && targetDay.dayNum != payload.sourceDayNum) {
      await _recomputeDay(ref, targetDay.dayNum);
    }
    if (!sameDay && context.mounted) {
      showAppNotice(context, '已移到 DAY ${targetDay.dayNum}');
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
    await _handleDrop(
      context,
      ref,
      payload: _EntryDragPayload(
        entry: entry,
        sourceDayId: day.id,
        sourceDayNum: day.dayNum,
      ),
      targetDay: target,
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
    // 前一個 await（delete/reorder/move）期間若已離開頁面，連進入時的 ref.read 都會擲錯。
    if (!ref.context.mounted) return;
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId: tripId, day: '$dayNum');
      _stalledTravelRecomputeScopes.remove(scope);
      // await 後 widget 可能已 unmount（如使用者離開頁面），此時碰 ref 會擲 StateError。
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
      // 同日 + 跨日皆接受;drop 在此天空白處(非某 entry 上)→ 放到該天末尾。
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        unawaited(
          _handleDrop(context, ref, payload: details.data, targetDay: day),
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
              if (day.hotel != null) ...[
                HotelCard(hotel: day.hotel!),
                const SizedBox(height: TpSpacing.s3),
              ],
              for (final (i, entry) in timeline.indexed)
                _buildEntryRow(
                  context,
                  ref,
                  index: i,
                  entry: entry,
                  timeline: timeline,
                  segments: segments,
                  segmentsReady: segmentsReady,
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

  /// 單一 entry row:travel row(選配)＋ 拖放目標(`entry-drop`)包住整張卡。
  /// 唯一拖曳手勢:長按整張卡 → 抬起、**限垂直**移動([Axis.vertical]);drop 到
  /// 某卡 → 插其前(同日重排 / 跨日移入,由 [_handleDrop] 依來源天分流)。
  /// 對齊 Apple 拖放:整張卡浮起(陰影)、原位留 ghost,無左右位移。
  Widget _buildEntryRow(
    BuildContext context,
    WidgetRef ref, {
    required int index,
    required TimelineEntry entry,
    required List<TimelineEntry> timeline,
    required List<TripSegment> segments,
    required bool segmentsReady,
  }) {
    final i = index;
    final travelSegment = i > 0 && entry.travel != null
        ? _findSegment(segments, timeline[i - 1].id, entry.id)
        : null;
    final payload = _EntryDragPayload(
      entry: entry,
      sourceDayId: day.id,
      sourceDayNum: day.dayNum,
    );

    // 整張卡建構;lifted=拖曳中的浮起版(隱藏 rail 連線,較乾淨)。
    Widget buildTile({bool lifted = false}) => TimelineEntryTile(
      entry: entry,
      number: i + 1,
      isFirst: lifted || i == 0,
      isLast: lifted || i == timeline.length - 1,
      onTap: () => showEntryEditSheet(
        context,
        tripId: tripId,
        args: EntryEditExisting(entry),
      ),
      trailing: _EntryTrailing(
        entryId: entry.id,
        onMove: () => _moveToDay(context, ref, entry),
      ),
    );

    final dropRow = DragTarget<_EntryDragPayload>(
      key: ValueKey('entry-drop-${entry.id}'),
      // 不接受 drop 到自己身上(no-op);其餘同日=重排、他日=移入。
      onWillAcceptWithDetails: (details) => details.data.entry.id != entry.id,
      onAcceptWithDetails: (details) {
        unawaited(
          _handleDrop(
            context,
            ref,
            payload: details.data,
            targetDay: day,
            overEntryId: entry.id,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final highlight = candidateData.isNotEmpty;
        // 整張卡即拖曳來源:長按抬起、限垂直。SwipeToDelete 在外層處理左滑刪除。
        return LayoutBuilder(
          builder: (context, constraints) {
            final draggable = LongPressDraggable<_EntryDragPayload>(
              key: ValueKey('entry-cross-drag-${entry.id}'),
              data: payload,
              axis: Axis.vertical,
              onDragStarted: _captureDragScroll,
              onDragUpdate: (details) =>
                  _autoScrollDuringDrag(context, details.globalPosition),
              onDragEnd: (_) => _restoreDragScroll(),
              onDraggableCanceled: (velocity, offset) => _restoreDragScroll(),
              onDragCompleted: _restoreDragScroll,
              feedback: _EntryDragFeedback(
                width: constraints.maxWidth,
                child: buildTile(lifted: true),
              ),
              // 原位留半透明 ghost,傳達「已抬起搬移中」。
              childWhenDragging: Opacity(opacity: 0.25, child: buildTile()),
              child: buildTile(),
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                border: highlight
                    ? Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                    : null,
              ),
              child: SwipeToDelete(
                dismissKey: ValueKey('entry-dismiss-${entry.id}'),
                onDelete: () => _confirmDelete(context, ref, entry),
                child: draggable,
              ),
            );
          },
        );
      },
    );
    return Column(
      key: ValueKey('entry-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (i > 0 && entry.travel != null)
          _TravelRow(
            travel: entry.travel!,
            segment: travelSegment,
            tripId: tripId,
            missingSegment: segmentsReady && travelSegment == null,
            recomputeStalled: _stalledTravelRecomputeScopes.contains(
              '$tripId:${day.dayNum}',
            ),
            missingCoords: _missingTravelCoords(timeline[i - 1], entry),
          ),
        dropRow,
      ],
    );
  }

  void _requestMissingSegmentRecompute(
    WidgetRef ref,
    List<TimelineEntry> timeline,
    List<TripSegment> segments,
  ) {
    final gapIds = <String>[];
    for (var i = 1; i < timeline.length; i++) {
      final entry = timeline[i];
      if (entry.travel == null) continue;
      final previous = timeline[i - 1];
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
/// 拖曳中的抬起卡片:整張卡浮起(Material 陰影 + 圓角),寬度對齊來源列,
/// 對齊 Apple 拖放的「拿起」質感。
class _EntryDragFeedback extends StatelessWidget {
  const _EntryDragFeedback({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(TpRadius.md),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(width: width, child: child),
    );
  }
}

class _EntryTrailing extends StatelessWidget {
  const _EntryTrailing({required this.entryId, required this.onMove});

  final int entryId;
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
          onPressed: onMove,
        ),
        // 拖曳排序視覺提示（≡）;整張卡長按即可拖曳,此 handle 僅為 affordance。
        Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            CupertinoIcons.line_horizontal_3,
            key: ValueKey('entry-drag-$entryId'),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 依相鄰兩端 entry id 比對 travel pill 對應的 segment（找不到回 null,pill 不可點）。
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

/// travel pill 列：沿用 tile 的時間欄 + rail 縮排。有對應 segment 時可點擊編輯交通。
class _TravelRow extends StatelessWidget {
  const _TravelRow({
    required this.travel,
    this.segment,
    this.tripId,
    this.missingSegment = false,
    this.recomputeStalled = false,
    this.missingCoords = false,
  });

  final Travel travel;
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
      statusLabel: needsStatus
          ? (missingCoords
                ? '缺座標，無法計算車程'
                : recomputeStalled
                ? '車程待更新'
                : '車程重新計算中')
          : null,
    );
    if (seg != null && tripId != null) {
      pill = InkWell(
        key: ValueKey('travel-edit-${seg.id}'),
        onTap: () =>
            showTravelEditSheet(context, tripId: tripId!, segment: seg),
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
