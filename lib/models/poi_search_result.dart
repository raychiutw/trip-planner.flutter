/// POI 搜尋結果（`GET /api/poi-search`,Google Places 直通,**snake_case** wire）。
library;

enum PoiBusinessStatus { operational, closedTemporarily, closedPermanently }

PoiBusinessStatus? _businessStatusFromJson(Object? raw) {
  switch (raw) {
    case 'OPERATIONAL':
      return PoiBusinessStatus.operational;
    case 'CLOSED_TEMPORARILY':
      return PoiBusinessStatus.closedTemporarily;
    case 'CLOSED_PERMANENTLY':
      return PoiBusinessStatus.closedPermanently;
    default:
      return null;
  }
}

class PoiSearchResult {
  const PoiSearchResult({
    required this.placeId,
    required this.name,
    this.address,
    this.lat = 0,
    this.lng = 0,
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
  final PoiBusinessStatus? businessStatus;

  factory PoiSearchResult.fromJson(Map<String, dynamic> json) {
    return PoiSearchResult(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String?,
      country: json['country'] as String?,
      countryName: json['country_name'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      businessStatus: _businessStatusFromJson(json['business_status']),
    );
  }
}
