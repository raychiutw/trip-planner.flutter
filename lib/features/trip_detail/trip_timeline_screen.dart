import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/segment.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'day_warnings.dart';
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

enum _TripMoreAction { share, collab, health }

/// 行程時間軸畫面：AppBar（trip 名 + 地圖/筆記 actions）→ 頂部 day pills →
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
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/edit-trip/$tripId'),
          ),
          IconButton(
            tooltip: '地圖',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/map'),
          ),
          IconButton(
            tooltip: '筆記',
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/notes'),
          ),
          IconButton(
            tooltip: '列印',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/print'),
          ),
          IconButton(
            tooltip: '異動紀錄',
            icon: const Icon(Icons.history_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/audit'),
          ),
          PopupMenuButton<_TripMoreAction>(
            key: const ValueKey('trip-actions-menu'),
            tooltip: '更多',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
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
  Map<int, GlobalKey> _daySectionKeys = {};
  Map<int, GlobalKey> _entryKeys = {};
  late int _activeDayNum;

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
    _activeDayNum =
        _initialDayNum() ??
        (widget.days.isEmpty ? 1 : widget.days.first.dayNum);
    _scheduleInitialFocusScroll();
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
        duration: TpMotion.normal,
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
        duration: TpMotion.normal,
        curve: TpMotion.appleEase,
      );
    }
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

/// 單日 section：day header → hotel 卡 → entries（拖曳排序 + 左滑刪除 + 點擊編輯）→ 新增鈕。
class _DaySection extends ConsumerWidget {
  const _DaySection({
    super.key,
    required this.tripId,
    required this.day,
    required this.allDays,
    required this.entryKeys,
    this.focusedEntryId,
  });

  final String tripId;
  final TripDay day;
  final List<TripDay> allDays;
  final Map<int, GlobalKey> entryKeys;
  final int? focusedEntryId;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('排序失敗，請稍後再試')));
      }
      ref.invalidate(tripDaysProvider(tripId));
      return;
    }
    ref.invalidate(tripDaysProvider(tripId));
    await _recomputeAndRefresh(ref);
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
    final target = allDays.firstWhere((d) => d.id == targetDayId);
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.reorderEntries(
        tripId: tripId,
        updates: [
          (id: entry.id, sortOrder: target.timeline.length, dayId: targetDayId),
        ],
      );
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('搬移失敗，請稍後再試')));
      }
      ref.invalidate(tripDaysProvider(tripId));
      return;
    }
    ref.invalidate(tripDaysProvider(tripId));
    await _recomputeAndRefresh(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已移到 DAY ${target.dayNum}')));
    }
  }

  /// reorder/move 後重算交通,完成再刷新（交通重算失敗不影響排序結果）。
  Future<void> _recomputeAndRefresh(WidgetRef ref) async {
    try {
      await ref.read(tripRepositoryProvider).recomputeTravel(tripId: tripId);
      ref.invalidate(tripDaysProvider(tripId));
    } on Exception {
      // 交通重算失敗忽略
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = day.timeline;
    final warnings = validateDay(timeline);
    final segmentsValue = ref.watch(tripSegmentsProvider(tripId));
    final segmentsReady = segmentsValue is AsyncData<List<TripSegment>>;
    final segments = switch (segmentsValue) {
      AsyncData(:final value) => value,
      _ => const <TripSegment>[],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayHeader(day: day),
        const SizedBox(height: TpSpacing.s3),
        if (warnings.isNotEmpty) ...[
          _DayWarningsCard(warnings: warnings),
          const SizedBox(height: TpSpacing.s3),
        ],
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
            return KeyedSubtree(
              key: ValueKey('entry-${entry.id}'),
              child: Container(
                key: entryKeys[entry.id],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (previous != null &&
                        (previous.travel != null || segmentsReady))
                      _TravelRow(
                        travel: previous.travel,
                        segment: _findSegment(segments, previous.id, entry.id),
                        segmentsReady: segmentsReady,
                        tripId: tripId,
                        fromEntryId: previous.id,
                        toEntryId: entry.id,
                      ),
                    SwipeToDelete(
                      dismissKey: ValueKey('entry-dismiss-${entry.id}'),
                      onDelete: () => _confirmDelete(context, ref, entry),
                      child: TimelineEntryTile(
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
                      ),
                    ),
                  ],
                ),
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
              args: EntryEditNew(day.dayNum),
            ),
            icon: const Icon(Icons.add),
            label: const Text('新增停留點'),
          ),
        ),
        const SizedBox(height: TpSpacing.s6),
      ],
    );
  }
}

/// 注意事項卡：早於營業時間等提醒,以 warning tone 呈現（淡底 + 警示圖示）。
class _DayWarningsCard extends StatelessWidget {
  const _DayWarningsCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warningColor = theme.extension<TpTones>()!.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: warningColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: warningColor),
              const SizedBox(width: TpSpacing.s2),
              Text(
                '注意事項',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(top: TpSpacing.s1),
              child: Text(
                warning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
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
          icon: const Icon(Icons.drive_file_move_outline),
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

/// travel pill 列：沿用 tile 的時間欄 + rail 縮排，可編輯或補建交通 segment。
class _TravelRow extends StatelessWidget {
  const _TravelRow({
    required this.travel,
    required this.fromEntryId,
    required this.toEntryId,
    required this.segmentsReady,
    this.segment,
    this.tripId,
  });

  final Travel? travel;
  final int fromEntryId;
  final int toEntryId;
  final bool segmentsReady;
  final TripSegment? segment;
  final String? tripId;

  @override
  Widget build(BuildContext context) {
    final railLineColor = Theme.of(context).colorScheme.outlineVariant;
    final seg = segment;
    Widget pill = TravelPill(
      travel: travel,
      segment: seg,
      missing: seg == null && travel == null,
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
            Icons.error_outline,
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
