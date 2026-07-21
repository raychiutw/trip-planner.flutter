import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../../models/entry.dart';
import '../../../models/poi_type.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import 'entry_duration.dart';

/// rail（圓點 + 連線）欄寬度。
const double kTimelineRailWidth = 32;

/// D1 時間軸停留點：固定左 rail，時間與卡片共用同一內容起點。
class TimelineEntryTile extends StatelessWidget {
  const TimelineEntryTile({
    super.key,
    required this.entry,
    required this.number,
    this.isFirst = false,
    this.isLast = false,
    this.isFocused = false,
    this.compact = false,
    this.onTap,
    this.trailing,
  });

  final TimelineEntry entry;

  /// 當日序號（1-based),渲染於 rail badge。
  final int number;

  /// 當日第一個 entry：rail 不畫圓點上方連線。
  final bool isFirst;

  /// 當日最後一個 entry：rail 不畫圓點下方連線。
  final bool isLast;

  /// deep link 或搜尋結果指定的目前聚焦停留點。
  final bool isFocused;

  /// 排序模式只保留名稱與拖曳手把。
  final bool compact;

  /// 點內容卡的回呼（null 則不可點）。
  final VoidCallback? onTap;

  /// tile 尾端附加元件（拖曳 handle、搬移鈕）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final railLineColor = theme.colorScheme.outlineVariant;
    final startTime = (entry.startTime ?? entry.time ?? '').trim();
    final endTime = entry.endTime?.trim() ?? '';
    final categoryLabel =
        poiCategoryLabel(entry.master?.category) ??
        kPoiTypeLabels[entry.master?.type];
    final timeSemantics = startTime.isEmpty
        ? null
        : endTime.isEmpty
        ? startTime
        : '$startTime 到 $endTime';
    final semanticsLabel = [
      entry.title,
      ?timeSemantics,
      categoryLabel ?? '停留點',
    ].join('，');
    final entryContent = Semantics(
      key: ValueKey('timeline-entry-content-${entry.id}'),
      label: semanticsLabel,
      hint: onTap == null ? null : '點兩下編輯停留點',
      button: onTap != null,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: _EntryCard(
            entry: entry,
            isFocused: isFocused,
            categoryLabel: categoryLabel,
            compact: compact,
            trailing: trailing,
          ),
        ),
      ),
    );
    return KeyedSubtree(
      key: ValueKey('timeline-entry-d1-${entry.id}'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimelineRail(
              entryId: entry.id,
              number: number,
              isFirst: isFirst,
              isLast: isLast,
              color: tones.accentDeep,
              lineColor: railLineColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EntryTimeRange(
                    entryId: entry.id,
                    startTime: startTime,
                    endTime: endTime,
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  entryContent,
                  const SizedBox(height: TpSpacing.s3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTimeRange extends StatelessWidget {
  const _EntryTimeRange({
    required this.entryId,
    required this.startTime,
    required this.endTime,
  });

  final int entryId;
  final String startTime;
  final String endTime;

  @override
  Widget build(BuildContext context) {
    if (startTime.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final visualStart = _visualTime(startTime);
    final visualEnd = _visualTime(endTime);
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        key: ValueKey('entry-time-scale-$entryId'),
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          visualEnd.isEmpty ? visualStart : '$visualStart - $visualEnd',
          maxLines: 1,
          softWrap: false,
          style: style,
        ),
      ),
    );
  }
}

String _visualTime(String value) => value.replaceFirst(':', '：');

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
        alignment: Alignment.topCenter,
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

/// 內容卡統一使用中性 system surface；POI 類型只以文字呈現。
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.isFocused,
    required this.categoryLabel,
    required this.compact,
    this.trailing,
  });

  final TimelineEntry entry;
  final bool isFocused;
  final String? categoryLabel;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final master = entry.master;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    final metaItems = <Widget>[];
    final duration = formatEntryDuration(entry.startTime, entry.endTime);
    if (duration != null) {
      metaItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.clock, size: 14, color: mutedColor),
            const SizedBox(width: 2),
            Text(
              duration,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mutedColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }
    if (master != null) {
      final masterName = master.name;
      if (masterName != null && masterName != entry.title) {
        metaItems.add(
          Text(
            masterName,
            style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
          ),
        );
      }
      if (master.rating != null) {
        // rating 一律 accent（設計系統：rating 屬 accent 職責）
        metaItems.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.star_fill, size: 14, color: tones.accent),
              const SizedBox(width: 2),
              Text(
                master.rating!.toStringAsFixed(1),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      }
    }

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (!compact && categoryLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Row(
                      key: ValueKey('entry-category-${entry.id}'),
                      children: [
                        Icon(
                          CupertinoIcons.tag,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            categoryLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!compact && metaItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Wrap(
                      spacing: TpSpacing.s2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: metaItems,
                    ),
                  ),
                if (!compact &&
                    entry.description != null &&
                    entry.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Text(
                      entry.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: TpSpacing.s2),
            trailing!,
          ],
        ],
      ),
    );
  }
}
