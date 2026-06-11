import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 共用評分標籤：星星 icon + 一位小數評分（tabular figures 對齊）。
/// 收藏卡與探索卡共用，避免重複樣式。
class PoiRatingLabel extends StatelessWidget {
  const PoiRatingLabel({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 14, color: tones.accent),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
