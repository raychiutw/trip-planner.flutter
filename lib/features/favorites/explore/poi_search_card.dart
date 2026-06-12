import 'package:flutter/material.dart';

import '../../../models/poi_search_result.dart';
import '../../../models/poi_type.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/poi_tone.dart';
import '../../../theme/tokens.dart';
import '../poi_rating_label.dart';

/// 探索 POI 卡片：cover tone 漸層 + 類型 label + name/address/rating + heart toggle。
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Container(height: 64, color: tone.subtle),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  key: ValueKey('poi-heart-${poi.placeId}'),
                  tooltip: isSaved ? '已收藏 · 點擊取消' : '加入收藏',
                  onPressed: isSaving ? null : onToggleFavorite,
                  icon: Icon(
                    isSaved ? Icons.favorite : Icons.favorite_border,
                    color: tones.pink,
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kPoiTypeLabels[poiType] ?? 'POI',
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
                  const Spacer(),
                  if (poi.rating != null) PoiRatingLabel(rating: poi.rating!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
