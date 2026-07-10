import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

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

/// 行程清單卡片：cover 色塊（tone subtle 底 + deep 首字）→ eyebrow
/// （{countries} · N 天）+ 標題 + 建立者列 + 日期範圍 + chevron。
/// elevation 0 + hairline 由 CardTheme 提供。
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.tone,
    this.currentUserId,
    this.onTap,
    this.onLongPress,
  });

  final TripSummary trip;
  final TripCardTone tone;

  /// 當前登入使用者 id；用於判斷是否「由你建立」。null 時一律當作他人行程。
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
    final tones = theme.extension<TpTones>()!;
    final (coverBackground, coverForeground) = switch (tone) {
      TripCardTone.accent => (tones.accentSubtle, tones.accentDeep),
      TripCardTone.sage => (tones.sageSubtle, tones.sageDeep),
      TripCardTone.pink => (tones.pinkSubtle, tones.pinkDeep),
    };
    final eyebrowText = _eyebrowText;
    final dateRangeText = _dateRangeText;

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
                style: theme.textTheme.displaySmall?.copyWith(
                  color: coverForeground,
                ),
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
                        if (eyebrowText != null) ...[
                          Text(
                            eyebrowText,
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
                        if (dateRangeText != null) ...[
                          const SizedBox(height: TpSpacing.s1),
                          Text(
                            dateRangeText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                        _buildOwnerRow(theme, coverBackground, coverForeground),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
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

  /// 建立者列：自己建立 → 「由你建立」；他人 → 首字 avatar + ownerDisplayName。
  /// ownerUserId / ownerDisplayName 皆缺時不顯示（回傳零高度）。
  Widget _buildOwnerRow(
    ThemeData theme,
    Color avatarBackground,
    Color avatarForeground,
  ) {
    final isMine =
        currentUserId != null && trip.ownerUserId == currentUserId;
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
