import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'map_adapter.dart';

@immutable
class TripMapClusterItem {
  const TripMapClusterItem(this.members, this.point);

  final List<TripMapMarker> members;
  final TripMapPoint point;

  List<String> get memberIds => [for (final member in members) member.id];
  bool get isCluster => members.length > 1;
  String get glyph =>
      isCluster ? '${members.length}' : members.single.glyph ?? '';
  String get id =>
      isCluster ? 'cluster:${memberIds.join('|')}' : members.single.id;
}

class TripMapClusterProjector {
  const TripMapClusterProjector({this.logicalPixelRadius = 12});

  final double logicalPixelRadius;

  List<TripMapClusterItem> project({
    required List<TripMapMarker> markers,
    required double zoom,
  }) {
    final sorted = [...markers]..sort((a, b) => a.id.compareTo(b.id));
    final groups = <_ProjectedGroup>[];
    final singles = <TripMapClusterItem>[];

    for (final marker in sorted) {
      if (!marker.clusterable) {
        singles.add(TripMapClusterItem([marker], marker.point));
        continue;
      }
      final projected = _project(marker.point, zoom);
      _ProjectedGroup? nearest;
      for (final group in groups) {
        if ((group.anchor - projected).distance <= logicalPixelRadius) {
          nearest = group;
          break;
        }
      }
      if (nearest == null) {
        groups.add(_ProjectedGroup(projected, [marker]));
      } else {
        nearest.members.add(marker);
      }
    }

    return [
      ...groups.map(
        (group) => TripMapClusterItem(group.members, _center(group.members)),
      ),
      ...singles,
    ]..sort((a, b) => a.id.compareTo(b.id));
  }

  Offset _project(TripMapPoint point, double zoom) {
    final scale = 256 * math.pow(2, zoom);
    final latitude = point.latitude.clamp(-85.05112878, 85.05112878);
    final sinLatitude = math.sin(latitude * math.pi / 180);
    return Offset(
      ((point.longitude + 180) / 360) * scale,
      (0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) *
          scale,
    );
  }

  TripMapPoint _center(List<TripMapMarker> markers) => TripMapPoint(
    markers.map((marker) => marker.point.latitude).reduce((a, b) => a + b) /
        markers.length,
    markers.map((marker) => marker.point.longitude).reduce((a, b) => a + b) /
        markers.length,
  );
}

class _ProjectedGroup {
  _ProjectedGroup(this.anchor, this.members);

  final Offset anchor;
  final List<TripMapMarker> members;
}
