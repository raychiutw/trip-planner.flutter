/// 行程日 models（`GET /trips/:id/days?all=1` item）。
library;

import 'entry.dart';

/// 座標位置（server 合成 view，全 nullable）。
class TripLocation {
  const TripLocation({this.name, this.lat, this.lng});

  final String? name;
  final double? lat;
  final double? lng;

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    return TripLocation(
      name: json['name'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

/// 當日飯店（hotel_poi_id JOIN pois 合成，每日至多一間）。
class DayHotel {
  const DayHotel({
    required this.id,
    required this.name,
    this.checkout,
    this.note,
    this.location,
  });

  final int id;
  final String name;
  final String? checkout;
  final String? note;
  final TripLocation? location;

  factory DayHotel.fromJson(Map<String, dynamic> json) {
    return DayHotel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      checkout: json['checkout'] as String?,
      note: json['note'] as String?,
      location: json['location'] == null
          ? null
          : TripLocation.fromJson(json['location'] as Map<String, dynamic>),
    );
  }
}

/// 行程日（trip_days），內嵌 hotel 與 timeline。
class TripDay {
  const TripDay({
    required this.id,
    required this.dayNum,
    this.date,
    this.dayOfWeek,
    this.label,
    this.title,
    required this.version,
    this.hotel,
    this.timeline = const [],
  });

  final int id;
  final int dayNum;

  /// `"YYYY-MM-DD"` 字串。
  final String? date;
  final String? dayOfWeek;
  final String? label;
  final String? title;
  final int version;
  final DayHotel? hotel;
  final List<TimelineEntry> timeline;

  /// 顯示標題 fallback chain：title → label → 'Day N'。
  String get displayTitle => title ?? label ?? 'Day $dayNum';

  factory TripDay.fromJson(Map<String, dynamic> json) {
    return TripDay(
      id: (json['id'] as num).toInt(),
      dayNum: (json['dayNum'] as num).toInt(),
      date: json['date'] as String?,
      dayOfWeek: json['dayOfWeek'] as String?,
      label: json['label'] as String?,
      title: json['title'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 0,
      hotel: json['hotel'] == null
          ? null
          : DayHotel.fromJson(json['hotel'] as Map<String, dynamic>),
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .map(
            (entryJson) =>
                TimelineEntry.fromJson(entryJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
