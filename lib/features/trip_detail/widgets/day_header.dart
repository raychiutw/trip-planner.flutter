import 'package:flutter/material.dart';

import '../../../models/day.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// 逐日 section 標頭：eyebrow「DAY NN」+ 日期（tabular）+ displayTitle。
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day});

  final TripDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final dateLabel = [
      if (day.date != null) day.date!,
      if (day.dayOfWeek != null) '（${day.dayOfWeek}）',
    ].join();

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
            if (dateLabel.isNotEmpty) ...[
              const SizedBox(width: TpSpacing.s2),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: TpSpacing.s1),
        Text(day.displayTitle, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
