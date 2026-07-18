import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;

import 'map_adapter.dart';
import 'map_style.dart';
import 'trip_map_cluster_projector.dart';
import 'trip_map_marker_icon_registry.dart';
import 'trip_map_overlay_synchronizer.dart';

Widget buildPlatformTripMapCanvas(TripMapCanvasConfig config) =>
    _TripMapMobileCanvas(config: config);

class _TripMapMobileCanvas extends StatefulWidget {
  const _TripMapMobileCanvas({required this.config});

  final TripMapCanvasConfig config;

  @override
  State<_TripMapMobileCanvas> createState() => _TripMapMobileCanvasState();
}

class _TripMapMobileCanvasState extends State<_TripMapMobileCanvas> {
  final TripMapMarkerIconRegistry _iconRegistry = TripMapMarkerIconRegistry();
  final TripMapClusterProjector _clusterProjector =
      const TripMapClusterProjector();
  final Map<String, nav.ImageDescriptor> _registeredIcons = {};

  nav.GoogleMapViewController? _nativeController;
  _GoogleNavigationPlatformController? _cameraPlatform;
  _GoogleNavigationOverlayPlatform? _overlayPlatform;
  TripMapOverlaySynchronizer? _overlaySynchronizer;
  Map<String, TripMapMarker> _visibleMarkers = const {};
  double _zoom = 12;
  double _pixelRatio = 1;
  Brightness? _brightness;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _zoom = widget.config.initialZoom;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final brightness = Theme.of(context).brightness;
    if (_brightness != brightness) {
      _brightness = brightness;
      final controller = _nativeController;
      if (controller != null) {
        unawaited(
          controller
              .setMapColorScheme(_mapColorScheme(brightness))
              .catchError(_reportPlatformError),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant _TripMapMobileCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final platform = _cameraPlatform;
    if (platform != null &&
        oldWidget.config.controller != widget.config.controller) {
      oldWidget.config.controller.detach(platform);
      widget.config.controller.attach(platform);
    }
    final controller = _nativeController;
    if (controller != null) {
      if (oldWidget.config.tilePreset.style != widget.config.tilePreset.style) {
        unawaited(
          controller
              .setMapType(mapType: _mapType(widget.config.tilePreset.style))
              .catchError(_reportPlatformError),
        );
      }
      if (oldWidget.config.initialPadding != widget.config.initialPadding) {
        unawaited(
          controller
              .setPadding(widget.config.initialPadding)
              .catchError(_reportPlatformError),
        );
      }
      _scheduleOverlaySync();
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.config.controller.reduceMotion = MediaQuery.disableAnimationsOf(
      context,
    );
    final initialTarget =
        widget.config.initialCenter ??
        (widget.config.initialFitPoints.isEmpty
            ? const TripMapPoint(25.033, 121.5654)
            : widget.config.initialFitPoints.first);
    return nav.GoogleMapsMapView(
      key: widget.config.mapKey,
      onViewCreated: _handleViewCreated,
      initialCameraPosition: nav.CameraPosition(
        target: _toNative(initialTarget),
        zoom: widget.config.initialZoom,
      ),
      initialMapType: _mapType(widget.config.tilePreset.style),
      initialMapColorScheme: _mapColorScheme(Theme.of(context).brightness),
      initialCompassEnabled: true,
      initialMapToolbarEnabled: false,
      initialZoomControlsEnabled: false,
      initialPadding: widget.config.initialPadding,
      onMapClicked: (point) => widget.config.onTap?.call(_fromNative(point)),
      onPoiClicked: (poi) => widget.config.onGooglePoiSelected?.call(
        GoogleMapPoiSelection(
          placeId: poi.placeID,
          name: poi.name,
          point: _fromNative(poi.latLng),
        ),
      ),
      onMarkerClicked: _handleMarkerClicked,
      onCameraIdle: _handleCameraIdle,
    );
  }

  Future<void> _handleViewCreated(
    nav.GoogleMapViewController controller,
  ) async {
    if (_disposed) return;
    _nativeController = controller;
    final cameraPlatform = _GoogleNavigationPlatformController(controller);
    final overlayPlatform = _GoogleNavigationOverlayPlatform(
      controller,
      iconFor: _iconFor,
    );
    _cameraPlatform = cameraPlatform;
    _overlayPlatform = overlayPlatform;
    _overlaySynchronizer = TripMapOverlaySynchronizer(overlayPlatform);
    widget.config.controller.attach(cameraPlatform);

    await _syncOverlays();
    if (_disposed) return;
    await widget.config.controller.fitPoints(
      widget.config.initialFitPoints,
      padding: widget.config.initialPadding,
      maxZoom: widget.config.initialMaxZoom,
    );
    if (!_disposed) widget.config.onMapReady?.call();
  }

  void _scheduleOverlaySync() {
    unawaited(_syncOverlays().catchError(_reportPlatformError));
  }

  Future<void> _syncOverlays() async {
    final synchronizer = _overlaySynchronizer;
    if (synchronizer == null || _disposed) return;
    final projected = _projectMarkers();
    _visibleMarkers = {for (final marker in projected) marker.id: marker};
    await synchronizer.sync(markers: projected, routes: widget.config.routes);
  }

  List<TripMapMarker> _projectMarkers() {
    if (!widget.config.clusterMarkers) return widget.config.markers;
    return [
      for (final item in _clusterProjector.project(
        markers: widget.config.markers,
        zoom: _zoom,
      ))
        if (!item.isCluster)
          item.members.single
        else
          TripMapMarker(
            id: item.id,
            point: item.point,
            color: item.members.first.color,
            style: tripMapMarkerStyle(
              dayColor: item.members.first.color,
              isFocused: false,
            ),
            title: '${item.members.length} 個景點',
            glyph: item.glyph,
            clusterable: false,
            zIndex: 900,
            onTap: () => unawaited(
              widget.config.controller.fitPoints(
                [for (final member in item.members) member.point],
                padding: widget.config.initialPadding,
                maxZoom: 17,
              ),
            ),
          ),
    ];
  }

  void _handleMarkerClicked(String platformMarkerId) {
    final semanticId = _overlayPlatform?.semanticIdFor(platformMarkerId);
    if (semanticId != null) _visibleMarkers[semanticId]?.onTap?.call();
  }

  void _handleCameraIdle(nav.CameraPosition position) {
    final previousBucket = _zoom.floor();
    _zoom = position.zoom;
    if (widget.config.clusterMarkers && _zoom.floor() != previousBucket) {
      _scheduleOverlaySync();
    }
  }

  Future<nav.ImageDescriptor> _iconFor(TripMapMarker marker) async {
    final key = Object.hash(
      marker.glyph,
      marker.style,
      marker.color,
      _pixelRatio,
    ).toString();
    final existing = _registeredIcons[key];
    if (existing != null) return existing;
    final bitmap = await _iconRegistry.bitmapFor(
      marker,
      pixelRatio: _pixelRatio,
    );
    final descriptor = await nav.registerBitmapImage(
      bitmap: ByteData.sublistView(bitmap.bytes),
      imagePixelRatio: bitmap.pixelRatio,
    );
    _registeredIcons[key] = descriptor;
    return descriptor;
  }

  void _reportPlatformError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'trip map renderer',
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    final cameraPlatform = _cameraPlatform;
    if (cameraPlatform != null) widget.config.controller.detach(cameraPlatform);
    unawaited(_disposeOwnedOverlays());
    _nativeController = null;
    _cameraPlatform = null;
    _overlayPlatform = null;
    super.dispose();
  }

  Future<void> _disposeOwnedOverlays() async {
    try {
      await _overlaySynchronizer?.dispose();
      for (final image in _registeredIcons.values) {
        await nav.unregisterImage(image);
      }
    } catch (_) {
      // Native PlatformView teardown may win the race; it already releases
      // the map-owned overlays in that case.
    }
    _registeredIcons.clear();
  }
}

class _GoogleNavigationPlatformController implements TripMapPlatformController {
  const _GoogleNavigationPlatformController(this._controller);

  final nav.GoogleMapViewController _controller;

  @override
  Future<void> move(TripMapPoint point, double zoom, {required bool animate}) =>
      _apply(
        nav.CameraUpdate.newLatLngZoom(_toNative(point), zoom),
        animate: animate,
      );

  @override
  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required double padding,
    required bool animate,
    double? maxZoom,
  }) async {
    if (points.isEmpty) return;
    if (points.length == 1) {
      await move(points.single, maxZoom ?? 16, animate: animate);
      return;
    }
    await _apply(
      nav.CameraUpdate.newLatLngBounds(
        nav.LatLngBounds.createBoundsFromPoints([
          for (final point in points) _toNative(point),
        ]),
        padding: padding,
      ),
      animate: animate,
    );
    if (maxZoom != null &&
        (await _controller.getCameraPosition()).zoom > maxZoom) {
      await _apply(nav.CameraUpdate.zoomTo(maxZoom), animate: animate);
    }
  }

