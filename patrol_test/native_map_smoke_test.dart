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
const _nativeMapEvidenceLabel = 'Tripline native map evidence canvas';
const _nativePinchRequestLabel = 'Tripline native map pinch request';
const _nativeRotateRequestLabel = 'Tripline native map rotate request';
const _nativeDoubleTapRequestLabel = 'Tripline native map double tap request';

enum _NativeGesture { pan, pinch, rotate, doubleTap }

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

    await $(#armPanCheck).tap();
    await $.platform.mobile.swipe(
      from: const Offset(0.5, 0.68),
      to: const Offset(0.5, 0.42),
      steps: 24,
    );
    await $(
      #nativeMapPanObserved,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#nativeMapPanObserved), findsOneWidget);

    final semantics = $.tester.ensureSemantics();
    try {
      await $.tester.pump();

      await $(#armPinchCheck).tap();
      await $(
        #nativeMapPinchObserved,
      ).waitUntilExists(timeout: const Duration(seconds: 15));
      expect($(#nativeMapPinchObserved), findsOneWidget);

      await $(#armRotateCheck).tap();
      await $(
        #nativeMapRotateObserved,
      ).waitUntilExists(timeout: const Duration(seconds: 15));
      expect($(#nativeMapRotateObserved), findsOneWidget);

      await $(#armDoubleTapCheck).tap();
      await $(
        #nativeMapDoubleTapObserved,
      ).waitUntilExists(timeout: const Duration(seconds: 15));
      expect($(#nativeMapDoubleTapObserved), findsOneWidget);
    } finally {
      semantics.dispose();
    }

    await $(#requestLocationPermission).tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $(
      #locationPermissionGranted,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#locationPermissionGranted), findsOneWidget);

    await $(#toggleMapLifecycle).tap();
    await $(
      #nativeMapRemounted,
    ).waitUntilExists(timeout: const Duration(seconds: 30));
    expect($(#nativeMapRemounted), findsOneWidget);

    await $(#focusAtZoom13).tap();
    await $(
      #nativeMapRemountCameraObserved,
    ).waitUntilExists(timeout: const Duration(seconds: 15));
    expect($(#nativeMapRemountCameraObserved), findsOneWidget);

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
  bool _mapMounted = true;
  int _readyCount = 0;
  bool _expectingZoom13 = false;
  bool _observedZoom13 = false;
  bool _remountCameraObserved = false;
  _NativeGesture? _expectedGesture;
  final _observedGestures = <_NativeGesture>{};
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
        if (_readyCount >= 2) _remountCameraObserved = true;
      });
      return;
    }
    final expectedGesture = _expectedGesture;
    if (expectedGesture != null) {
      final start = _gestureStartPosition;
      if (start == null) return;
      final observed = switch (expectedGesture) {
        _NativeGesture.pan => !_near(
          start.target,
          position.target,
          tolerance: 1e-5,
        ),
        _NativeGesture.pinch ||
        _NativeGesture.doubleTap => (start.zoom - position.zoom).abs() >= 0.25,
        _NativeGesture.rotate =>
          _bearingDelta(start.bearing, position.bearing) >= 5,
      };
      if (!observed) return;
      setState(() {
        _expectedGesture = null;
        _observedGestures.add(expectedGesture);
      });
    }
  }

  void _armGesture(_NativeGesture gesture) {
    setState(() {
      _expectedGesture = gesture;
      _observedGestures.remove(gesture);
      _gestureStartPosition = _lastCameraPosition;
    });
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

  Future<void> _remountMap() async {
    setState(() {
      _mapMounted = false;
      _ready = false;
      _observedZoom13 = false;
      _remountCameraObserved = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _mapMounted = true);
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
            if (_mapMounted)
              Positioned.fill(
                child: Semantics(
                  label: _nativeMapEvidenceLabel,
                  container: true,
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
                        if (mounted) {
                          setState(() {
                            _ready = true;
                            _readyCount++;
                          });
                        }
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
                    for (final (gesture, key, label) in const [
                      (_NativeGesture.pan, 'armPanCheck', 'Pan'),
                      (_NativeGesture.pinch, 'armPinchCheck', 'Pinch'),
                      (_NativeGesture.rotate, 'armRotateCheck', 'Rotate'),
                      (
                        _NativeGesture.doubleTap,
                        'armDoubleTapCheck',
                        'Double tap',
                      ),
                    ])
                      FilledButton(
                        key: ValueKey(key),
                        onPressed: () => _armGesture(gesture),
                        child: Text(switch ((_expectedGesture, gesture)) {
                          (_NativeGesture.pinch, _NativeGesture.pinch) =>
                            _nativePinchRequestLabel,
                          (_NativeGesture.rotate, _NativeGesture.rotate) =>
                            _nativeRotateRequestLabel,
                          (
                            _NativeGesture.doubleTap,
                            _NativeGesture.doubleTap,
                          ) =>
                            _nativeDoubleTapRequestLabel,
                          _ => label,
                        }),
                      ),
                    FilledButton(
                      key: const ValueKey('requestLocationPermission'),
                      onPressed: _requestLocationPermission,
                      child: const Text('Location'),
                    ),
                    FilledButton(
                      key: const ValueKey('toggleMapLifecycle'),
                      onPressed: _remountMap,
                      child: const Text('Remount'),
                    ),
                  ],
                ),
              ),
            ),
            if (_ready)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapReady')),
              ),
            if (_readyCount >= 2)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapRemounted')),
              ),
            if (_remountCameraObserved)
              const IgnorePointer(
                child: SizedBox(
                  key: ValueKey('nativeMapRemountCameraObserved'),
                ),
              ),
            if (_observedZoom13)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('observedZoom13')),
              ),
            if (_darkStyleApplied)
              const IgnorePointer(
                child: SizedBox(key: ValueKey('darkMapTheme')),
              ),
            if (_observedGestures.contains(_NativeGesture.pan))
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapPanObserved')),
              ),
            if (_observedGestures.contains(_NativeGesture.pinch))
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapPinchObserved')),
              ),
            if (_observedGestures.contains(_NativeGesture.rotate))
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapRotateObserved')),
              ),
            if (_observedGestures.contains(_NativeGesture.doubleTap))
              const IgnorePointer(
                child: SizedBox(key: ValueKey('nativeMapDoubleTapObserved')),
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

double _bearingDelta(double first, double second) {
  final delta = (first - second).abs() % 360;
  return delta > 180 ? 360 - delta : delta;
}
