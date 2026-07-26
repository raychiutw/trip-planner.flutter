import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/google_maps_external_launcher.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  const namedPoi = GoogleMapPoiSelection(
    placeId: 'ChIJ-test',
    name: '清水寺 Kyoto',
    point: TripMapPoint(34.9948, 135.7850),
  );

  test('builds a precise encoded Google Maps Universal URL', () {
    final uri = GoogleMapsExternalLauncher.buildSearchUri(namedPoi);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], '清水寺 Kyoto');
    expect(uri.queryParameters['query_place_id'], 'ChIJ-test');
  });

  test('falls back to coordinates when a POI has no usable name', () {
    final uri = GoogleMapsExternalLauncher.buildSearchUri(
      const GoogleMapPoiSelection(
        placeId: '',
        name: '   ',
        point: TripMapPoint(34.9948, 135.7850),
      ),
    );

    expect(uri.queryParameters['query'], '34.9948,135.785');
    expect(uri.queryParameters.containsKey('query_place_id'), isFalse);
  });

  test('open returns false and requests an external application', () async {
    Uri? openedUri;
    LaunchMode? openedMode;
    final launcher = GoogleMapsExternalLauncher(
      launch: (uri, {required mode}) async {
        openedUri = uri;
        openedMode = mode;
        return false;
      },
    );

    expect(await launcher.open(namedPoi), isFalse);
    expect(openedUri, GoogleMapsExternalLauncher.buildSearchUri(namedPoi));
    expect(openedMode, LaunchMode.externalApplication);
  });

  test('entry URI uses name first so Google Maps shows the place, not coordinates', () {
    // 與 buildSearchUri 同一條規則:有名稱就用名稱 —— 帶座標當 query 時
    // Google Maps 只會落一根無名的座標針,使用者看到的是一串數字。
    expect(
      GoogleMapsExternalLauncher.buildEntryUri(
        name: '沖繩美麗海水族館',
        latitude: 26.6942,
        longitude: 127.8778,
      ).queryParameters['query'],
      '沖繩美麗海水族館',
    );
    expect(
      GoogleMapsExternalLauncher.buildEntryUri(
        name: '沖繩美麗海水族館',
      ).queryParameters['query'],
      '沖繩美麗海水族館',
    );
  });

  test('entry URI falls back to coordinates when the name is blank', () {
    expect(
      GoogleMapsExternalLauncher.buildEntryUri(
        name: '   ',
        latitude: 26.6942,
        longitude: 127.8778,
      ).queryParameters['query'],
      '26.6942,127.8778',
    );
  });
}
