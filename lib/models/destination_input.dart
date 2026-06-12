/// 建立/編輯行程表單用的目的地值型別(對應後端 destinations[] snake_case)。
library;

import 'poi_search_result.dart';

class DestinationInput {
  const DestinationInput({
    required this.name,
    this.lat,
    this.lng,
    this.country,
    this.dayQuota,
  });

  final String name;
  final double? lat;
  final double? lng;
  final String? country;
  final int? dayQuota;

  factory DestinationInput.fromPoi(PoiSearchResult p) => DestinationInput(
    name: p.name,
    lat: p.lat,
    lng: p.lng,
    country: p.country,
  );

  DestinationInput copyWith({int? dayQuota}) => DestinationInput(
    name: name,
    lat: lat,
    lng: lng,
    country: country,
    dayQuota: dayQuota ?? this.dayQuota,
  );

  /// 送 POST/PUT 的 destinations[] 元素(snake_case;null 省略)。
  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': ?lat,
    'lng': ?lng,
    'day_quota': ?dayQuota,
  };
}
