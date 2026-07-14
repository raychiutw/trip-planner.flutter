import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_location.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/theme/app_theme.dart';

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class _SequencedLocationService implements TripMapLocationService {
  int calls = 0;

  @override
  Future<TripMapPoint> currentLocation() async {
    calls++;
    if (calls == 1) {
      throw const TripMapLocationException('請開啟定位權限');
    }
    return const TripMapPoint(26.215, 127.72);
  }
}

const _favorite = PoiFavorite(
  id: 1,
  userId: 'u',
  poiId: 10,
  favoritedAt: '2026-01-01',
  poiName: '首里城',
  poiLat: 26.2,
  poiLng: 127.7,
  poiType: 'attraction',
);

Widget _buildApp({TripMapLocationService? locationService}) {
  return ProviderScope(
    overrides: [
      favoritesProvider.overrideWith((ref) => Stream.value(const [_favorite])),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: GlobalMapScreen(
        tileProvider: _TransparentTileProvider(),
        locationService: locationService,
      ),
    ),
  );
}

void main() {
  testWidgets('地圖 marker 保留小圓點但提供 44pt 點擊區與名稱語意', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final marker = find.byKey(const ValueKey('map-fav-1'));
    expect(tester.getSize(marker), const Size(44, 44));
    expect(find.bySemanticsLabel('地點：首里城，景點'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('定位失敗持續顯示且可直接重試', (tester) async {
    final location = _SequencedLocationService();
    await tester.pumpWidget(_buildApp(locationService: location));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('global-map-locate-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('global-map-location-error')),
      findsOneWidget,
    );
    expect(find.text('請開啟定位權限'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('請開啟定位權限'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(location.calls, 2);
    expect(
      find.byKey(const ValueKey('global-map-location-error')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('global-map-user-location')),
      findsOneWidget,
    );
  });
}
