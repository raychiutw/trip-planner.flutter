import 'package:flutter/foundation.dart';

import 'map_adapter.dart';

abstract interface class TripMapOverlayPlatform {
  Future<void> addMarker(TripMapMarker marker);
  Future<void> updateMarker(TripMapMarker marker);
  Future<void> removeMarker(String semanticId);
  Future<void> addRoute(TripMapRoute route);
  Future<void> updateRoute(TripMapRoute route);
  Future<void> removeRoute(String semanticId);
}

class TripMapOverlaySynchronizer {
  TripMapOverlaySynchronizer(this._platform);

  final TripMapOverlayPlatform _platform;
  final Map<String, TripMapMarker> _markers = {};
  final Map<String, TripMapRoute> _routes = {};

  Future<void> sync({
    required List<TripMapMarker> markers,
    required List<TripMapRoute> routes,
  }) async {
    final nextMarkers = {for (final marker in markers) marker.id: marker};
    final nextRoutes = {for (final route in routes) route.id: route};

    for (final id
        in _markers.keys.where((id) => !nextMarkers.containsKey(id)).toList()) {
      await _platform.removeMarker(id);
      _markers.remove(id);
    }
    for (final marker in markers) {
      final previous = _markers[marker.id];
      if (previous == null) {
        await _platform.addMarker(marker);
      } else if (!_sameMarker(previous, marker)) {
        await _platform.updateMarker(marker);
      }
      _markers[marker.id] = marker;
    }

    for (final id
        in _routes.keys.where((id) => !nextRoutes.containsKey(id)).toList()) {
      await _platform.removeRoute(id);
      _routes.remove(id);
    }
    for (final route in routes) {
      final previous = _routes[route.id];
      if (previous == null) {
        await _platform.addRoute(route);
      } else if (!_sameRoute(previous, route)) {
        await _platform.updateRoute(route);
      }
      _routes[route.id] = route;
    }
  }

  Future<void> dispose() async {
    for (final id in _markers.keys.toList()) {
      await _platform.removeMarker(id);
    }
    for (final id in _routes.keys.toList()) {
      await _platform.removeRoute(id);
    }
    _markers.clear();
    _routes.clear();
  }
}

bool _sameMarker(TripMapMarker a, TripMapMarker b) =>
    a.point == b.point &&
    a.color == b.color &&
    a.style == b.style &&
    a.title == b.title &&
    a.snippet == b.snippet &&
    a.zIndex == b.zIndex &&
    a.clusterable == b.clusterable &&
    a.glyph == b.glyph;

bool _sameRoute(TripMapRoute a, TripMapRoute b) =>
    listEquals(a.points, b.points) &&
    a.color == b.color &&
    a.strokeWidth == b.strokeWidth &&
    a.opacity == b.opacity &&
    a.dashed == b.dashed;
