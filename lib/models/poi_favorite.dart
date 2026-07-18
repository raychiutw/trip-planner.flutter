/// 收藏 models（`GET /api/poi-favorites`，跨 trip 收藏池）。
library;

/// POI 收藏在某行程的使用紀錄（反查 hotel_poi_id ∪ trip_entry_pois）。
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

/// 一筆 POI 收藏（含 JOIN pois 的展示欄位與 usages）。
class PoiFavorite {
  const PoiFavorite({
    required this.id,
    required this.userId,
    required this.poiId,
    required this.favoritedAt,
    this.note,
    this.poiName,
    this.poiAddress,
    this.poiType,
    this.poiLat,
    this.poiLng,
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
  final String? poiType;
  final double? poiLat;
  final double? poiLng;
  final double? poiRating;
  final List<PoiFavoriteUsage> usages;

  /// 顯示名 fallback：poiName → '未命名地點'。
  String get displayName => poiName ?? '未命名地點';

  factory PoiFavorite.fromJson(Map<String, dynamic> json) {
    return PoiFavorite(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] ?? json['user_id']) as String,
      poiId: ((json['poiId'] ?? json['poi_id']) as num).toInt(),
      favoritedAt: (json['favoritedAt'] ?? json['favorited_at']) as String,
      note: json['note'] as String?,
      poiName: (json['poiName'] ?? json['poi_name']) as String?,
      poiAddress: (json['poiAddress'] ?? json['poi_address']) as String?,
      poiType: (json['poiType'] ?? json['poi_type']) as String?,
      poiLat: ((json['poiLat'] ?? json['poi_lat']) as num?)?.toDouble(),
      poiLng: ((json['poiLng'] ?? json['poi_lng']) as num?)?.toDouble(),
      poiRating: ((json['poiRating'] ?? json['poi_rating']) as num?)
          ?.toDouble(),
      usages: (json['usages'] as List<dynamic>? ?? [])
          .map(
            (usageJson) =>
                PoiFavoriteUsage.fromJson(usageJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
