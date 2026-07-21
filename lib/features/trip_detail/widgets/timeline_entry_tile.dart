import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../models/entry.dart';
import '../../../models/poi_type.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import 'entry_duration.dart';

const double kTimelineRailWidth = 32;

class TimelineEntryTile extends StatelessWidget {
  const TimelineEntryTile({
    super.key,
    required this.entry,
    required this.number,
    this.isFirst = false,
    this.isLast = false,
    this.isFocused = false,
    this.compact = false,
    this.expanded = false,
    this.onTap,
    this.onEditTime,
    this.trailing,
    this.mapLinks,
    this.expandedChild,
  });

  final TimelineEntry entry;
  final int number;
  final bool isFirst;
  final bool isLast;
  final bool isFocused;
  final bool compact;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onEditTime;
  final Widget? trailing;
  final Widget? mapLinks;
  final Widget? expandedChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
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
      child: InkWell(
        excludeFromSemantics: true,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: _EntryCard(
          entry: entry,
          isFocused: isFocused,
          categoryLabel: categoryLabel,
          compact: compact,
          timeLabel: timeLabel,
          onEditTime: onEditTime,
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
                  isLast: isLast && expandedChild == null,
                  color: tones.accentDeep,
                  lineColor: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 10),
                Expanded(child: card),
              ],
            ),
          ),
          const SizedBox(height: TpSpacing.s3),
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
                              color: isLast
                                  ? Colors.transparent
                                  : theme.colorScheme.outlineVariant,
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
  final start = (entry.startTime ?? entry.time ?? '').trim();
  final end = (entry.endTime ?? '').trim();
  if (start.isEmpty && end.isEmpty) return '未設定時間';
  if (start.isEmpty) return end;
  if (end.isEmpty) return start;
  return '$start–$end';
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.entryId,
    required this.number,
    required this.isFirst,
    required this.isLast,
    required this.color,
    required this.lineColor,
  });

  final int entryId;
  final int number;
  final bool isFirst;
  final bool isLast;
  final Color color;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kTimelineRailWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!isFirst || !isLast)
            Positioned(
              top: isFirst ? 22 : 0,
              bottom: isLast ? null : 0,
              height: isLast ? 22 : null,
              child: Container(width: 1, color: lineColor),
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
    this.onEditTime,
    this.trailing,
    this.mapLinks,
  });

  final TimelineEntry entry;
  final bool isFocused;
  final String? categoryLabel;
  final bool compact;
  final String timeLabel;
  final VoidCallback? onEditTime;
  final Widget? trailing;
  final Widget? mapLinks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final master = entry.master;
    final muted = theme.colorScheme.onSurfaceVariant;
    final duration = formatEntryDuration(entry.startTime, entry.endTime);
    final details = _details(entry);

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
            Wrap(
              key: ValueKey('entry-meta-${entry.id}'),
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  key: ValueKey('entry-time-${entry.id}'),
                  avatar: const Icon(CupertinoIcons.clock, size: 14),
                  label: Text(
                    timeLabel,
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  onPressed: onEditTime,
                ),
                if (categoryLabel != null)
                  Text(
                    categoryLabel!,
                    key: ValueKey('entry-category-${entry.id}'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                if (duration != null)
                  Text(
                    duration,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (master?.rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.star_fill,
                        size: 14,
                        color: tones.accent,
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
            if (mapLinks != null) ...[
              const SizedBox(height: TpSpacing.s1),
              mapLinks!,
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s1),
              Text(
                details.join(' · '),
                key: ValueKey('entry-details-${entry.id}'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
