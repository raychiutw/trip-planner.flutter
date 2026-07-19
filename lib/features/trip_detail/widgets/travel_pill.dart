import 'package:flutter/material.dart';

import '../../../models/entry.dart';
import '../../../models/segment.dart';

/// 站間移動 pill：中性描邊、Tripline accent icon + 分鐘數（tabular）。
class TravelPill extends StatelessWidget {
  const TravelPill({
    super.key,
    this.travel,
    this.segment,
    this.missing = false,
    this.statusLabel,
  }) : assert(travel != null || segment != null || missing);

  final Travel? travel;
  final TripSegment? segment;
  final bool missing;
  final String? statusLabel;

  /// 移動方式 → icon；未知 type 用通用路線 icon。
  static IconData iconForType(String type) {
    switch (type) {
      case 'walk':
      case 'walking':
        return Icons.directions_walk;
      case 'car':
      case 'drive':
      case 'driving':
        return Icons.directions_car;
      case 'taxi':
        return Icons.local_taxi;
      case 'bus':
        return Icons.directions_bus;
      case 'train':
      case 'metro':
      case 'hsr':
        return Icons.train;
      case 'monorail':
      case 'tram':
        return Icons.tram;
      case 'flight':
      case 'plane':
        return Icons.flight;
      case 'ferry':
      case 'boat':
        return Icons.directions_boat;
      case 'bike':
      case 'cycle':
        return Icons.directions_bike;
      default:
        return Icons.route;
    }
  }

  /// 距離公尺 → 顯示字串：>=1000m 整數 km；<1000m 顯示 M m。
  static String _formatDistance(int distanceM) {
    if (distanceM >= 1000) {
      return '${distanceM ~/ 1000} km';
    }
    return '$distanceM m';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final noTravel = segment?.noTravel ?? travel?.sameplace ?? false;

    if (noTravel) {
      return Container(
        key: const ValueKey('travel-no-travel'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 17,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '不需計算路程',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String label;
    final mode = segment?.mode ?? travel?.type;
    final submode = segment?.submode ?? travel?.submode;
    final isStale = segment?.isStale == true;
    final hasStatus = statusLabel != null;
    final min = hasStatus || isStale ? null : segment?.min ?? travel?.min;
    final distanceM = hasStatus || isStale
        ? null
        : segment?.distanceM ?? travel?.distanceM;
    final desc = travel?.desc;
    final method = travelMethodLabel(mode, submode);
    final showMethod = mode == 'transit' && submode?.isNotEmpty == true;
    final hasMin = min != null;
    final hasDist = distanceM != null;

    if (hasStatus) {
      label = statusLabel!;
    } else if (hasMin && hasDist) {
      label =
          '${showMethod ? '$method · ' : ''}$min 分鐘 · '
          '${_formatDistance(distanceM)}';
    } else if (hasMin) {
      label = '${showMethod ? '$method · ' : ''}$min 分鐘';
    } else if (hasDist) {
      label = '${showMethod ? '$method · ' : ''}${_formatDistance(distanceM)}';
    } else if (isStale) {
      label = showMethod ? '$method · 車程待更新' : '車程待更新';
    } else if (showMethod) {
      label = desc?.trim().isNotEmpty == true ? '$method · $desc' : method;
    } else if (missing) {
      label = '尚未設定交通';
    } else {
      label = desc ?? '移動';
    }

    return Container(
      key: isStale
          ? const ValueKey('travel-stale')
          : const ValueKey('travel-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconForType(submode ?? mode ?? ''),
            size: 17,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
