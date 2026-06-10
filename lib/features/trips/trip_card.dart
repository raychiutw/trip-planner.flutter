import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// 卡片 cover 色調：依清單 index 輪替 accent → sage → pink。
enum TripCardTone { accent, sage, pink }

/// TripSummary 顯示名稱：title 優先（人類可讀），空值退回 name。
extension TripSummaryDisplay on TripSummary {
  String get displayTitle {
    final trimmedTitle = title?.trim();
    if (trimmedTitle == null || trimmedTitle.isEmpty) return name;
    return trimmedTitle;
  }
}

/// 行程清單卡片：cover 色塊（tone subtle 底 + deep 首字）→ eyebrow（N 天）+
/// 標題 + chevron。elevation 0 + hairline 由 CardTheme 提供。
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.tone,
    this.onTap,
    this.onLongPress,
  });

  final TripSummary trip;
  final TripCardTone tone;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final (coverBackground, coverForeground) = switch (tone) {
      TripCardTone.accent => (tones.accentSubtle, tones.accentDeep),
      TripCardTone.sage => (tones.sageSubtle, tones.sageDeep),
      TripCardTone.pink => (tones.pinkSubtle, tones.pinkDeep),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // cover 色塊：subtle 底 + deep 首字 glyph（同色相由淺到深）
            Container(
              height: 88,
              color: coverBackground,
              alignment: Alignment.center,
              child: Text(
                trip.displayTitle.characters.first,
                style: theme.textTheme.displaySmall
                    ?.copyWith(color: coverForeground),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s4,
                vertical: TpSpacing.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (trip.totalDays != null) ...[
                          Text(
                            '${trip.totalDays} 天',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: TpSpacing.s1),
                        ],
                        Text(
                          trip.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
