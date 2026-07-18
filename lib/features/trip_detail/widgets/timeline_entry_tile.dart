import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../../models/entry.dart';
import '../../../models/poi_type.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/poi_tone.dart';
import 'entry_duration.dart';

/// 時間欄寬度（timeline rail 對齊用，travel row 共用）。
const double kTimelineTimeColumnWidth = 48;

/// rail（圓點 + 連線）欄寬度。
const double kTimelineRailWidth = 24;

/// 時間軸停留點 tile：時間欄（tabular）+ tone 圓點 rail + 內容卡。
/// tone 依 master.type：玩/看/買=accent、住/移動=sage、吃=pink。
class TimelineEntryTile extends StatelessWidget {
  const TimelineEntryTile({
    super.key,
    required this.entry,
    required this.number,
    this.isFirst = false,
    this.isLast = false,
    this.isFocused = false,
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

  /// 點內容卡的回呼（null 則不可點）。
  final VoidCallback? onTap;

  /// tile 尾端附加元件（拖曳 handle、搬移鈕）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final tone = resolvePoiTone(tones, entry.master?.type);
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
      label: semanticsLabel,
      hint: onTap == null ? null : '點兩下編輯停留點',
      button: onTap != null,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TpRadius.md),
          child: _EntryCard(
            entry: entry,
            tone: tone,
            isFocused: isFocused,
            categoryLabel: categoryLabel,
          ),
        ),
      ),
    );
    final accessibilityLayout =
        MediaQuery.textScalerOf(context).scale(17) >= 23;

    if (accessibilityLayout) {
      return KeyedSubtree(
        key: ValueKey('timeline-entry-accessibility-${entry.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TimelineRail(
                entryId: entry.id,
                number: number,
                isFirst: isFirst,
                isLast: isLast,
                color: tone.deep,
                lineColor: railLineColor,
              ),
              const SizedBox(width: TpSpacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EntryTimeRange(startTime: startTime, endTime: endTime),
                    const SizedBox(height: TpSpacing.s2),
                    entryContent,
                    if (trailing != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: trailing,
                      ),
                    const SizedBox(height: TpSpacing.s3),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: kTimelineTimeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _EntryTimeRange(startTime: startTime, endTime: endTime),
            ),
          ),
          _TimelineRail(
            entryId: entry.id,
            number: number,
            isFirst: isFirst,
            isLast: isLast,
            color: tone.deep,
            lineColor: railLineColor,
          ),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: TpSpacing.s3),
              child: entryContent,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _EntryTimeRange extends StatelessWidget {
  const _EntryTimeRange({required this.startTime, required this.endTime});

  final String startTime;
  final String endTime;

  @override
  Widget build(BuildContext context) {
    if (startTime.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(startTime, style: style),
        if (endTime.isNotEmpty)
          Text(
            '– $endTime',
            style: style?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
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
      child: Column(
        children: [
          Container(
            width: 1,
            height: 16,
            color: isFirst ? Colors.transparent : lineColor,
          ),
          Container(
            key: ValueKey('entry-dot-$entryId'),
            width: 18,
            height: 18,
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
          Expanded(
            child: Container(
              width: 1,
              color: isLast ? Colors.transparent : lineColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 內容卡：tone 色階梯（卡底 subtle、hairline bg、分類字 deep）。
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.tone,
    required this.isFocused,
    required this.categoryLabel,
  });

  final TimelineEntry entry;
  final PoiToneColors tone;
  final bool isFocused;
  final String? categoryLabel;

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
              style: TextStyle(
                fontSize: 11,
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
          Text(masterName, style: TextStyle(fontSize: 12, color: mutedColor)),
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
                style: TextStyle(
                  fontSize: 11,
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
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: tone.subtle,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(
          color: isFocused ? tone.deep : tone.bg,
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (categoryLabel != null)
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (metaItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TpSpacing.s1),
              child: Wrap(
                spacing: TpSpacing.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: metaItems,
              ),
            ),
          if (entry.description != null && entry.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TpSpacing.s1),
              child: Text(
                entry.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
              ),
            ),
        ],
      ),
    );
  }
}
