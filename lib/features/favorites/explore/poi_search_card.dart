import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../../models/poi_search_result.dart';
import '../../../models/poi_type.dart';
import '../../../theme/tokens.dart';
import '../poi_rating_label.dart';

/// 探索 POI 卡片：系統 surface + 類型 label + name/address/rating + heart toggle。
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
    final poiType = mapGooglePrimaryTypeToPoiType(poi.category);
    final categoryLabel =
        poiCategoryLabel(poi.category) ?? kPoiTypeLabels[poiType] ?? 'POI';
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      key: ValueKey('poi-card-${poi.placeId}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Container(
                height: 64,
                color: theme.colorScheme.surfaceContainerHigh,
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  key: ValueKey('poi-heart-${poi.placeId}'),
                  tooltip: isSaved ? '已收藏 · 點擊取消' : '加入收藏',
                  onPressed: isSaving ? null : onToggleFavorite,
                  icon: Icon(
                    isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (onAddToTrip != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    key: ValueKey('poi-add-to-trip-${poi.placeId}'),
                    tooltip: '加入行程',
                    icon: const Icon(Icons.add_location_alt_outlined),
                    onPressed: onAddToTrip,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(TpSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(poi.name, style: theme.textTheme.titleMedium),
                if (poi.address != null && poi.address!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      poi.address!,
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
        ],
      ),
    );
  }
}
