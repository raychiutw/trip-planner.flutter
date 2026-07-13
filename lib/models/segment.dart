/// 交通段（trip_segments）;GET /trips/:id/segments item。
/// 顯示用的 [Travel]（entry.travel）不含 id/version,編輯交通需用本 model。
library;

class TripSegment {
  const TripSegment({
    required this.id,
    this.fromEntryId,
    this.toEntryId,
    required this.mode,
    this.submode,
    this.min,
    this.distanceM,
    this.source,
    this.computedAt,
    this.updatedAt,
    this.noTravel = false,
    required this.version,
  });

  final int id;
  final int? fromEntryId;
  final int? toEntryId;

  /// driving / walking / transit。
  final String mode;

  /// transit 細分：monorail / bus / metro / train / hsr / 自訂名稱。
  final String? submode;
  final int? min;
  final int? distanceM;

  /// google / manual。
  final String? source;
  final int? computedAt;
  final int? updatedAt;

  /// 此相鄰地點不需計算路程。
  final bool noTravel;

  /// OCC token（PATCH 帶 expectedVersion）。
  final int version;

  factory TripSegment.fromJson(Map<String, dynamic> json) {
    return TripSegment(
      id: (json['id'] as num).toInt(),
      fromEntryId: ((json['fromEntryId'] ?? json['from_entry_id']) as num?)
          ?.toInt(),
      toEntryId: ((json['toEntryId'] ?? json['to_entry_id']) as num?)?.toInt(),
      mode: json['mode'] as String? ?? 'driving',
      submode: json['submode'] as String?,
      min: (json['min'] as num?)?.toInt(),
      distanceM: ((json['distanceM'] ?? json['distance_m']) as num?)?.toInt(),
      source: json['source'] as String?,
      computedAt: ((json['computedAt'] ?? json['computed_at']) as num?)
          ?.toInt(),
      updatedAt: ((json['updatedAt'] ?? json['updated_at']) as num?)?.toInt(),
      noTravel: _jsonBool(json['noTravel'] ?? json['no_travel']),
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }
}

bool _jsonBool(Object? value) => value == true || value == 1;

/// 交通編輯器與顯示共用的 server 契約。
class TravelMethodOption {
  const TravelMethodOption({
    required this.key,
    required this.mode,
    required this.label,
    required this.automatic,
    this.submode,
  });

  final String key;
  final String mode;
  final String? submode;
  final String label;
  final bool automatic;
}

const travelMethodOptions = <TravelMethodOption>[
  TravelMethodOption(
    key: 'driving',
    mode: 'driving',
    label: '駕車',
    automatic: true,
  ),
  TravelMethodOption(
    key: 'walking',
    mode: 'walking',
    label: '步行',
    automatic: true,
  ),
  TravelMethodOption(
    key: 'monorail',
    mode: 'transit',
    submode: 'monorail',
    label: '單軌',
    automatic: true,
  ),
  TravelMethodOption(
    key: 'bus',
    mode: 'transit',
    submode: 'bus',
    label: '公車',
    automatic: true,
  ),
  TravelMethodOption(
    key: 'metro',
    mode: 'transit',
    submode: 'metro',
    label: '地鐵',
    automatic: true,
  ),
  TravelMethodOption(
    key: 'train',
    mode: 'transit',
    submode: 'train',
    label: '火車',
    automatic: true,
  ),
  TravelMethodOption(
    key: 'hsr',
    mode: 'transit',
    submode: 'hsr',
    label: '高鐵',
    automatic: true,
  ),
  TravelMethodOption(
    key: 'other',
    mode: 'transit',
    label: '其他',
    automatic: false,
  ),
];

String travelMethodKey(String? mode, String? submode) {
  return switch (mode) {
    'driving' || 'drive' || 'car' || 'taxi' => 'driving',
    'walking' || 'walk' => 'walking',
    'monorail' => 'monorail',
    'bus' => 'bus',
    'train' when submode == null => 'train',
    'transit'
        when const {
          'monorail',
          'bus',
          'metro',
          'train',
          'hsr',
        }.contains(submode) =>
      submode!,
    'transit' => 'other',
    _ => 'driving',
  };
}

String travelMethodLabel(String? mode, String? submode) {
  final legacyLabel = switch (mode) {
    'ferry' || 'boat' => '渡輪',
    'flight' || 'plane' => '飛機',
    'bike' || 'cycle' => '自行車',
    _ => null,
  };
  if (legacyLabel != null) return legacyLabel;
  final key = travelMethodKey(mode, submode);
  if (key == 'other') {
    final custom = submode?.trim();
    return custom == null || custom.isEmpty ? '大眾運輸' : custom;
  }
  return travelMethodOptions.firstWhere((option) => option.key == key).label;
}
