/// 行程 models（wire format 為 camelCase，見 docs/discovery/models.md）。
library;

/// `GET /my-trips` 清單項目。
class TripSummary {
  const TripSummary({
    required this.tripId,
    required this.name,
    this.title,
    this.totalDays,
  });

  final String tripId;
  final String name;
  final String? title;
  final int? totalDays;

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      tripId: json['tripId'] as String,
      name: json['name'] as String,
      title: json['title'] as String?,
      totalDays: (json['totalDays'] as num?)?.toInt(),
    );
  }
}

/// 行程目的地（trip_destinations JOIN）。
class TripDestination {
  const TripDestination({
    this.destOrder,
    required this.name,
    this.lat,
    this.lng,
  });

  final int? destOrder;
  final String name;
  final double? lat;
  final double? lng;

  factory TripDestination.fromJson(Map<String, dynamic> json) {
    return TripDestination(
      destOrder: (json['destOrder'] as num?)?.toInt(),
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

/// `GET /trips`（list item）與 `GET /trips/:id`（detail）共用，寬鬆 nullable。
class Trip {
  const Trip({
    required this.id,
    required this.name,
    this.owner,
    this.ownerDisplayName,
    this.title,
    this.description,
    this.countries,
    this.published = false,
    this.lang,
    this.dayCount,
    this.startDate,
    this.endDate,
    this.memberCount,
    this.destinations = const [],
  });

  /// 來源 json['tripId'] ?? json['id']（API 同時回兩個 key）。
  final String id;
  final String name;
  final String? owner;
  final String? ownerDisplayName;
  final String? title;
  final String? description;
  final String? countries;
  final bool published;
  final String? lang;
  final int? dayCount;
  final String? startDate;
  final String? endDate;
  final int? memberCount;
  final List<TripDestination> destinations;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: (json['tripId'] ?? json['id']) as String,
      name: json['name'] as String,
      owner: json['owner'] as String?,
      ownerDisplayName: json['ownerDisplayName'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      countries: json['countries'] as String?,
      published: json['published'] == 1 || json['published'] == true,
      lang: json['lang'] as String?,
      dayCount: (json['dayCount'] as num?)?.toInt(),
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt(),
      destinations: (json['destinations'] as List<dynamic>? ?? [])
          .map((destinationJson) =>
              TripDestination.fromJson(destinationJson as Map<String, dynamic>))
          .toList(),
    );
  }
}
