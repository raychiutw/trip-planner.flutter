import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';
import 'widgets/day_header.dart';
import 'widgets/day_pills.dart';
import 'widgets/hotel_card.dart';
import 'widgets/timeline_entry_tile.dart';
import 'widgets/travel_pill.dart';

enum _TimelineOverflowAction { health, collab }

final timelineOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool hasNetwork(List<ConnectivityResult> results) {
    return !results.contains(ConnectivityResult.none);
  }

  yield hasNetwork(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(hasNetwork).distinct();
});

/// 行程時間軸畫面：AppBar（trip 名 + 地圖/筆記 actions）→ 頂部 day pills →
/// 逐日 section（day header → hotel 卡 → timeline rail + travel pill）。
class TripTimelineScreen extends ConsumerStatefulWidget {
  const TripTimelineScreen({
    super.key,
    required this.tripId,
    this.focusEntryId,
    this.today,
  });

  final String tripId;

  /// Optional entry id to scroll into view after timeline data loads.
  final int? focusEntryId;

  /// Optional date used by tests to make today auto-scroll deterministic.
  final DateTime? today;

  @override
  ConsumerState<TripTimelineScreen> createState() => _TripTimelineScreenState();
}

class _TripTimelineScreenState extends ConsumerState<TripTimelineScreen> {
  final Set<String> _autoRecomputeAttempts = <String>{};

