import 'package:flutter/material.dart';

import '../../../models/entry.dart';
import '../../../theme/app_theme.dart';

/// 站間移動 pill：sage 描邊、透明底、type icon + 分鐘數（tabular）。
class TravelPill extends StatelessWidget {
  const TravelPill({super.key, required this.travel, this.statusLabel});

  final Travel travel;
  final String? statusLabel;

  /// 移動方式 → icon；未知 type 用通用路線 icon。
  static IconData iconForType(String type) {
    switch (type) {
      case 'walk':
        return Icons.directions_walk;
      case 'car':
      case 'drive':
        return Icons.directions_car;
      case 'taxi':
        return Icons.local_taxi;
      case 'bus':
        return Icons.directions_bus;
      case 'train':
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
    final tones = Theme.of(context).extension<TpTones>()!;

    final String label;
    final hasStatus = statusLabel != null;
    final hasMin = !hasStatus && travel.min != null;
    final hasDist = !hasStatus && travel.distanceM != null;

    if (hasStatus) {
      label = statusLabel!;
    } else if (hasMin && hasDist) {
      label = '${travel.min} 分鐘 · ${_formatDistance(travel.distanceM!)}';
    } else if (hasMin) {
      label = '${travel.min} 分鐘';
    } else if (hasDist) {
      label = _formatDistance(travel.distanceM!);
    } else {
      label = travel.desc ?? '移動';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tones.sage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForType(travel.type), size: 14, color: tones.sageDeep),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tones.sageDeep,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
