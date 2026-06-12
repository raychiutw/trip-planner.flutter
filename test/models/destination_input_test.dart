import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/destination_input.dart';
import 'package:tripline/models/poi_search_result.dart';

void main() {
  test('fromPoi 帶入 name/lat/lng/country', () {
    const poi = PoiSearchResult(
      placeId: 'p1',
      name: '東京',
      lat: 35.68,
      lng: 139.76,
      country: 'JP',
    );
    final d = DestinationInput.fromPoi(poi);
    expect(d.name, '東京');
    expect(d.lat, 35.68);
    expect(d.lng, 139.76);
    expect(d.country, 'JP');
    expect(d.dayQuota, isNull);
  });

  test('toJson：snake_case + null 省略', () {
    expect(
      const DestinationInput(
        name: 'A',
        lat: 1.0,
        lng: 2.0,
        dayQuota: 3,
      ).toJson(),
      {'name': 'A', 'lat': 1.0, 'lng': 2.0, 'day_quota': 3},
    );
    expect(const DestinationInput(name: 'B').toJson(), {'name': 'B'});
  });

  test('copyWith(dayQuota:)', () {
    const d = DestinationInput(name: 'A', country: 'JP');
    expect(d.copyWith(dayQuota: 2).dayQuota, 2);
    expect(d.copyWith(dayQuota: 2).country, 'JP'); // 其他欄位保留
  });
}