  @override
  void didUpdateWidget(covariant TripTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _autoRecomputeAttempts.clear();
    }
  }

  void _goTo(BuildContext context, String location) {
    // 測試環境可能未掛 GoRouter，maybeOf 避免 crash
    GoRouter.maybeOf(context)?.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripId;
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    final segmentsAsync = ref.watch(tripSegmentsProvider(tripId));
    final isOnline = ref.watch(timelineOnlineProvider).value ?? true;
    final trip = tripAsync.value;
    final tripTitle = trip?.title ?? trip?.name ?? '行程';

    ref.listen<AsyncValue<bool>>(timelineOnlineProvider, (previous, next) {
      final wasOnline = previous?.value ?? true;
      final nowOnline = next.value ?? true;
      if (!wasOnline && nowOnline) {
        ref.invalidate(tripDaysProvider(tripId));
        ref.invalidate(tripSegmentsProvider(tripId));
      }
    });

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
          PopupMenuButton<_TimelineOverflowAction>(
            key: const ValueKey('timeline-overflow-actions'),
            tooltip: '更多行程動作',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _TimelineOverflowAction.health:
                  _goTo(context, '/trips/$tripId/health');
                case _TimelineOverflowAction.collab:
                  _goTo(context, '/trips/$tripId/collab');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                key: ValueKey('timeline-overflow-health'),
                value: _TimelineOverflowAction.health,
                child: ListTile(
                  leading: Icon(Icons.health_and_safety_outlined),
                  title: Text('AI 健檢'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                key: ValueKey('timeline-overflow-collab'),
                value: _TimelineOverflowAction.collab,
                child: ListTile(
                  leading: Icon(Icons.group_outlined),
                  title: Text('共編設定'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: daysAsync.when(
        data: (days) {
          final loadedSegments = segmentsAsync.whenOrNull(
            data: (segments) => segments,
          );
          if (days.isNotEmpty && loadedSegments != null) {
            _queueSegmentAutoRecompute(
              tripId: tripId,
              days: days,
              segments: loadedSegments,
            );
          }

          return days.isEmpty
              ? const _EmptyTimeline()
              : _TimelineBody(
                  tripId: tripId,
                  focusEntryId: widget.focusEntryId,
                  today: widget.today,
                  days: days,
                  segments: segmentsAsync.value ?? const <TripSegment>[],
                  isOnline: isOnline,
                  showSegmentError: segmentsAsync.hasError,
                  onSegmentsRetry: () =>
                      ref.invalidate(tripSegmentsProvider(tripId)),
                );
        },
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

  void _queueSegmentAutoRecompute({
    required String tripId,
    required List<TripDay> days,
    required List<TripSegment> segments,
  }) {
    final jobs = _segmentAutoRecomputeJobs(days: days, segments: segments);
    final pendingJobs = <_SegmentAutoRecomputeJob>[];

    for (final job in jobs) {
      final attemptKey = '$tripId|${job.dayNum}|${job.signature}';
      if (_autoRecomputeAttempts.add(attemptKey)) {
        pendingJobs.add(job);
      }
    }

    if (pendingJobs.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final job in pendingJobs) {
        unawaited(_runSegmentAutoRecompute(tripId: tripId, job: job));
      }
    });
  }

  Future<void> _runSegmentAutoRecompute({
    required String tripId,
    required _SegmentAutoRecomputeJob job,
  }) async {
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId, dayNum: job.dayNum);
      if (!mounted) return;
      ref.invalidate(tripSegmentsProvider(tripId));
      ref.invalidate(tripDaysProvider(tripId));
    } catch (_) {
      // Auto-healing mirrors web: keep fallback UI and avoid noisy toasts.
    }
  }
}

/// 日程主體：day pills + 可捲動逐日 sections；pill 點擊 ensureVisible 捲至該日。
class _TimelineBody extends StatefulWidget {
  const _TimelineBody({
    required this.tripId,
    required this.focusEntryId,
    required this.today,
    required this.days,
    required this.segments,
    required this.isOnline,
    required this.showSegmentError,
    required this.onSegmentsRetry,
  });

  final String tripId;
  final int? focusEntryId;
  final DateTime? today;
  final List<TripDay> days;
  final List<TripSegment> segments;
  final bool isOnline;
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
        _initialTargetDayNum() ??
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
        oldWidget.today != widget.today ||
        !identical(oldWidget.days, widget.days)) {
      _didApplyInitialFocus = false;
      final targetDayNum = _initialTargetDayNum();
      if (targetDayNum != null && targetDayNum != _activeDayNum) {
        _activeDayNum = targetDayNum;
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

  int? _dayNumForDate(DateTime date) {
    final dateKey = _dateKey(date);
    for (final day in widget.days) {
      if (day.date == dateKey) return day.dayNum;
    }
    return null;
  }

  int? _initialTargetDayNum() {
    return _dayNumForEntry(widget.focusEntryId) ??
        _dayNumForDate(widget.today ?? DateTime.now());
  }

  void _scheduleInitialFocus() {
    if (_didApplyInitialFocus || _initialTargetDayNum() == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialFocus());
  }

  void _applyInitialFocus() {
    if (!mounted || _didApplyInitialFocus) return;
    final focusEntryId = widget.focusEntryId;
    final focusedDayNum = _dayNumForEntry(focusEntryId);
    final entryContext = focusEntryId == null
        ? null
        : _entryKeys[focusEntryId]?.currentContext;
    if (entryContext != null) {
      _didApplyInitialFocus = true;
      if (focusedDayNum != null && focusedDayNum != _activeDayNum) {
        setState(() => _activeDayNum = focusedDayNum);
      }
      Scrollable.ensureVisible(
        entryContext,
        duration: TpMotion.normal,
        curve: TpMotion.appleEase,
        alignment: 0.08,
      );
      return;
    }

    final todayDayNum = _dayNumForDate(widget.today ?? DateTime.now());
    final sectionContext = _daySectionKeys[todayDayNum]?.currentContext;
    if (todayDayNum == null || sectionContext == null) return;
    _didApplyInitialFocus = true;
    if (todayDayNum != _activeDayNum) {
      setState(() => _activeDayNum = todayDayNum);
    }
    Scrollable.ensureVisible(
      sectionContext,
      duration: TpMotion.normal,
      curve: TpMotion.appleEase,
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
        if (!widget.isOnline) const _OfflineBanner(),
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('timeline-offline-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s4,
        vertical: TpSpacing.s3,
      ),
      color: theme.colorScheme.tertiaryContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 20,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '目前是離線模式',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: TpSpacing.s1),
                Text(
                  '正在顯示快取資料，重新連線後會自動更新時間軸。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
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

class _SegmentAutoRecomputeJob {
  const _SegmentAutoRecomputeJob({
    required this.dayNum,
    required this.signature,
  });

  final int dayNum;
  final String signature;
}

List<_SegmentAutoRecomputeJob> _segmentAutoRecomputeJobs({
  required List<TripDay> days,
  required List<TripSegment> segments,
}) {
  final segmentsByPair = {
    for (final segment in segments)
      _segmentPairKey(segment.fromEntryId, segment.toEntryId): segment,
  };
  final jobs = <_SegmentAutoRecomputeJob>[];

  for (final day in days) {
    final gaps = <String>[];
    for (var entryIndex = 1; entryIndex < day.timeline.length; entryIndex++) {
      final previousEntry = day.timeline[entryIndex - 1];
      final entry = day.timeline[entryIndex];
      if (!_hasCoordinates(previousEntry) || !_hasCoordinates(entry)) {
        continue;
      }

      final pairKey = _segmentPairKey(previousEntry.id, entry.id);
      final segment = segmentsByPair[pairKey];
      if (segment == null || segment.isStale) {
        gaps.add(pairKey);
      }
    }

    if (gaps.isNotEmpty) {
      jobs.add(
        _SegmentAutoRecomputeJob(dayNum: day.dayNum, signature: gaps.join(',')),
      );
    }
  }

  return jobs;
}

bool _hasCoordinates(TimelineEntry entry) {
  final master = entry.master;
  return master?.lat != null && master?.lng != null;
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
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
