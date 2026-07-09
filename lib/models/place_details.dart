/// Google Place Details response subset used by the mobile app.
library;

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    this.name,
    this.address,
    this.lat,
    this.lng,
    this.hours,
    this.priceLevel,
  });

  final String placeId;
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? hours;
  final String? priceLevel;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      placeId: (json['placeId'] ?? json['place_id']) as String? ?? '',
      name: json['name'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      hours: json['hours'] as String?,
      priceLevel: (json['priceLevel'] ?? json['price_level']) as String?,
    );
  }
}
