/// `/api/route` 回應:單段行車路線(已由後端解碼的道路折線)。
///
/// 契約:`{ polyline: [[lat,lng],...], duration: sec|null, distance: m }`。
library;

/// 折線上的一個點(純 lat/lng,不耦合任何地圖套件)。
typedef RoutePoint = ({double lat, double lng});

class RouteResult {
  const RouteResult({
    required this.polyline,
    required this.distanceM,
    this.durationSec,
  });

  /// 道路折線點(lat/lng);後端已解碼。失敗時上層拿到 null(不會是空 RouteResult)。
  final List<RoutePoint> polyline;

  /// 距離(公尺);缺漏 → 0。
  final int distanceM;

  /// 時間(秒);可為 null(對齊契約)。
  final int? durationSec;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final rawPolyline = (json['polyline'] as List?) ?? const [];
    return RouteResult(
      polyline: [
        for (final point in rawPolyline)
          if (point is List && point.length >= 2)
            (lat: (point[0] as num).toDouble(), lng: (point[1] as num).toDouble()),
      ],
      distanceM: (json['distance'] as num?)?.toInt() ?? 0,
      durationSec: (json['duration'] as num?)?.toInt(),
    );
  }
}
