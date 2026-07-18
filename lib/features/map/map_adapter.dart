import 'dart:async';

import 'package:flutter/material.dart';

import 'map_canvas_mobile.dart'
    if (dart.library.js_interop) 'map_canvas_web.dart'
    as platform_canvas;
import 'map_style.dart';

@immutable
class TripMapPoint {
  const TripMapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is TripMapPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

enum TripMapTileStyle { roadmap, terrain, satellite }

@immutable
class TripMapTilePreset {
  const TripMapTilePreset({required this.style, required this.label});

  final TripMapTileStyle style;
  final String label;
}

const List<TripMapTilePreset> kTripMapTilePresets = [
  TripMapTilePreset(style: TripMapTileStyle.roadmap, label: '路線圖'),
  TripMapTilePreset(style: TripMapTileStyle.terrain, label: '地形'),
  TripMapTilePreset(style: TripMapTileStyle.satellite, label: '衛星'),
];

typedef TripMapTapCallback = void Function(TripMapPoint point);
typedef TripMapCanvasBuilder = Widget Function(TripMapCanvasConfig config);

@immutable
class GoogleMapPoiSelection {
  const GoogleMapPoiSelection({
    required this.placeId,
    required this.name,
    required this.point,
  });

  final String placeId;
  final String name;
  final TripMapPoint point;

  @override
  bool operator ==(Object other) =>
      other is GoogleMapPoiSelection &&
      other.placeId == placeId &&
      other.name == name &&
      other.point == point;

  @override
  int get hashCode => Object.hash(placeId, name, point);
}

@immutable
class TripMapRoute {
  const TripMapRoute({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.opacity = 1,
    this.dashed = false,
  });

  final String id;
  final List<TripMapPoint> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool dashed;
}

@immutable
class TripMapMarker {
  const TripMapMarker({
    required this.id,
    required this.point,
    required this.color,
    this.style,
    this.title,
    this.snippet,
    this.onTap,
    this.zIndex = 0,
    this.clusterable = true,
    this.glyph,
  });

  final String id;
  final TripMapPoint point;
  final Color color;
  final TripMapMarkerStyle? style;
  final String? title;
  final String? snippet;
  final VoidCallback? onTap;
  final int zIndex;
  final bool clusterable;
  final String? glyph;
}

abstract interface class TripMapPlatformController {
  Future<void> move(TripMapPoint point, double zoom, {required bool animate});

  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required double padding,
    required bool animate,
    double? maxZoom,
  });
}

class TripMapController {
  TripMapPlatformController? _platform;
  final List<_PendingCameraOperation> _pending = [];
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  bool reduceMotion = false;

  void attach(TripMapPlatformController platform) {
    if (_disposed) return;
    _platform = platform;
    final pending = List<_PendingCameraOperation>.of(_pending);
    _pending.clear();
    for (final operation in pending) {
      final future = _schedule(platform, operation.action);
      unawaited(
        future.then<void>(
          (_) => operation.completer.complete(),
          onError: operation.completer.completeError,
        ),
      );
    }
  }

  void detach(TripMapPlatformController platform) {
    if (identical(_platform, platform)) _platform = null;
  }

  Future<void> move(TripMapPoint point, double zoom) =>
      _run((platform) => platform.move(point, zoom, animate: !reduceMotion));

  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required EdgeInsets padding,
    double? maxZoom,
  }) {
    if (points.isEmpty) return Future<void>.value();
    final edgePadding = padding.left < padding.right
        ? padding.left
        : padding.right;
    return _run(
      (platform) => platform.fitPoints(
        points,
        padding: edgePadding,
        maxZoom: maxZoom,
        animate: !reduceMotion,
      ),
    );
  }

  Future<void> _run(_CameraOperation action) {
    if (_disposed) return Future<void>.value();
    final platform = _platform;
    if (platform != null) return _schedule(platform, action);
    final completer = Completer<void>();
    _pending.add(_PendingCameraOperation(action, completer));
    return completer.future;
  }

  Future<void> _schedule(
    TripMapPlatformController platform,
    _CameraOperation action,
  ) {
    final operation = _tail.then((_) => action(platform));
    _tail = _swallow(operation);
    return operation;
  }

  Future<void> _swallow(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // The returned operation still exposes the error to its caller. Keeping
      // the queue alive lets later camera requests continue.
    }
  }

  void dispose() {
    _disposed = true;
    _platform = null;
    for (final operation in _pending) {
      operation.completer.complete();
    }
    _pending.clear();
  }
}

typedef _CameraOperation =
    Future<void> Function(TripMapPlatformController platform);

class _PendingCameraOperation {
  const _PendingCameraOperation(this.action, this.completer);

  final _CameraOperation action;
  final Completer<void> completer;
}

@immutable
class TripMapCameraPosition {
  const TripMapCameraPosition({required this.target, required this.zoom});

  final TripMapPoint target;
  final double zoom;
}

@immutable
class TripMapCanvasConfig {
  const TripMapCanvasConfig({
    required this.controller,
    required this.tilePreset,
    required this.initialFitPoints,
    this.initialCenter,
    this.initialZoom = 14,
    this.initialPadding = const EdgeInsets.all(32),
    this.initialMaxZoom,
    this.routes = const [],
    this.markers = const [],
    this.clusterMarkers = false,
    this.onMapReady,
    this.onCameraIdle,
    this.onMapStyleApplied,
    this.onTap,
    this.onGooglePoiSelected,
    this.mapKey = const ValueKey('google-trip-map-canvas'),
  });

  final TripMapController controller;
  final TripMapTilePreset tilePreset;
  final List<TripMapPoint> initialFitPoints;
  final TripMapPoint? initialCenter;
  final double initialZoom;
  final EdgeInsets initialPadding;
  final double? initialMaxZoom;
  final List<TripMapRoute> routes;
  final List<TripMapMarker> markers;
  final bool clusterMarkers;
  final VoidCallback? onMapReady;
  final ValueChanged<TripMapCameraPosition>? onCameraIdle;
  final ValueChanged<Brightness>? onMapStyleApplied;
  final TripMapTapCallback? onTap;
  final ValueChanged<GoogleMapPoiSelection>? onGooglePoiSelected;
  final Key mapKey;
}

Widget buildTripMapCanvas(
  TripMapCanvasConfig config, {
  TripMapCanvasBuilder? builder,
}) =>
    builder?.call(config) ?? platform_canvas.buildPlatformTripMapCanvas(config);
