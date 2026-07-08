import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/day.dart';
import '../../models/entry.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';
import 'widgets/day_header.dart';
import 'widgets/day_pills.dart';
import 'widgets/hotel_card.dart';
import 'widgets/timeline_entry_tile.dart';
import 'widgets/travel_pill.dart';

/// 行程時間軸畫面：AppBar（trip 名 + 地圖/筆記 actions）→ 頂部 day pills →
/// 逐日 section（day header → hotel 卡 → timeline rail + travel pill）。
class TripTimelineScreen extends ConsumerWidget {
  const TripTimelineScreen({
    super.key,
    required this.tripId,
    this.focusEntryId,
  });

  final String tripId;

  /// Optional entry id to scroll into view after timeline data loads.
  final int? focusEntryId;

  void _goTo(BuildContext context, String location) {
    // 測試環境可能未掛 GoRouter，maybeOf 避免 crash
    GoRouter.maybeOf(context)?.go(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    final segmentsAsync = ref.watch(tripSegmentsProvider(tripId));
    final trip = tripAsync.value;
    final tripTitle = trip?.title ?? trip?.name ?? '行程';

    return Scaffold(
      appBar: AppBar(
        title: Text(tripTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '新增景點',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/add-entry'),
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
            tooltip: 'AI 健檢',
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/health'),
          ),
          IconButton(
            tooltip: '共編',
            icon: const Icon(Icons.group_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/collab'),
          ),
        ],
      ),
      body: daysAsync.when(
        data: (days) => days.isEmpty
            ? const _EmptyTimeline()
            : _TimelineBody(
                tripId: tripId,
                focusEntryId: focusEntryId,
                days: days,
                segments: segmentsAsync.value ?? const <TripSegment>[],
                showSegmentError: segmentsAsync.hasError,
                onSegmentsRetry: () =>
                    ref.invalidate(tripSegmentsProvider(tripId)),
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

/// 日程主體：day pills + 可捲動逐日 sections；pill 點擊 ensureVisible 捲至該日。
class _TimelineBody extends StatefulWidget {
  const _TimelineBody({
    required this.tripId,
    required this.focusEntryId,
    required this.days,
    required this.segments,
    required this.showSegmentError,
    required this.onSegmentsRetry,
  });

  final String tripId;
  final int? focusEntryId;
  final List<TripDay> days;
  final List<TripSegment> segments;
  final bool showSegmentError;
  final VoidCallback onSegmentsRetry;

  @override
  State<_TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<_TimelineBody> {
  final _scrollViewKey = GlobalKey();
  late final ScrollController _scrollController;
  late Map<int, GlobalKey> _daySectionKeys;
  late Map<int, GlobalKey> _entryKeys;
  late int _activeDayNum;
  bool _didApplyInitialFocus = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(_syncActiveDayFromScroll);
    _rebuildScrollKeys();
    _activeDayNum =
        _dayNumForEntry(widget.focusEntryId) ??
        (widget.days.isEmpty ? 1 : widget.days.first.dayNum);
    _scheduleInitialFocus();
  }

  @override
  void didUpdateWidget(covariant _TimelineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.days, widget.days)) {
      _rebuildScrollKeys();
    }
    if (oldWidget.focusEntryId != widget.focusEntryId ||
        !identical(oldWidget.days, widget.days)) {
      _didApplyInitialFocus = false;
      final focusedDayNum = _dayNumForEntry(widget.focusEntryId);
      if (focusedDayNum != null && focusedDayNum != _activeDayNum) {
        _activeDayNum = focusedDayNum;
      }
      _scheduleInitialFocus();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncActiveDayFromScroll)
      ..dispose();
    super.dispose();
  }

  void _rebuildScrollKeys() {
    _daySectionKeys = {for (final day in widget.days) day.dayNum: GlobalKey()};
    _entryKeys = {
      for (final day in widget.days)
        for (final entry in day.timeline) entry.id: GlobalKey(),
    };
  }

  int? _dayNumForEntry(int? entryId) {
    if (entryId == null) return null;
    for (final day in widget.days) {
      if (day.timeline.any((entry) => entry.id == entryId)) {
        return day.dayNum;
      }
    }
    return null;
  }

  void _scheduleInitialFocus() {
    if (widget.focusEntryId == null || _didApplyInitialFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialFocus());
  }

  void _applyInitialFocus() {
    if (!mounted || _didApplyInitialFocus) return;
    final focusEntryId = widget.focusEntryId;
    if (focusEntryId == null) return;

    final entryContext = _entryKeys[focusEntryId]?.currentContext;
    if (entryContext == null) return;

    _didApplyInitialFocus = true;
    final focusedDayNum = _dayNumForEntry(focusEntryId);
    if (focusedDayNum != null && focusedDayNum != _activeDayNum) {
      setState(() => _activeDayNum = focusedDayNum);
    }
    Scrollable.ensureVisible(
      entryContext,
      duration: TpMotion.normal,
      curve: TpMotion.appleEase,
      alignment: 0.08,
    );
  }

  void _syncActiveDayFromScroll() {
    final viewportContext = _scrollViewKey.currentContext;
    final viewportRenderObject = viewportContext?.findRenderObject();
    if (!mounted || viewportRenderObject is! RenderBox) return;

    final viewportTop = viewportRenderObject.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportRenderObject.size.height;
    final anchorY = viewportTop + viewportRenderObject.size.height * 0.2;
    int? nextActiveDayNum;
    var bestDistance = double.infinity;

    for (final day in widget.days) {
      final sectionContext = _daySectionKeys[day.dayNum]?.currentContext;
      final sectionRenderObject = sectionContext?.findRenderObject();
      if (sectionRenderObject is! RenderBox) continue;

      final sectionTop = sectionRenderObject.localToGlobal(Offset.zero).dy;
      final sectionBottom = sectionTop + sectionRenderObject.size.height;
      final isVisible =
          sectionBottom >= viewportTop && sectionTop <= viewportBottom;
      if (!isVisible) continue;

      final distance = (sectionTop - anchorY).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        nextActiveDayNum = day.dayNum;
      }
    }

    if (nextActiveDayNum != null && nextActiveDayNum != _activeDayNum) {
      setState(() => _activeDayNum = nextActiveDayNum!);
    }
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
    final segmentsByPair = {
      for (final segment in widget.segments)
        _segmentPairKey(segment.fromEntryId, segment.toEntryId): segment,
    };

    return Column(
      children: [
        DayPills(
          days: widget.days,
          activeDayNum: _activeDayNum,
          onDaySelected: _scrollToDay,
        ),
        if (widget.showSegmentError)
          _SegmentErrorBanner(onRetry: widget.onSegmentsRetry),
        Expanded(
          child: SingleChildScrollView(
            key: _scrollViewKey,
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
                    tripId: widget.tripId,
                    day: day,
                    entryKeys: _entryKeys,
                    segmentsByPair: segmentsByPair,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 單日 section：day header → hotel 卡 → entries（entry 之間插 travel pill）。
class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.tripId,
    required this.day,
    required this.entryKeys,
    required this.segmentsByPair,
  });

  final String tripId;
  final TripDay day;
  final Map<int, GlobalKey> entryKeys;
  final Map<String, TripSegment> segmentsByPair;

  @override
  Widget build(BuildContext context) {
    final timeline = day.timeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayHeader(day: day),
        const SizedBox(height: TpSpacing.s3),
        if (day.hotel != null) ...[
          HotelCard(hotel: day.hotel!),
          const SizedBox(height: TpSpacing.s3),
        ],
        ..._buildTimelineRows(context, timeline),
        const SizedBox(height: TpSpacing.s6),
      ],
    );
  }

  List<Widget> _buildTimelineRows(
    BuildContext context,
    List<TimelineEntry> timeline,
  ) {
    final rows = <Widget>[];
    for (var entryIndex = 0; entryIndex < timeline.length; entryIndex++) {
      final entry = timeline[entryIndex];
      if (entryIndex > 0) {
        final previousEntry = timeline[entryIndex - 1];
        final segment =
            segmentsByPair[_segmentPairKey(previousEntry.id, entry.id)];
        final travel = segment?.toTravel() ?? entry.travel;
        if (travel != null) {
          rows.add(
            _TravelRow(
              tripId: tripId,
              travel: travel,
              segment: segment,
              fromTitle: previousEntry.title,
              toTitle: entry.title,
            ),
          );
        }
      }
      rows.add(
        TimelineEntryTile(
          key: entryKeys[entry.id],
          entry: entry,
          isFirst: entryIndex == 0,
          isLast: entryIndex == timeline.length - 1,
          onEdit: () => GoRouter.maybeOf(
            context,
          )?.go('/trips/$tripId/stop/${entry.id}/edit'),
        ),
      );
    }
    return rows;
  }
}

/// travel pill 列：沿用 tile 的時間欄 + rail 縮排，rail 連線視覺連續。
class _TravelRow extends StatelessWidget {
  const _TravelRow({
    required this.tripId,
    required this.travel,
    required this.segment,
    required this.fromTitle,
    required this.toTitle,
  });

  final String tripId;
  final Travel travel;
  final TripSegment? segment;
  final String fromTitle;
  final String toTitle;

  @override
  Widget build(BuildContext context) {
    final railLineColor = Theme.of(context).colorScheme.outlineVariant;

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
              child: Align(
                alignment: Alignment.centerLeft,
                child: TravelPill(
                  travel: travel,
                  isStale: segment?.isStale ?? false,
                  onTap: segment == null
                      ? null
                      : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => TravelSegmentEditorSheet(
                            tripId: tripId,
                            segment: segment!,
                            fromTitle: fromTitle,
                            toTitle: toTitle,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentErrorBanner extends StatelessWidget {
  const _SegmentErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s4,
        vertical: TpSpacing.s2,
      ),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Text(
              '交通段載入失敗，已暫用舊資料顯示',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

String _segmentPairKey(int fromEntryId, int toEntryId) {
  return '$fromEntryId:$toEntryId';
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
