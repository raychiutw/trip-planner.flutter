import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patrol/patrol.dart';
import 'package:tripline/features/map/map_adapter.dart';

import 'support/ios_system_alerts.dart';

const _taipei101 = TripMapPoint(25.033968, 121.564468);
// Keep this outside the initial Taipei 101 viewport so the native SDK cannot
// coalesce the camera update and skip its idle callback.
const _zoomCheckPoint = TripMapPoint(25.1676, 121.4450);
const _expectGooglePoi = bool.fromEnvironment('E2E_EXPECT_GOOGLE_POI');
const _poiTapOffsets = <Offset>[
  Offset(0.5, 0.5),
  Offset(0.47, 0.5),
  Offset(0.53, 0.5),
  Offset(0.5, 0.47),
  Offset(0.5, 0.53),
  Offset(0.47, 0.47),
  Offset(0.53, 0.47),
  Offset(0.47, 0.53),
  Offset(0.53, 0.53),
];

void main() {
  patrolTest('native Google Map renders, keeps zoom 13, and exposes a POI', (
    $,
  ) async {
    await dismissStaleSpringBoardTutorial($);
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
    await $(
      #nativeMapReady,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#nativeMapReady), findsOneWidget);

    await $(#focusAtZoom13).tap();
    await $(
      #observedZoom13,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#observedZoom13), findsOneWidget);

    await $(#toggleBrightness).tap();
    await $(
      #darkMapTheme,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#darkMapTheme), findsOneWidget);

    await $(#armGestureCheck).tap();
    await $.platform.mobile.swipe(
      from: const Offset(0.5, 0.68),
      to: const Offset(0.5, 0.42),
      steps: 24,
    );
    await $(
      #nativeMapGestureObserved,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#nativeMapGestureObserved), findsOneWidget);

    await $(#requestLocationPermission).tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $(
      #locationPermissionGranted,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#locationPermissionGranted), findsOneWidget);

    if (!_expectGooglePoi) return;

    // The release behavior stays at zoom 13. For the strict Test Lab-only POI
    // assertion, zoom in after that check so the known native POI is a stable
    // center-screen tap across device sizes and locales.
    await controller.move(_taipei101, 18);
    await $(
      #poiZoomReady,
    ).waitUntilExists(timeout: const Duration(seconds: 15));

    // Google Maps PlatformViews don't expose POI labels consistently through
    // the native accessibility tree. A normalized native tap validates the
    // real onPoiClicked bridge without depending on locale-specific labels.
    GoogleMapPoiSelection? poi;
    for (final offset in _poiTapOffsets) {
      await $.platform.mobile.tapAt(offset);
      try {
        poi = await selectedPoi.future.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // Continue across a small center grid because Google label placement
        // can shift slightly between device models and map-data revisions.
      }
      if (poi != null) break;
    }
    expect(
      poi,
      isNotNull,
      reason: 'No native Google POI callback was observed near map center.',
    );
    final selected = poi!;
    expect(selected.placeId, isNotEmpty);
    expect(selected.point.latitude, closeTo(_taipei101.latitude, 0.01));
    expect(selected.point.longitude, closeTo(_taipei101.longitude, 0.01));
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
  bool _expectingZoom13 = false;
  bool _observedZoom13 = false;
  bool _expectingGesture = false;
  bool _gestureObserved = false;
  bool _darkStyleApplied = false;
  bool _locationPermissionGranted = false;
  bool _poiZoomReady = false;
  TripMapCameraPosition? _lastCameraPosition;
  TripMapCameraPosition? _gestureStartPosition;

  void _handleCameraIdle(TripMapCameraPosition position) {
    if (!mounted) return;
    _lastCameraPosition = position;
    if ((position.zoom - 18).abs() < 0.05 &&
        _near(position.target, _taipei101) &&
        !_poiZoomReady) {
      setState(() => _poiZoomReady = true);
      return;
    }
    if (_expectingZoom13 &&
        (position.zoom - 13).abs() < 0.05 &&
        _near(position.target, _zoomCheckPoint)) {
      setState(() {
        _expectingZoom13 = false;
        _observedZoom13 = true;
      });
      return;
    }
    if (_expectingGesture) {
      final start = _gestureStartPosition;
      if (start == null ||
          _near(start.target, position.target, tolerance: 1e-5)) {
        return;
      }
      setState(() {
        _expectingGesture = false;
        _gestureObserved = true;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    setState(() {
      _locationPermissionGranted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
  }

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
                  initialZoom: 13,
                  initialMaxZoom: 13,
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
                  onCameraIdle: _handleCameraIdle,
                  onMapStyleApplied: (brightness) {
                    if (brightness == Brightness.dark && mounted) {
                      setState(() => _darkStyleApplied = true);
                    }
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
                      key: const ValueKey('focusAtZoom13'),
                      onPressed: () async {
                        setState(() => _expectingZoom13 = true);
                        await widget.controller.move(_zoomCheckPoint, 13);
                      },
                      child: const Text('Zoom 13'),
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
                    FilledButton(
                      key: const ValueKey('armGestureCheck'),
                      onPressed: () => setState(() {
                        _expectingGesture = true;
                        _gestureObserved = false;
                        _gestureStartPosition = _lastCameraPosition;
                      }),
                      child: const Text('Gesture'),
                    ),
                    FilledButton(
                      key: const ValueKey('requestLocationPermission'),
                      onPressed: _requestLocationPermission,
                      child: const Text('Location'),
                    ),
                  ],
                ),
              ),
            ),
            if (_ready)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapReady')),
              ),
            if (_observedZoom13)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('observedZoom13')),
              ),
            if (_darkStyleApplied)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('darkMapTheme')),
              ),
            if (_gestureObserved)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapGestureObserved')),
              ),
            if (_locationPermissionGranted)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('locationPermissionGranted')),
              ),
            if (_poiZoomReady)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('poiZoomReady')),
              ),
          ],
        ),
      ),
    );
  }
}

bool _near(
  TripMapPoint first,
  TripMapPoint second, {
  double tolerance = 0.0005,
}) =>
    (first.latitude - second.latitude).abs() < tolerance &&
    (first.longitude - second.longitude).abs() < tolerance;
