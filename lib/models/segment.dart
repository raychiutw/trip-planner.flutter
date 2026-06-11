/// 交通段（trip_segments）;GET /trips/:id/segments item。
/// 顯示用的 [Travel]（entry.travel）不含 id/version,編輯交通需用本 model。
library;

class TripSegment {
  const TripSegment({
    required this.id,
    this.fromEntryId,
    this.toEntryId,
    required this.mode,
    this.min,
    this.distanceM,
    this.source,
    required this.version,
  });

  final int id;
  final int? fromEntryId;
  final int? toEntryId;

  /// driving / walking / transit。
  final String mode;
  final int? min;
  final int? distanceM;

  /// google / manual。
  final String? source;

  /// OCC token（PATCH 帶 expectedVersion）。
  final int version;

  factory TripSegment.fromJson(Map<String, dynamic> json) {
    return TripSegment(
      id: (json['id'] as num).toInt(),
      fromEntryId: (json['fromEntryId'] as num?)?.toInt(),
      toEntryId: (json['toEntryId'] as num?)?.toInt(),
      mode: json['mode'] as String? ?? 'driving',
      min: (json['min'] as num?)?.toInt(),
      distanceM: (json['distanceM'] as num?)?.toInt(),
      source: json['source'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }
}