  Future<void> _apply(nav.CameraUpdate update, {required bool animate}) =>
      animate
      ? _controller.animateCamera(update)
      : _controller.moveCamera(update);
}

typedef _IconResolver = Future<nav.ImageDescriptor> Function(TripMapMarker);

class _GoogleNavigationOverlayPlatform implements TripMapOverlayPlatform {
  _GoogleNavigationOverlayPlatform(this._controller, {required this.iconFor});

  final nav.GoogleMapViewController _controller;
  final _IconResolver iconFor;
  final Map<String, nav.Marker> _markers = {};
  final Map<String, String> _semanticMarkerIds = {};
  final Map<String, nav.Polyline> _routes = {};

  String? semanticIdFor(String platformMarkerId) =>
      _semanticMarkerIds[platformMarkerId];

  @override
  Future<void> addMarker(TripMapMarker marker) async {
    final added = (await _controller.addMarkers([
      await _markerOptions(marker),
    ])).single;
    if (added == null) throw StateError('Failed to add marker ${marker.id}');
    _markers[marker.id] = added;
    _semanticMarkerIds[added.markerId] = marker.id;
  }

  @override
  Future<void> updateMarker(TripMapMarker marker) async {
    final current = _markers[marker.id];
    if (current == null) return addMarker(marker);
    final updated = (await _controller.updateMarkers([
      current.copyWith(options: await _markerOptions(marker)),
    ])).single;
    if (updated == null) {
      throw StateError('Failed to update marker ${marker.id}');
    }
    _semanticMarkerIds.remove(current.markerId);
    _markers[marker.id] = updated;
    _semanticMarkerIds[updated.markerId] = marker.id;
  }

