/// POI 收藏與搜尋 models。
library;

/// 一筆收藏目前在哪些 trip / day / entry 出現。
class PoiFavoriteUsage {
  const PoiFavoriteUsage({
    required this.tripId,
    required this.tripName,
    this.dayNum,
    this.dayDate,
    this.entryId,
  });

  final String tripId;
  final String tripName;
  final int? dayNum;
  final String? dayDate;
  final int? entryId;

  factory PoiFavoriteUsage.fromJson(Map<String, dynamic> json) {
    return PoiFavoriteUsage(
      tripId: json['tripId'] as String,
      tripName: json['tripName'] as String,
      dayNum: (json['dayNum'] as num?)?.toInt(),
      dayDate: json['dayDate'] as String?,
      entryId: (json['entryId'] as num?)?.toInt(),
    );
  }
}

/// `GET /poi-favorites` 回傳的跨行程 POI 收藏。
class PoiFavorite {
  const PoiFavorite({
    required this.id,
    required this.userId,
    required this.poiId,
    required this.favoritedAt,
    this.note,
    this.poiName,
    this.poiAddress,
    this.poiLat,
    this.poiLng,
    this.poiType,
    this.poiRating,
    this.usages = const [],
  });

  final int id;
  final String userId;
  final int poiId;
  final String favoritedAt;
  final String? note;
  final String? poiName;
  final String? poiAddress;
  final double? poiLat;
  final double? poiLng;
  final String? poiType;
  final double? poiRating;
  final List<PoiFavoriteUsage> usages;

  String get displayName {
    final name = poiName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'POI #$poiId';
  }

  factory PoiFavorite.fromJson(Map<String, dynamic> json) {
    return PoiFavorite(
      id: (json['id'] as num).toInt(),
      userId: json['userId'] as String,
      poiId: (json['poiId'] as num).toInt(),
      favoritedAt: json['favoritedAt'] as String,
      note: json['note'] as String?,
      poiName: json['poiName'] as String?,
      poiAddress: json['poiAddress'] as String?,
      poiLat: (json['poiLat'] as num?)?.toDouble(),
      poiLng: (json['poiLng'] as num?)?.toDouble(),
      poiType: json['poiType'] as String?,
      poiRating: (json['poiRating'] as num?)?.toDouble(),
      usages: (json['usages'] as List<dynamic>? ?? [])
          .map(
            (usageJson) =>
                PoiFavoriteUsage.fromJson(usageJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// `GET /poi-search` 的 Google Places 搜尋結果。
class PoiSearchResult {
  const PoiSearchResult({
    required this.placeId,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    this.category,
    this.country,
    this.countryName,
    this.rating,
    this.businessStatus,
  });

  final String placeId;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String? category;
  final String? country;
  final String? countryName;
  final double? rating;
  final String? businessStatus;

  factory PoiSearchResult.fromJson(Map<String, dynamic> json) {
    return PoiSearchResult(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      category: json['category'] as String?,
      country: json['country'] as String?,
      countryName: json['country_name'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      businessStatus: json['business_status'] as String?,
    );
  }
}

/// `POST /poi-favorites/:id/add-to-trip` 成功回應。
class PoiFavoriteAddToTripResult {
  const PoiFavoriteAddToTripResult({
    required this.ok,
    required this.entryId,
    required this.dayId,
    required this.sortOrder,
    required this.startTime,
    required this.endTime,
    this.note,
  });

  final bool ok;
  final int entryId;
  final int dayId;
  final int sortOrder;
  final String startTime;
  final String endTime;
  final String? note;

  factory PoiFavoriteAddToTripResult.fromJson(Map<String, dynamic> json) {
    return PoiFavoriteAddToTripResult(
      ok: json['ok'] == 1 || json['ok'] == true,
      entryId: (json['entryId'] as num).toInt(),
      dayId: (json['dayId'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      note: json['note'] as String?,
    );
  }
}

/// Google primaryType / 既有 poi_type → 後端 `pois.type` 白名單。
String mapPoiCategoryToType(String? category) {
  final normalized = category?.toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) return 'attraction';

  const whitelist = {
    'hotel',
    'restaurant',
    'shopping',
    'parking',
    'attraction',
    'transport',
    'activity',
    'other',
  };
  if (whitelist.contains(normalized)) return normalized;

  if (RegExp(
    r'hotel|lodging|hostel|motel|guest_house|resort|tourism|(?:^|_)inn(?:_|$)',
  ).hasMatch(normalized)) {
    return 'hotel';
  }
  if (normalized.contains('parking')) return 'parking';
  if (RegExp(
    r'station|airport|transit|terminal|subway|railway|taxi_stand|bus_stop|transport',
  ).hasMatch(normalized)) {
    return 'transport';
  }
  if (RegExp(
    r'amusement|theme_park|water_park|aquarium|fitness|night_?club|cinema|movie|theater|theatre|stadium|arena|bowling|karaoke|leisure|(?:^|_)(?:zoo|gym|spa|activity)(?:_|$)',
  ).hasMatch(normalized)) {
    return 'activity';
  }
  if (RegExp(
    r'restaurant|coffee|bakery|bistro|diner|eatery|izakaya|brunch|amenity|ice_cream|dessert|donut|doughnut|bagel|juice|acai|tea_house|(?:^|_)(?:cafe|bar|food|pub)(?:_|$)',
  ).hasMatch(normalized)) {
    return 'restaurant';
  }
  if (RegExp(
    r'shop|store|mall|market|supermarket|retail|boutique|grocery',
  ).hasMatch(normalized)) {
    return 'shopping';
  }
  if (RegExp(
    r'museum|gallery|temple|shrine|church|mosque|synagogue|worship|monument|landmark|tourist|historic|garden|castle|palace|memorial|park|attraction|sightseeing|scenic',
  ).hasMatch(normalized)) {
    return 'attraction';
  }
  return 'attraction';
}

/// POI 類型的 zh-TW 顯示文案。
String poiTypeLabel(String? type) {
  switch (mapPoiCategoryToType(type)) {
    case 'restaurant':
      return '餐廳';
    case 'shopping':
      return '購物';
    case 'hotel':
      return '飯店';
    case 'parking':
      return '停車';
    case 'transport':
      return '交通';
    case 'activity':
      return '活動';
    case 'other':
      return '其他';
    case 'attraction':
    default:
      return '景點';
  }
}

/// Explore 搜尋結果與收藏清單共用的粗略 identity key。
String poiFavoriteKey({required String name, required String? type}) {
  return '${mapPoiCategoryToType(type)}::${name.trim().toLowerCase()}';
}
