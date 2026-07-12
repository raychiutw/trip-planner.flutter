import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../models/poi_favorite.dart';
import '../../theme/app_theme.dart';
import '../../theme/poi_tone.dart';
import '../../theme/tokens.dart';
import 'poi_rating_label.dart';

/// 收藏 POI 卡片：poiType tone 色階 + rating/note/usages；右側只保留加入行程，
/// 取消收藏改用左滑，避免同列三個互相競爭的操作。
class PoiFavoriteCard extends StatelessWidget {
  const PoiFavoriteCard({
    super.key,
    required this.favorite,
    required this.onRemove,
    this.onAddToTrip,
    this.onTap,
  });

  final PoiFavorite favorite;
  final VoidCallback onRemove;
  final VoidCallback? onAddToTrip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final tone = resolvePoiTone(tones, favorite.poiType);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final note = favorite.note
        ?.replaceFirst(RegExp(r'\s*\(req\s*#\d+\)\s*$'), '')
        .trim();

    return Dismissible(
      key: ValueKey('favorite-swipe-${favorite.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      background: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(TpRadius.md),
        ),
        padding: const EdgeInsets.only(right: TpSpacing.s4),
        alignment: Alignment.centerRight,
        child: Icon(
          CupertinoIcons.heart_slash,
          color: theme.colorScheme.onPrimary,
        ),
      ),
      child: InkWell(
        key: ValueKey('favorite-card-${favorite.id}'),
        borderRadius: BorderRadius.circular(TpRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(TpSpacing.s3),
          decoration: BoxDecoration(
            color: tone.subtle,
            borderRadius: BorderRadius.circular(TpRadius.md),
            border: Border.all(color: tone.bg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(TpRadius.md),
                ),
                child: Icon(
                  CupertinoIcons.location_solid,
                  size: 20,
                  color: tone.deep,
                ),
              ),
              const SizedBox(width: TpSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    if (favorite.poiRating != null)
                      Padding(
                        padding: const EdgeInsets.only(top: TpSpacing.s1),
                        child: PoiRatingLabel(rating: favorite.poiRating!),
                      ),
                    if (note != null && note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: TpSpacing.s1),
                        child: Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ),
                    if (favorite.usages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: TpSpacing.s1),
                        child: Text(
                          '用於 ${favorite.usages.length} 個行程',
                          style: TextStyle(fontSize: 12, color: tone.deep),
                        ),
                      ),
                  ],
                ),
              ),
              if (onAddToTrip != null)
                IconButton(
                  key: ValueKey('favorite-add-to-trip-${favorite.id}'),
                  tooltip: '加入行程',
                  icon: const Icon(Icons.add_location_alt_outlined),
                  onPressed: onAddToTrip,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
