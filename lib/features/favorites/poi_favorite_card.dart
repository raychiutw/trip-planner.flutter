import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../models/poi_favorite.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'poi_rating_label.dart';

/// 收藏 POI 卡片：共用 Tripline accent + rating/note/usages + 取消收藏 heart。
class PoiFavoriteCard extends StatelessWidget {
  const PoiFavoriteCard({
    super.key,
    required this.favorite,
    required this.onRemove,
    this.onAddToTrip,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
    this.onSelectedChanged,
    this.grouped = false,
    this.matchQuery = '',
  });

  final PoiFavorite favorite;
  final VoidCallback onRemove;
  final VoidCallback? onAddToTrip;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;
  final ValueChanged<bool>? onSelectedChanged;
  final bool grouped;
  final String matchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;

    return GestureDetector(
      onLongPress: onLongPress ?? onAddToTrip,
      child: AnimatedContainer(
        key: ValueKey('favorite-card-${favorite.id}'),
        duration: TpMotion.resolve(context, TpMotion.fast),
        padding: const EdgeInsets.all(TpSpacing.s3),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : grouped
              ? Colors.transparent
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: grouped
              ? BorderRadius.zero
              : BorderRadius.circular(TpRadius.lg),
          border: Border.all(
            color: !grouped && selected
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectionMode && onSelectedChanged != null) ...[
              Checkbox(
                key: ValueKey('favorite-select-${favorite.id}'),
                value: selected,
                onChanged: (value) => onSelectedChanged!(value ?? false),
              ),
              const SizedBox(width: TpSpacing.s2),
            ],
            Container(
              key: ValueKey('favorite-leading-${favorite.id}'),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tones.accentBg,
                borderRadius: BorderRadius.circular(TpRadius.md),
              ),
              child: Icon(
                CupertinoIcons.location_solid,
                size: 20,
                color: tones.accentDeep,
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FavoriteHighlightedText(
                    textKey: ValueKey('favorite-title-${favorite.id}'),
                    text: favorite.displayName,
                    matchQuery: matchQuery,
                    primary: true,
                    maxLines: 1,
                  ),
                  if (favorite.poiAddress != null &&
                      favorite.poiAddress!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: TpSpacing.s1),
                      child: _FavoriteHighlightedText(
                        textKey: ValueKey('favorite-address-${favorite.id}'),
                        text: favorite.poiAddress!,
                        matchQuery: matchQuery,
                        maxLines: 1,
                      ),
                    ),
                  if (favorite.poiRating != null)
                    Padding(
                      padding: const EdgeInsets.only(top: TpSpacing.s1),
                      child: PoiRatingLabel(rating: favorite.poiRating!),
                    ),
                  if (favorite.note != null && favorite.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: TpSpacing.s1),
                      child: _FavoriteHighlightedText(
                        textKey: ValueKey('favorite-note-${favorite.id}'),
                        text: favorite.note!,
                        matchQuery: matchQuery,
                        maxLines: 2,
                      ),
                    ),
                  if (favorite.usages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: TpSpacing.s1),
                      child: Text(
                        '用於 ${favorite.usages.length} 個行程',
                        style: TextStyle(fontSize: 11, color: tones.accentDeep),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('favorite-remove-${favorite.id}'),
              tooltip: '取消收藏',
              icon: Icon(CupertinoIcons.heart_fill, color: tones.accentDeep),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteHighlightedText extends StatelessWidget {
  const _FavoriteHighlightedText({
    required this.textKey,
    required this.text,
    required this.matchQuery,
    required this.maxLines,
    this.primary = false,
  });

  final Key textKey;
  final String text;
  final String matchQuery;
  final int maxLines;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = primary
        ? theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.4,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    final query = matchQuery.trim();
    final matchIndex = query.isEmpty
        ? -1
        : text.toLowerCase().indexOf(query.toLowerCase());
    if (matchIndex < 0) {
      return Text(
        text,
        key: textKey,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final matchEnd = matchIndex + query.length;
    return Text.rich(
      TextSpan(
        style: primary
            ? baseStyle?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              )
            : baseStyle,
        children: [
          if (matchIndex > 0) TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchEnd),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (matchEnd < text.length) TextSpan(text: text.substring(matchEnd)),
        ],
      ),
      key: textKey,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
