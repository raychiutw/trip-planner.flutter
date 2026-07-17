import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_content_surface.dart';

/// TripSummary 顯示名稱：title 優先（人類可讀），空值退回 name。
extension TripSummaryDisplay on TripSummary {
  String get displayTitle {
    final trimmedTitle = title?.trim();
    if (trimmedTitle == null || trimmedTitle.isEmpty) return name;
    return trimmedTitle;
  }
}

/// 行程清單卡片：緊湊的目的地圖示 + eyebrow（{countries} · N 天）+ 標題
/// + 建立者列 + 日期範圍 + chevron。內容層使用實色 surface，不使用玻璃材質。
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    this.currentUserId,
    this.onTap,
    this.onLongPress,
    this.onMorePressed,
  });

  final TripSummary trip;

  /// 當前登入使用者 id；用於判斷是否「由你建立」。null 時一律當作他人行程。
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMorePressed;

  /// eyebrow 文字：「{countries} · {N} 天」，任一缺漏只顯示有值的部分；皆缺則 null。
  String? get _eyebrowText {
    final parts = <String>[
      if (trip.countries != null && trip.countries!.trim().isNotEmpty)
        trip.countries!.trim(),
      if (trip.totalDays != null) '${trip.totalDays} 天',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// 日期範圍「startDate – endDate」；任一缺漏則 null（不顯示）。
  String? get _dateRangeText {
    final start = trip.startDate;
    final end = trip.endDate;
    if (start == null || start.isEmpty || end == null || end.isEmpty) {
      return null;
    }
    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverBackground = theme.colorScheme.surfaceContainerHigh;
    final coverForeground = theme.colorScheme.onSurfaceVariant;
    final eyebrowText = _eyebrowText;
    final dateRangeText = _dateRangeText;

    return TpContentSurface(
      semanticLabel: trip.displayTitle,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(TpSpacing.s3),
      child: Row(
        children: [
          Container(
            key: ValueKey('trip-card-cover-${trip.tripId}'),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: coverBackground,
              borderRadius: BorderRadius.circular(TpRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.map_pin_ellipse,
              color: coverForeground,
              size: 24,
            ),
          ),
          const SizedBox(width: TpSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrowText != null) ...[
                  Text(
                    eyebrowText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
                if (dateRangeText != null) ...[
                  const SizedBox(height: TpSpacing.s1),
                  Text(
                    dateRangeText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                _buildOwnerRow(theme, coverBackground, coverForeground),
              ],
            ),
          ),
          const SizedBox(width: TpSpacing.s2),
          if (onMorePressed != null)
            IconButton(
              key: ValueKey('trip-card-more-${trip.tripId}'),
              tooltip: '行程選項',
              onPressed: onMorePressed,
              icon: const Icon(CupertinoIcons.ellipsis),
            )
          else
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }

  /// 建立者列：自己建立 → 「由你建立」；他人 → 首字 avatar + ownerDisplayName。
  /// ownerUserId / ownerDisplayName 皆缺時不顯示（回傳零高度）。
  Widget _buildOwnerRow(
    ThemeData theme,
    Color avatarBackground,
    Color avatarForeground,
  ) {
    final isMine = currentUserId != null && trip.ownerUserId == currentUserId;
    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(top: TpSpacing.s2),
        child: Text(
          '由你建立',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final displayName = trip.ownerDisplayName?.trim();
    if (displayName == null || displayName.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: TpSpacing.s2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: avatarBackground,
            child: Text(
              displayName.characters.first.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: avatarForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: TpSpacing.s2),
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
