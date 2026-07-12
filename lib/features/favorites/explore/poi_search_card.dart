import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../../models/poi_search_result.dart';
import '../../../models/poi_type.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/poi_tone.dart';
import '../../../theme/tokens.dart';
import '../poi_rating_label.dart';

/// 探索 POI 單欄資訊卡：緊湊 tone 圖示 + 類型/name/address/rating + actions。
class PoiSearchCard extends StatelessWidget {
  const PoiSearchCard({
    super.key,
    required this.poi,
    required this.isSaved,
    required this.isSaving,
    required this.onToggleFavorite,
    this.onAddToTrip,
  });

  final PoiSearchResult poi;
  final bool isSaved;
  final bool isSaving;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onAddToTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final poiType = mapGooglePrimaryTypeToPoiType(poi.category);
    final categoryLabel =
        poiCategoryLabel(poi.category) ?? kPoiTypeLabels[poiType] ?? 'POI';
    final tone = resolvePoiTone(tones, poiType);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      key: ValueKey('poi-card-${poi.placeId}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            constraints: const BoxConstraints(minHeight: 112),
            color: tone.subtle,
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.location_solid,
              size: 26,
              color: tone.deep,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tone.deep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    poi.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  if (poi.address != null && poi.address!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        poi.address!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedColor,
                        ),
                      ),
                    ),
                  if (poi.rating != null) ...[
                    const SizedBox(height: TpSpacing.s2),
                    PoiRatingLabel(rating: poi.rating!),
                  ],
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onAddToTrip != null)
                IconButton(
                  key: ValueKey('poi-add-to-trip-${poi.placeId}'),
                  tooltip: '加入行程',
                  icon: const Icon(Icons.add_location_alt_outlined),
                  onPressed: onAddToTrip,
                ),
              IconButton(
                key: ValueKey('poi-heart-${poi.placeId}'),
                tooltip: isSaved ? '已收藏 · 點擊取消' : '加入收藏',
                onPressed: isSaving ? null : onToggleFavorite,
                icon: Icon(
                  isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: isSaved
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
