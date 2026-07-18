import 'dart:async';

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
  _OverlaySnapshot? _pendingSnapshot;
  final List<Completer<void>> _pendingWaiters = [];
  Future<void>? _drainFuture;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Future<void> sync({
    required List<TripMapMarker> markers,
    required List<TripMapRoute> routes,
  }) {
    if (_disposed) return Future<void>.value();
    final waiter = Completer<void>();
    _pendingSnapshot = _OverlaySnapshot(
      markers: List<TripMapMarker>.of(markers),
      routes: List<TripMapRoute>.of(routes),
    );
    _pendingWaiters.add(waiter);
    _drainFuture ??= _drain();
    return waiter.future;
  }

  Future<void> _drain() async {
    while (!_disposed) {
      final snapshot = _pendingSnapshot;
      if (snapshot == null) break;
      final waiters = List<Completer<void>>.of(_pendingWaiters);
      _pendingSnapshot = null;
      _pendingWaiters.clear();
      try {
        await _sync(markers: snapshot.markers, routes: snapshot.routes);
        for (final waiter in waiters) {
          if (!waiter.isCompleted) waiter.complete();
        }
      } catch (error, stackTrace) {
        for (final waiter in waiters) {
          if (!waiter.isCompleted) waiter.completeError(error, stackTrace);
        }
      }
    }
    _drainFuture = null;
    if (!_disposed && _pendingSnapshot != null) {
      _drainFuture = _drain();
    }
  }

  Future<void> _sync({
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

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    _disposed = true;
    _pendingSnapshot = null;
    for (final waiter in _pendingWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _pendingWaiters.clear();
    final activeDrain = _drainFuture;
    return _disposeFuture = () async {
      if (activeDrain != null) await activeDrain;
      await _dispose();
    }();
  }

  Future<void> _dispose() async {
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

class _OverlaySnapshot {
  const _OverlaySnapshot({required this.markers, required this.routes});

  final List<TripMapMarker> markers;
  final List<TripMapRoute> routes;
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
