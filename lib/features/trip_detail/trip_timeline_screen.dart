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
import 'widgets/entry_edit_sheet.dart';
import 'widgets/hotel_card.dart';
import 'widgets/timeline_entry_tile.dart';
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
            tooltip: '地圖',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/map'),
          ),
          IconButton(
            tooltip: '筆記',
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => _goTo(context, '/trips/$tripId/notes'),
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
                      tripId: widget.tripId),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 單日 section：day header → hotel 卡 → entries（entry 之間插 travel pill）→ 新增鈕。
/// entry 可點（編輯）、左滑（刪除）。
class _DaySection extends ConsumerWidget {
  const _DaySection({super.key, required this.tripId, required this.day});

  final String tripId;
  final TripDay day;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TimelineEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除停留點'),
        content: Text('確定要刪除「${entry.title}」嗎？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(tripRepositoryProvider)
          .deleteEntry(tripId: tripId, entryId: entry.id);
      ref.invalidate(tripDaysProvider(tripId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已刪除')));
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('刪除失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        for (var i = 0; i < timeline.length; i++) ...[
          if (i > 0 && timeline[i].travel != null)
            _TravelRow(travel: timeline[i].travel!),
          Dismissible(
            key: ValueKey('entry-dismiss-${timeline[i].id}'),
            direction: DismissDirection.endToStart,
            background: const _DeleteBackground(),
            confirmDismiss: (_) async {
              await _confirmDelete(context, ref, timeline[i]);
              return false; // 靠 invalidate 重抓移除,避免與 provider 資料雙重移除
            },
            child: TimelineEntryTile(
              entry: timeline[i],
              isFirst: i == 0,
              isLast: i == timeline.length - 1,
              onTap: () => showEntryEditSheet(context,
                  tripId: tripId, args: EntryEditExisting(timeline[i])),
            ),
          ),
        ],
        const SizedBox(height: TpSpacing.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('add-entry-${day.dayNum}'),
            onPressed: () => showEntryEditSheet(context,
                tripId: tripId, args: EntryEditNew(day.dayNum)),
            icon: const Icon(Icons.add),
            label: const Text('新增停留點'),
          ),
        ),
        const SizedBox(height: TpSpacing.s6),
      ],
    );
  }
}

/// 左滑刪除背景。
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

/// travel pill 列：沿用 tile 的時間欄 + rail 縮排，rail 連線視覺連續。
class _TravelRow extends StatelessWidget {
  const _TravelRow({required this.travel});

  final Travel travel;

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
                child: TravelPill(travel: travel),
              ),
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
