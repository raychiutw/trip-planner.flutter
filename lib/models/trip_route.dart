/// Route geometry and travel metrics returned by the map route endpoint.
library;

class TripRoutePoint {
  const TripRoutePoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory TripRoutePoint.fromJson(Object? value) {
    if (value is List && value.length >= 2) {
      return TripRoutePoint(
        lat: _doubleValue(value[0]),
        lng: _doubleValue(value[1]),
      );
    }
    if (value is Map<String, dynamic>) {
      return TripRoutePoint(
        lat: _doubleValue(value['lat']),
        lng: _doubleValue(value['lng']),
      );
    }
    if (value is Map) {
      return TripRoutePoint.fromJson(Map<String, dynamic>.from(value));
    }
    return const TripRoutePoint(lat: 0, lng: 0);
  }
}

class TripRouteResult {
  const TripRouteResult({
    required this.polyline,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  final List<TripRoutePoint> polyline;
  final int? durationSeconds;
  final int distanceMeters;

  factory TripRouteResult.fromJson(Map<String, dynamic> json) =>
      TripRouteResult(
        polyline: _polyline(json['polyline']),
        durationSeconds: _nullableInt(json['duration']),
        distanceMeters: _intValue(json['distance']),
      );
}

List<TripRoutePoint> _polyline(Object? value) {
  if (value is! List) return const [];
  return [
    for (final point in value)
      if (point is List || point is Map) TripRoutePoint.fromJson(point),
  ];
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _intValue(Object? value) => _nullableInt(value) ?? 0;

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
