import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../../models/day.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// 當日住宿卡：sage tone（subtle 底、deep 字、bed icon），hairline 用 sageBg。
class HotelCard extends StatelessWidget {
  const HotelCard({super.key, required this.hotel});

  final DayHotel hotel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;

    return Container(
      key: ValueKey('hotel-card-${hotel.id}'),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: tones.sageSubtle,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: tones.sageBg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tones.sageBg,
              borderRadius: BorderRadius.circular(TpRadius.md),
            ),
            child: Icon(
              CupertinoIcons.bed_double,
              size: 20,
              color: tones.sageDeep,
            ),
          ),
          const SizedBox(width: TpSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: tones.sageDeep,
                  ),
                ),
                if (hotel.checkout != null)
                  Text(
                    '退房 ${hotel.checkout}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (hotel.note != null && hotel.note!.isNotEmpty)
                  Text(
                    hotel.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
