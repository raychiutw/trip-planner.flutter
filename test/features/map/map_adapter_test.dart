import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_style.dart';
import 'package:tripline/features/map/trip_map_overlay_synchronizer.dart';

void main() {
  test('TripMapPoint remains an SDK-neutral value object', () {
    expect(
      const TripMapPoint(26.217, 127.719),
      const TripMapPoint(26.217, 127.719),
    );
  });

  test('map presets preserve road, terrain, and satellite choices', () {
    expect(
      kTripMapTilePresets.map((preset) => preset.style),
      TripMapTileStyle.values,
    );
  });

  test('plugin POI is converted to the app-owned selection DTO', () {
    const selection = GoogleMapPoiSelection(
      placeId: 'place-1',
      name: '清水寺',
      point: TripMapPoint(34.9948, 135.7850),
    );

    expect(selection.placeId, 'place-1');
    expect(selection.point.latitude, closeTo(34.9948, 0.0001));
  });

  test('controller queues camera work until the renderer attaches', () async {
    final platform = _FakeTripMapPlatformController();
    final controller = TripMapController();
    final move = controller.move(const TripMapPoint(35, 135), 12);

    controller.attach(platform);
    await move;

    expect(platform.moves.single.zoom, 12);
  });

  test('controller sends the horizontal inset and motion preference', () async {
    final platform = _FakeTripMapPlatformController();
    final controller = TripMapController()
      ..reduceMotion = true
      ..attach(platform);

    await controller.fitPoints(
      const [TripMapPoint(26.217, 127.719), TripMapPoint(26.214, 127.688)],
      padding: const EdgeInsets.fromLTRB(40, 100, 40, 250),
      maxZoom: 12,
    );

    expect(platform.fits.single.padding, 40);
    expect(platform.fits.single.animate, isFalse);
  });

  test('failed camera work does not poison later queued operations', () async {
    final platform = _FailingFirstTripMapPlatformController();
    final controller = TripMapController()..attach(platform);

    final first = controller.move(const TripMapPoint(35, 135), 12);
    final second = controller.move(const TripMapPoint(34, 136), 12);

    await expectLater(first, throwsStateError);
    await second;
    expect(platform.moves.single.point, const TripMapPoint(34, 136));
  });

  test('overlay reconciliation updates only changed semantic IDs', () async {
    final platform = _FakeTripMapOverlayPlatform();
    final sync = TripMapOverlaySynchronizer(platform);
    await sync.sync(
      markers: [_marker('a'), _marker('b')],
      routes: [_route('r')],
    );
    await sync.sync(
      markers: [_marker('a'), _marker('c')],
      routes: [_route('r')],
    );

    expect(platform.removedMarkerSemanticIds, ['b']);
    expect(platform.addedMarkerSemanticIds, containsAll(['a', 'b', 'c']));
    expect(platform.clearCount, 0);
  });

  test('overlay disposal waits for sync and ignores later updates', () async {
    final platform = _BlockingTripMapOverlayPlatform();
    final sync = TripMapOverlaySynchronizer(platform);
    final firstSync = sync.sync(markers: [_marker('a')], routes: const []);
    await platform.firstAddStarted.future;

    final disposal = sync.dispose();
    final lateSync = sync.sync(markers: [_marker('b')], routes: const []);
    await Future<void>.delayed(Duration.zero);

    expect(platform.maxConcurrentCalls, 1);
    platform.releaseFirstAdd.complete();
    await Future.wait([firstSync, disposal, lateSync]);

    expect(platform.addedMarkerSemanticIds, ['a']);
    expect(platform.removedMarkerSemanticIds, ['a']);
    expect(platform.maxConcurrentCalls, 1);
  });

  test(
    'overlay reconciliation coalesces queued updates to the latest snapshot',
    () async {
      final platform = _BlockingTripMapOverlayPlatform();
      final sync = TripMapOverlaySynchronizer(platform);
      final first = sync.sync(markers: [_marker('a')], routes: const []);
      await platform.firstAddStarted.future;

      final superseded = sync.sync(markers: [_marker('b')], routes: const []);
      final latest = sync.sync(markers: [_marker('c')], routes: const []);
      platform.releaseFirstAdd.complete();

      await Future.wait([first, superseded, latest]);

      expect(platform.addedMarkerSemanticIds, ['a', 'c']);
      expect(platform.removedMarkerSemanticIds, ['a']);
      expect(platform.maxConcurrentCalls, 1);
    },
  );
}

