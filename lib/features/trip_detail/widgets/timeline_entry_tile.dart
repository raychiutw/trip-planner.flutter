import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../models/entry.dart';
import '../../../models/poi_type.dart';
import '../../../theme/tokens.dart';
import 'entry_duration.dart';

const double kTimelineRailWidth = 32;

class TimelineEntryTile extends StatelessWidget {
  const TimelineEntryTile({
    super.key,
    required this.entry,
    required this.number,
    this.isFirst = false,
    this.isFocused = false,
    this.compact = false,
    this.expanded = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.mapLinks,
    this.expandedChild,
  });

  final TimelineEntry entry;
  final int number;
  final bool isFirst;
  final bool isFocused;
  final bool compact;
  final bool expanded;
  final VoidCallback? onTap;

  /// 長按卡片的入口；畫面接的是 `⋯` 那顆選單的 [MenuController]。
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Widget? mapLinks;
  final Widget? expandedChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryLabel =
        poiCategoryLabel(entry.master?.category) ??
        kPoiTypeLabels[entry.master?.type];
    final timeLabel = _timeLabel(entry);
    final semanticsLabel = [
      entry.title,
      timeLabel,
      categoryLabel ?? '停留點',
    ].join('，');

    final card = Semantics(
      key: ValueKey('timeline-entry-content-${entry.id}'),
      container: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      hint: onTap == null ? null : (expanded ? '點兩下收合備選景點' : '點兩下展開備選景點'),
      button: onTap != null,
      expanded: onTap == null ? null : expanded,
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        excludeFromSemantics: true,
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: _EntryCard(
          entry: entry,
          isFocused: isFocused,
          categoryLabel: categoryLabel,
          compact: compact,
          timeLabel: timeLabel,
          trailing: trailing,
          mapLinks: mapLinks,
        ),
      ),
    );

    return KeyedSubtree(
      key: ValueKey('timeline-entry-d1-${entry.id}'),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TimelineRail(
                  entryId: entry.id,
                  number: number,
                  isFirst: isFirst,
                  color: theme.colorScheme.onPrimaryContainer,
                  lineColor: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 10),
                Expanded(child: card),
              ],
            ),
          ),
          SizedBox(
            height: TpSpacing.s3,
            child: Row(
              children: [
                SizedBox(
                  width: kTimelineRailWidth,
                  child: Center(
                    child: Container(
                      key: ValueKey('entry-rail-gap-${entry.id}'),
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
          AnimatedSize(
            duration: TpMotion.resolve(context, TpMotion.normal),
            curve: TpMotion.appleEase,
            alignment: Alignment.topCenter,
            child: expandedChild == null
                ? const SizedBox.shrink()
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: kTimelineRailWidth,
                          child: Center(
                            child: Container(
                              width: 1,
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: TpSpacing.s3,
                            ),
                            child: expandedChild!,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _timeLabel(TimelineEntry entry) {
  final start = _resolvedStartTime(entry);
  final end = _resolvedEndTime(entry);
  if (start.isEmpty && end.isEmpty) return '未設定時間';
  if (start.isEmpty) return _displayTime(end);
  if (end.isEmpty) return _displayTime(start);
  return '${_displayTime(start)} - ${_displayTime(end)}';
}

String _displayTime(String value) => value.replaceAll(':', '：');

String _resolvedStartTime(TimelineEntry entry) =>
    (entry.startTime ?? entry.time ?? '').trim();

String _resolvedEndTime(TimelineEntry entry) => (entry.endTime ?? '').trim();

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.entryId,
    required this.number,
    required this.isFirst,
    required this.color,
    required this.lineColor,
  });

  final int entryId;
  final int number;
  final bool isFirst;
  final Color color;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kTimelineRailWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: isFirst ? 0.5 : 1,
                child: Container(
                  key: ValueKey('entry-rail-line-$entryId'),
                  width: 1,
                  color: lineColor,
                ),
              ),
            ),
          ),
          Container(
            key: ValueKey('entry-dot-$entryId'),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onPrimary,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.isFocused,
    required this.categoryLabel,
    required this.compact,
    required this.timeLabel,
    this.trailing,
    this.mapLinks,
  });

  final TimelineEntry entry;
  final bool isFocused;
  final String? categoryLabel;
  final bool compact;
  final String timeLabel;
  final Widget? trailing;
  final Widget? mapLinks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final master = entry.master;
    final muted = theme.colorScheme.onSurfaceVariant;
    final duration = formatEntryDuration(
      _resolvedStartTime(entry),
      _resolvedEndTime(entry),
    );
    final details = _details(entry);
    final accessibilityText = MediaQuery.textScalerOf(context).scale(1) >= 2;

    return Container(
      key: ValueKey('entry-card-${entry.id}'),
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.symmetric(
              horizontal: TpSpacing.s4,
              vertical: TpSpacing.s2,
            )
          : const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFocused
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: TpSpacing.s1),
                trailing!,
              ],
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: TpSpacing.s1),
            Column(
              key: ValueKey('entry-meta-${entry.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: TpSpacing.s2,
                  runSpacing: TpSpacing.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 時間是純顯示:不是 chip、不是按鈕。點它與點卡片其他地方
                    // 一樣會展開 —— 整張卡片行為一致,不留死區(使用者拍板)。
                    KeyedSubtree(
                      key: ValueKey('entry-time-${entry.id}'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!accessibilityText) ...[
                            Icon(CupertinoIcons.clock, size: 14, color: muted),
                            const SizedBox(width: 4),
                          ],
                          // 定版版面要求完整起訖時間維持一行。先拿掉裝飾性圖示,
                          // 只有無障礙字級真的撐破卡片寬度時才等比縮小。
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                timeLabel,
                                maxLines: 1,
                                softWrap: false,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (duration != null)
                      Text(
                        duration,
                        key: ValueKey('entry-duration-${entry.id}'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                if (categoryLabel != null || master?.rating != null) ...[
                  const SizedBox(height: TpSpacing.s1),
                  Wrap(
                    spacing: TpSpacing.s2,
                    runSpacing: TpSpacing.s1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (categoryLabel != null)
                        Text(
                          categoryLabel!,
                          key: ValueKey('entry-category-${entry.id}'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      if (master?.rating != null)
                        Row(
                          key: ValueKey('entry-rating-${entry.id}'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.star_fill,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              master!.rating!.toStringAsFixed(1),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
            if (mapLinks != null) ...[
              const SizedBox(height: TpSpacing.s1),
              mapLinks!,
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s1),
              Text(
                details.join('\n'),
                key: ValueKey('entry-details-${entry.id}'),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

List<String> _details(TimelineEntry entry) {
  final master = entry.master;
  final values = [
    entry.description,
    master?.description,
    entry.note == null ? null : '備註：${entry.note}',
    master?.note == null ? null : '備註：${master?.note}',
    master?.price,
    master?.hours,
    master?.reservation,
  ];
  final result = <String>[];
  for (final value in values) {
    final clean = value?.trim();
    if (clean != null && clean.isNotEmpty && !result.contains(clean)) {
      result.add(clean);
    }
  }
  return result;
}
