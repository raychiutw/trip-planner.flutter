/// POI availability health summary for a trip.
library;

enum TripPoiHealthStatus { closed, missing, unknown }

TripPoiHealthStatus parseTripPoiHealthStatus(String? value) =>
    switch (value?.toLowerCase()) {
      'closed' => TripPoiHealthStatus.closed,
      'missing' => TripPoiHealthStatus.missing,
      _ => TripPoiHealthStatus.unknown,
    };

class TripPoiHealthItem {
  const TripPoiHealthItem({
    required this.poiId,
    required this.poiName,
    required this.status,
    this.reason,
  });

  final int poiId;
  final String poiName;
  final TripPoiHealthStatus status;
  final String? reason;

  factory TripPoiHealthItem.fromJson(Map<String, dynamic> json) =>
      TripPoiHealthItem(
        poiId: _intValue(json['poiId'] ?? json['poi_id']),
        poiName: _stringValue(json['poiName'] ?? json['poi_name']),
        status: parseTripPoiHealthStatus(json['status']?.toString()),
        reason: _nullableString(json['reason']),
      );
}

class TripPoiHealthReport {
  const TripPoiHealthReport({
    required this.version,
    required this.closed,
    required this.missing,
    this.items = const [],
  });

  final int version;
  final int closed;
  final int missing;
  final List<TripPoiHealthItem> items;

  bool get hasIssues => closed > 0 || missing > 0 || items.isNotEmpty;

  factory TripPoiHealthReport.fromJson(Map<String, dynamic> json) =>
      TripPoiHealthReport(
        version: _intValue(json['version']),
        closed: _intValue(json['closed']),
        missing: _intValue(json['missing']),
        items: _items(json['items']),
      );
}

List<TripPoiHealthItem> _items(Object? value) {
  if (value is! List) return const [];
  final items = <TripPoiHealthItem>[];
  for (final item in value) {
    if (item is Map<String, dynamic>) {
      items.add(TripPoiHealthItem.fromJson(item));
    } else if (item is Map) {
      items.add(TripPoiHealthItem.fromJson(Map<String, dynamic>.from(item)));
    }
  }
  return items;
}

String _stringValue(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final stringValue = value?.toString();
  if (stringValue == null || stringValue.trim().isEmpty) return null;
  return stringValue;
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
