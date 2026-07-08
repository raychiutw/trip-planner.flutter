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
      id: _readRequiredInt(json, 'id'),
      dayNum: _readRequiredInt(json, 'dayNum', snakeKey: 'day_num'),
      date: _readString(json, 'date'),
      dayOfWeek: _readString(json, 'dayOfWeek', snakeKey: 'day_of_week'),
      label: _readString(json, 'label'),
      title: _readString(json, 'title'),
      version: _readInt(json, 'version') ?? 0,
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

/// DELETE /trips/:id/days/:num 回傳的影響摘要。
class TripDayDeleteResult {
  const TripDayDeleteResult({
    required this.ok,
    required this.removedEntryCount,
  });

  final bool ok;
  final int removedEntryCount;

  factory TripDayDeleteResult.fromJson(Map<String, dynamic> json) {
    return TripDayDeleteResult(
      ok: json['ok'] == true,
      removedEntryCount: _readInt(json, 'removedEntryCount') ?? 0,
    );
  }
}

/// POST /trips/:id/days/shift 回傳的新日期範圍摘要。
class TripDaysShiftResult {
  const TripDaysShiftResult({
    required this.ok,
    required this.newStartDate,
    this.newEndDate,
    required this.daysShifted,
  });

  final bool ok;
  final String newStartDate;
  final String? newEndDate;
  final int daysShifted;

  factory TripDaysShiftResult.fromJson(Map<String, dynamic> json) {
    return TripDaysShiftResult(
      ok: json['ok'] == true,
      newStartDate: _readString(json, 'newStartDate') ?? '',
      newEndDate: _readString(json, 'newEndDate'),
      daysShifted: _readInt(json, 'daysShifted') ?? 0,
    );
  }
}

Object? _readField(Map<String, dynamic> json, String key, {String? snakeKey}) {
  if (json.containsKey(key)) return json[key];
  if (snakeKey != null && json.containsKey(snakeKey)) return json[snakeKey];
  return null;
}

String? _readString(Map<String, dynamic> json, String key, {String? snakeKey}) {
  return _readField(json, key, snakeKey: snakeKey) as String?;
}

int? _readInt(Map<String, dynamic> json, String key, {String? snakeKey}) {
  return (_readField(json, key, snakeKey: snakeKey) as num?)?.toInt();
}

int _readRequiredInt(
  Map<String, dynamic> json,
  String key, {
  String? snakeKey,
}) {
  return _readInt(json, key, snakeKey: snakeKey)!;
}