TripMapMarker _marker(String id) => TripMapMarker(
  id: id,
  point: const TripMapPoint(25.033, 121.565),
  color: Colors.blue,
  style: tripMapMarkerStyle(dayColor: Colors.blue, isFocused: false),
  glyph: '1',
);

TripMapRoute _route(String id) => TripMapRoute(
  id: id,
  points: const [TripMapPoint(25.033, 121.565), TripMapPoint(25.034, 121.566)],
  color: Colors.blue,
  strokeWidth: 4,
);

class _CameraMove {
  const _CameraMove(this.point, this.zoom, this.animate);

  final TripMapPoint point;
  final double zoom;
  final bool animate;
}

class _CameraFit {
  const _CameraFit(this.points, this.padding, this.maxZoom, this.animate);

  final List<TripMapPoint> points;
  final double padding;
  final double? maxZoom;
  final bool animate;
}

class _FakeTripMapPlatformController implements TripMapPlatformController {
  final moves = <_CameraMove>[];
  final fits = <_CameraFit>[];

  @override
  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required double padding,
    required bool animate,
    double? maxZoom,
  }) async {
    fits.add(_CameraFit(points, padding, maxZoom, animate));
  }

  @override
  Future<void> move(
    TripMapPoint point,
    double zoom, {
    required bool animate,
  }) async {
    moves.add(_CameraMove(point, zoom, animate));
  }
}

class _FailingFirstTripMapPlatformController
    extends _FakeTripMapPlatformController {
  var _shouldFail = true;

  @override
  Future<void> move(
    TripMapPoint point,
    double zoom, {
    required bool animate,
  }) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('camera unavailable');
    }
    await super.move(point, zoom, animate: animate);
  }
}

class _FakeTripMapOverlayPlatform implements TripMapOverlayPlatform {
  final addedMarkerSemanticIds = <String>[];
  final removedMarkerSemanticIds = <String>[];
  int clearCount = 0;

  @override
  Future<void> addMarker(TripMapMarker marker) async {
    addedMarkerSemanticIds.add(marker.id);
  }

  @override
  Future<void> addRoute(TripMapRoute route) async {}

  @override
  Future<void> removeMarker(String semanticId) async {
    removedMarkerSemanticIds.add(semanticId);
  }

  @override
  Future<void> removeRoute(String semanticId) async {}

  @override
  Future<void> updateMarker(TripMapMarker marker) async {}

  @override
  Future<void> updateRoute(TripMapRoute route) async {}
}

class _BlockingTripMapOverlayPlatform extends _FakeTripMapOverlayPlatform {
  final firstAddStarted = Completer<void>();
  final releaseFirstAdd = Completer<void>();
  var _blockedFirstAdd = false;
  var _activeCalls = 0;
  var maxConcurrentCalls = 0;

  @override
  Future<void> addMarker(TripMapMarker marker) async {
    _activeCalls += 1;
    maxConcurrentCalls = maxConcurrentCalls < _activeCalls
        ? _activeCalls
        : maxConcurrentCalls;
    try {
      if (!_blockedFirstAdd) {
        _blockedFirstAdd = true;
        firstAddStarted.complete();
        await releaseFirstAdd.future;
      }
      await super.addMarker(marker);
    } finally {
      _activeCalls -= 1;
    }
  }

  @override
  Future<void> removeMarker(String semanticId) async {
    _activeCalls += 1;
    maxConcurrentCalls = maxConcurrentCalls < _activeCalls
        ? _activeCalls
        : maxConcurrentCalls;
    try {
      await super.removeMarker(semanticId);
    } finally {
      _activeCalls -= 1;
    }
  }
}
