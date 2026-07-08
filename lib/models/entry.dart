/// Timeline entry models（`GET /trips/:id/days` timeline 內嵌結構）。
library;

/// 移動段資訊（server 由 trip_segments 組裝）。
class Travel {
  const Travel({
    required this.type,
    this.desc,
    this.min,
    this.distanceM,
    this.source,
  });

  final String type;
  final String? desc;
  final int? min;
  final int? distanceM;
  final String? source;

  factory Travel.fromJson(Map<String, dynamic> json) {
    return Travel(
      type: json['type'] as String,
      desc: json['desc'] as String?,
      min: (json['min'] as num?)?.toInt(),
      distanceM: (json['distanceM'] as num?)?.toInt(),
      source: json['source'] as String?,
    );
  }
}

/// Entry 掛載的 POI 資訊（trip_entry_pois JOIN pois；除 poiId 外全 nullable）。
class EntryPoiInfo {
  const EntryPoiInfo({
    required this.poiId,
    this.name,
    this.lat,
    this.lng,
    this.type,
    this.category,
    this.hours,
    this.rating,
    this.price,
    this.note,
    this.sortOrder,
  });

  final int poiId;
  final String? name;
  final double? lat;
  final double? lng;

  /// poi_type enum 字串（hotel/restaurant/shopping/parking/attraction/transport/activity/other）。
  final String? type;
  final String? category;
  final String? hours;
  final double? rating;
  final String? price;
  final String? note;
  final int? sortOrder;

  factory EntryPoiInfo.fromJson(Map<String, dynamic> json) {
    return EntryPoiInfo(
      poiId: (json['poiId'] as num).toInt(),
      name: json['name'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      type: json['type'] as String?,
      category: json['category'] as String?,
      hours: json['hours'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      price: json['price'] as String?,
      note: json['note'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
    );
  }
}

/// 時間軸停留點（trip_entries）。
class TimelineEntry {
  const TimelineEntry({
    required this.id,
    this.dayId,
    required this.sortOrder,
    this.time,
    this.startTime,
    this.endTime,
    required this.title,
    this.description,
    this.note,
    this.source,
    required this.version,
    this.entryPoisVersion,
    this.travel,
    this.master,
    this.alternates = const [],
  });

  final int id;
  final int? dayId;
  final int sortOrder;
  final String? time;

  /// `"HH:MM"` 字串，顯示層再 parse。
  final String? startTime;
  final String? endTime;
  final String title;
  final String? description;
  final String? note;
  final String? source;
  final int version;
  final String? entryPoisVersion;
  final Travel? travel;
  final EntryPoiInfo? master;
  final List<EntryPoiInfo> alternates;

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    return TimelineEntry(
      id: (json['id'] as num).toInt(),
      dayId: (json['dayId'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      time: json['time'] as String?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      note: json['note'] as String?,
      source: json['source'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 0,
      entryPoisVersion: json['entryPoisVersion'] as String?,
      travel: json['travel'] == null
          ? null
          : Travel.fromJson(json['travel'] as Map<String, dynamic>),
      master: json['master'] == null
          ? null
          : EntryPoiInfo.fromJson(json['master'] as Map<String, dynamic>),
      alternates: (json['alternates'] as List<dynamic>? ?? [])
          .map(
            (alternateJson) =>
                EntryPoiInfo.fromJson(alternateJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// `trip_entry_pois` 變更後的 OCC token。
class EntryPoisMutationResult {
  const EntryPoisMutationResult({
    required this.entryId,
    required this.poiId,
    this.sortOrder,
    this.entryPoisVersion,
  });

  final int entryId;
  final int poiId;
  final int? sortOrder;
  final String? entryPoisVersion;

  factory EntryPoisMutationResult.fromJson(Map<String, dynamic> json) {
    return EntryPoisMutationResult(
      entryId: (json['entryId'] as num).toInt(),
      poiId: (json['poiId'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      entryPoisVersion: json['entryPoisVersion'] as String?,
    );
  }
}
