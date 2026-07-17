import 'package:flutter/material.dart';

import '../../../models/day.dart';
import '../../../models/segment.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// 計算當日時間範圍字串「min–max」（en dash U+2013）。
///
/// 每筆 start 候選 = startTime ?? time、end 候選 = endTime ?? startTime ?? time;
/// HH:MM 字典序取 min/max。timeline 無任何時間 → 回 null。
String? dayTimeRange(TripDay day) {
  String? min;
  String? max;
  for (final e in day.timeline) {
    final start = e.startTime ?? e.time;
    final end = e.endTime ?? e.startTime ?? e.time;
    if (start != null && (min == null || start.compareTo(min) < 0)) {
      min = start;
    }
    if (end != null && (max == null || end.compareTo(max) > 0)) {
      max = end;
    }
  }
  if (min == null || max == null) return null;
  return '$min–$max';
}

int dayTotalDistanceM(TripDay day, List<TripSegment> segments) {
  final segmentByPair = <String, TripSegment>{
    for (final segment in segments)
      if (segment.fromEntryId != null && segment.toEntryId != null)
        '${segment.fromEntryId}-${segment.toEntryId}': segment,
  };
  var total = 0;
  for (var i = 1; i < day.timeline.length; i++) {
    final prev = day.timeline[i - 1];
    final curr = day.timeline[i];
    total +=
        segmentByPair['${prev.id}-${curr.id}']?.distanceM ??
        prev.travel?.distanceM ??
        0;
  }
  return total;
}

/// 逐日 section 標頭：eyebrow「DAY NN」+ 日期主標。
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, this.segments = const []});

  final TripDay day;
  final List<TripSegment> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final timeRange = dayTimeRange(day);
    final stopCount = day.timeline.length;
    final totalM = dayTotalDistanceM(day, segments);
    final summary = totalM == 0
        ? '$stopCount 個停留點'
        : '$stopCount 個停留點 · ${(totalM / 1000).round()} km';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'DAY ${day.dayNum.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: tones.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (timeRange != null) ...[
              const SizedBox(width: TpSpacing.s2),
              Text(
                timeRange,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: TpSpacing.s1),
        Text(day.displayTitle, style: theme.textTheme.titleLarge),
        Text(
          summary,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