  @override
  Future<void> removeMarker(String semanticId) async {
    final marker = _markers.remove(semanticId);
    if (marker == null) return;
    _semanticMarkerIds.remove(marker.markerId);
    await _controller.removeMarkers([marker]);
  }

  @override
  Future<void> addRoute(TripMapRoute route) async {
    final added = (await _controller.addPolylines([
      _polylineOptions(route),
    ])).single;
    if (added == null) throw StateError('Failed to add route ${route.id}');
    _routes[route.id] = added;
  }

  @override
  Future<void> updateRoute(TripMapRoute route) async {
    final current = _routes[route.id];
    if (current == null) return addRoute(route);
    final updated = (await _controller.updatePolylines([
      current.copyWith(options: _polylineOptions(route)),
    ])).single;
    if (updated == null) throw StateError('Failed to update route ${route.id}');
    _routes[route.id] = updated;
  }

  @override
  Future<void> removeRoute(String semanticId) async {
    final route = _routes.remove(semanticId);
    if (route != null) await _controller.removePolylines([route]);
  }

  Future<nav.MarkerOptions> _markerOptions(TripMapMarker marker) async =>
      nav.MarkerOptions(
        position: _toNative(marker.point),
        consumeTapEvents: true,
        zIndex: marker.zIndex.toDouble(),
        icon: await iconFor(marker),
        infoWindow: marker.title == null && marker.snippet == null
            ? nav.InfoWindow.noInfo
            : nav.InfoWindow(title: marker.title, snippet: marker.snippet),
      );

  nav.PolylineOptions _polylineOptions(TripMapRoute route) =>
      nav.PolylineOptions(
        points: [for (final point in route.points) _toNative(point)],
        strokeColor: route.color.withValues(alpha: route.opacity),
        strokeWidth: route.strokeWidth,
        strokePattern: route.dashed
            ? const [nav.DashPattern(length: 12), nav.GapPattern(length: 8)]
            : const [],
      );
}

nav.LatLng _toNative(TripMapPoint point) =>
    nav.LatLng(latitude: point.latitude, longitude: point.longitude);

TripMapPoint _fromNative(nav.LatLng point) =>
    TripMapPoint(point.latitude, point.longitude);

nav.MapType _mapType(TripMapTileStyle style) => switch (style) {
  TripMapTileStyle.roadmap => nav.MapType.normal,
  TripMapTileStyle.terrain => nav.MapType.terrain,
  TripMapTileStyle.satellite => nav.MapType.hybrid,
};

nav.MapColorScheme _mapColorScheme(Brightness brightness) =>
    brightness == Brightness.dark
    ? nav.MapColorScheme.dark
    : nav.MapColorScheme.light;
