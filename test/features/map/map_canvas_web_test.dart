import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_canvas_web.dart';
import 'package:tripline/features/map/google_maps_external_launcher.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('web fallback reports ready and keeps a 44pt external action', (
    tester,
  ) async {
    var readyCount = 0;
    const mapKey = ValueKey('web-map-fallback');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: buildPlatformTripMapCanvas(
            TripMapCanvasConfig(
              controller: TripMapController(),
              tilePreset: kTripMapTilePresets.first,
              initialFitPoints: const [TripMapPoint(25.033, 121.5654)],
              onMapReady: () => readyCount++,
              mapKey: mapKey,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(readyCount, 1);
    expect(find.byKey(mapKey), findsOneWidget);
    expect(find.text('請使用 Google 地圖查看完整地圖'), findsOneWidget);
    final action = find.widgetWithText(TextButton, '在 Google 地圖開啟');
    expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
  });

  testWidgets('web fallback exposes an explicit launch failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TripMapWebFallback(
            launcher: GoogleMapsExternalLauncher(
              launch: (uri, {required mode}) async => false,
            ),
            config: TripMapCanvasConfig(
              controller: TripMapController(),
              tilePreset: kTripMapTilePresets.first,
              initialFitPoints: const [],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('在 Google 地圖開啟'));
    await tester.pumpAndSettle();

    expect(find.text('無法開啟 Google 地圖，請稍後再試'), findsOneWidget);
  });
}
