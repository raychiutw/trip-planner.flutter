import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tripline/features/map/map_adapter.dart';

const _taipei101 = TripMapPoint(25.033968, 121.564468);
const _expectGooglePoi = bool.fromEnvironment('E2E_EXPECT_GOOGLE_POI');

void main() {
  patrolTest('native Google Map renders, keeps zoom 12, and exposes a POI', (
    $,
  ) async {
    final ready = Completer<void>();
    final selectedPoi = Completer<GoogleMapPoiSelection>();
    final controller = TripMapController();

    await $.pumpWidgetAndSettle(
      _NativeMapSmokeHarness(
        controller: controller,
        onReady: () {
          if (!ready.isCompleted) ready.complete();
        },
        onGooglePoiSelected: (poi) {
          if (!selectedPoi.isCompleted) selectedPoi.complete(poi);
        },
      ),
    );

    await ready.future.timeout(const Duration(seconds: 30));
    await $.pump(const Duration(milliseconds: 100));
    expect($(#nativeMapReady), findsOneWidget);

    await $(#focusAtZoom12).tap();
    await $.pump(const Duration(seconds: 1));
    expect($(#lastRequestedZoom12), findsOneWidget);

    await $(#toggleBrightness).tap();
    await $.pump(const Duration(seconds: 1));
    expect($(#darkMapTheme), findsOneWidget);

    if (!_expectGooglePoi) return;

    // The release behavior stays at zoom 12. For the strict Test Lab-only POI
    // assertion, zoom in after that check so the known native POI is a stable
    // center-screen tap across device sizes and locales.
    controller.move(_taipei101, 18);
    await $.pump(const Duration(seconds: 2));

    // Google Maps PlatformViews don't expose POI labels consistently through
    // the native accessibility tree. A normalized native tap validates the
    // real onPoiClicked bridge without depending on locale-specific labels.
    await $.platform.mobile.tapAt(const Offset(0.5, 0.5));

    final poi = await selectedPoi.future.timeout(const Duration(seconds: 20));
    expect(poi.placeId, isNotEmpty);
    expect(poi.point.latitude, closeTo(_taipei101.latitude, 0.01));
    expect(poi.point.longitude, closeTo(_taipei101.longitude, 0.01));
  });
}

class _NativeMapSmokeHarness extends StatefulWidget {
  const _NativeMapSmokeHarness({
    required this.controller,
    required this.onReady,
    required this.onGooglePoiSelected,
  });

  final TripMapController controller;
  final VoidCallback onReady;
  final ValueChanged<GoogleMapPoiSelection> onGooglePoiSelected;

  @override
  State<_NativeMapSmokeHarness> createState() => _NativeMapSmokeHarnessState();
}

class _NativeMapSmokeHarnessState extends State<_NativeMapSmokeHarness> {
  Brightness _brightness = Brightness.light;
  bool _ready = false;
  bool _requestedZoom12 = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: buildTripMapCanvas(
                TripMapCanvasConfig(
                  controller: widget.controller,
                  tilePreset: kTripMapTilePresets.first,
                  initialFitPoints: const [_taipei101],
                  initialCenter: _taipei101,
                  initialZoom: 12,
                  initialMaxZoom: 12,
                  routes: const [
                    TripMapRoute(
                      id: 'smoke-route',
                      points: [TripMapPoint(25.028, 121.559), _taipei101],
                      color: Color(0xFFC48B4A),
                      strokeWidth: 6,
                    ),
                  ],
                  markers: const [
                    TripMapMarker(
                      id: 'smoke-marker-1',
                      point: TripMapPoint(25.028, 121.559),
                      color: Color(0xFFC48B4A),
                      glyph: '1',
                      title: 'Tripline smoke marker',
                    ),
                  ],
                  onMapReady: () {
                    if (mounted) setState(() => _ready = true);
                    widget.onReady();
                  },
                  onGooglePoiSelected: widget.onGooglePoiSelected,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      key: const ValueKey('focusAtZoom12'),
                      onPressed: () {
                        setState(() => _requestedZoom12 = true);
                        widget.controller.move(_taipei101, 12);
                      },
                      child: const Text('Zoom 12'),
                    ),
                    FilledButton(
                      key: const ValueKey('toggleBrightness'),
                      onPressed: () => setState(() {
                        _brightness = _brightness == Brightness.light
                            ? Brightness.dark
                            : Brightness.light;
                      }),
                      child: const Text('Theme'),
                    ),
                  ],
                ),
              ),
            ),
            if (_ready)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapReady')),
              ),
            if (_requestedZoom12)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('lastRequestedZoom12')),
              ),
            if (_brightness == Brightness.dark)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('darkMapTheme')),
              ),
          ],
        ),
      ),
    );
  }
}
