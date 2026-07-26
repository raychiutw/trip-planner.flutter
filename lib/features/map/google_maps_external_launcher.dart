import 'package:url_launcher/url_launcher.dart';

import 'map_adapter.dart';

typedef GoogleMapsUrlLaunch =
    Future<bool> Function(Uri url, {required LaunchMode mode});

class GoogleMapsExternalLauncher {
  const GoogleMapsExternalLauncher({this.launch = launchUrl});

  final GoogleMapsUrlLaunch launch;

  static Uri buildSearchUri(GoogleMapPoiSelection selection) {
    final name = selection.name.trim();
    final placeId = selection.placeId.trim();
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': name.isEmpty
          ? '${_coordinate(selection.point.latitude)},${_coordinate(selection.point.longitude)}'
          : name,
      if (placeId.isNotEmpty) 'query_place_id': placeId,
    });
  }

  static Uri buildEntryUri({
    String? name,
    double? latitude,
    double? longitude,
  }) {
    final cleanName = name?.trim() ?? '';
    final coordinates = latitude == null || longitude == null
        ? ''
        : '${_coordinate(latitude)},${_coordinate(longitude)}';
    // 名稱優先,與 buildSearchUri 同一條規則:座標當 query 時 Google Maps
    // 只落一根無名的針,使用者看到的是一串數字而不是景點。
    //
    // 天花板:`/maps/search/?api=1` 沒有「名稱 + 座標」並存的參數(Apple 那側
    // 的 `q` + `ll` 可以),所以同名景點會落到錯的地點。要同時精準又有名字,
    // 唯一解是後端補 `placeId` → 走 buildSearchUri 的 `query_place_id`。
    final query = cleanName.isNotEmpty ? cleanName : coordinates;
    if (query.isEmpty) {
      throw ArgumentError('A map query requires a name or coordinates.');
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  Future<bool> open(GoogleMapPoiSelection selection) =>
      launch(buildSearchUri(selection), mode: LaunchMode.externalApplication);
}

String _coordinate(double value) =>
    double.parse(value.toStringAsFixed(6)).toString();
