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
    final query = coordinates.isNotEmpty ? coordinates : cleanName;
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
