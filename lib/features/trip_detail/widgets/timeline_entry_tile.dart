import 'package:flutter/material.dart';

import '../../../models/entry.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import 'entry_tone.dart';

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
    this.isFirst = false,
    this.isLast = false,
  });

  final TimelineEntry entry;

  /// 當日第一個 entry：rail 不畫圓點上方連線。
  final bool isFirst;

  /// 當日最後一個 entry：rail 不畫圓點下方連線。
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final tone = resolveEntryTone(tones, entry.master?.type);
    final railLineColor = theme.colorScheme.outlineVariant;
    final displayTime = entry.startTime ?? entry.time ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: kTimelineTimeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                displayTime,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          SizedBox(
            width: kTimelineRailWidth,
            child: Column(
              children: [
                Container(
                  width: 1,
                  height: 16,
                  color: isFirst ? Colors.transparent : railLineColor,
                ),
                Container(
                  key: ValueKey('entry-dot-${entry.id}'),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tone.deep,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1,
                    color: isLast ? Colors.transparent : railLineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: TpSpacing.s3),
              child: _EntryCard(entry: entry, tone: tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// 內容卡：tone 色階梯（卡底 subtle、hairline bg、分類字 deep）。
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.tone});

  final TimelineEntry entry;
  final EntryToneColors tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final master = entry.master;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    final metaItems = <Widget>[];
    if (master != null) {
      final masterName = master.name;
      if (masterName != null && masterName != entry.title) {
        metaItems.add(Text(
          masterName,
          style: TextStyle(fontSize: 13, color: mutedColor),
        ));
      }
      if (master.category != null) {
        metaItems.add(Text(
          master.category!,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tone.deep,
          ),
        ));
      }
      if (master.rating != null) {
        // rating 一律 accent（設計系統：rating 屬 accent 職責）
        metaItems.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 14, color: tones.accent),
            const SizedBox(width: 2),
            Text(
              master.rating!.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                color: mutedColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: tone.subtle,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: tone.bg),
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
