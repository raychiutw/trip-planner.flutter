/// Result from refreshing a POI with Google Place Details.
library;

enum PoiEnrichmentStatus { active, closed, missing, unknown }

PoiEnrichmentStatus parsePoiEnrichmentStatus(String? value) =>
    switch (value?.toLowerCase()) {
      'active' => PoiEnrichmentStatus.active,
      'closed' => PoiEnrichmentStatus.closed,
      'missing' => PoiEnrichmentStatus.missing,
      _ => PoiEnrichmentStatus.unknown,
    };

class PoiEnrichmentResult {
  const PoiEnrichmentResult({
    required this.poiId,
    required this.name,
    required this.placeId,
    required this.status,
    this.statusReason,
    this.rating,
    this.refreshedAt,
  });

  final int poiId;
  final String name;
  final String placeId;
  final PoiEnrichmentStatus status;
  final String? statusReason;
  final double? rating;
  final String? refreshedAt;

  factory PoiEnrichmentResult.fromJson(Map<String, dynamic> json) =>
      PoiEnrichmentResult(
        poiId: _intValue(json['poiId'] ?? json['poi_id']),
        name: _stringValue(json['name']),
        placeId: _stringValue(json['placeId'] ?? json['place_id']),
        status: parsePoiEnrichmentStatus(json['status']?.toString()),
        statusReason: _nullableString(
          json['statusReason'] ?? json['status_reason'],
        ),
        rating: _nullableDouble(json['rating']),
        refreshedAt: _nullableString(
          json['refreshedAt'] ?? json['refreshed_at'],
        ),
      );
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

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
