import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 地圖 SDK 無關的座標值物件。
class TripMapPoint {
  const TripMapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  LatLng toGoogleLatLng() => LatLng(latitude, longitude);

  static TripMapPoint fromGoogleLatLng(LatLng point) {
    return TripMapPoint(point.latitude, point.longitude);
  }

  @override
  bool operator ==(Object other) {
    return other is TripMapPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

enum TripMapTileStyle { roadmap, terrain, satellite }

class TripMapTilePreset {
  const TripMapTilePreset({
    required this.style,
    required this.label,
    required this.mapType,
  });

  final TripMapTileStyle style;
  final String label;
  final MapType mapType;
}

const List<TripMapTilePreset> kTripMapTilePresets = [
  TripMapTilePreset(
    style: TripMapTileStyle.roadmap,
    label: '路線圖',
    mapType: MapType.normal,
  ),
  TripMapTilePreset(
    style: TripMapTileStyle.terrain,
    label: '地形',
    mapType: MapType.terrain,
  ),
  TripMapTilePreset(
    style: TripMapTileStyle.satellite,
    label: '衛星',
    mapType: MapType.hybrid,
  ),
];

typedef TripMapTapCallback = void Function(TripMapPoint point);
typedef TripMapCanvasBuilder = Widget Function(TripMapCanvasConfig config);

const _tripClusterManagerId = ClusterManagerId('trip-stops');

class TripMapRoute {
  const TripMapRoute({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.borderColor,
    this.borderStrokeWidth = 0,
  });

  final String id;
  final List<TripMapPoint> points;
  final Color color;
  final double strokeWidth;
  final Color? borderColor;
  final double borderStrokeWidth;
}

class TripMapMarker {
  const TripMapMarker({
    required this.id,
    required this.point,
    required this.color,
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
  final String? title;
  final String? snippet;
  final VoidCallback? onTap;
  final int zIndex;
  final bool clusterable;
  final String? glyph;
}

class GoogleTripMapController {
  GoogleMapController? _controller;

  void attach(GoogleMapController controller) {
    _controller?.dispose();
    _controller = controller;
  }

  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required EdgeInsets padding,
    double? maxZoom,
  }) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          points.single.toGoogleLatLng(),
          maxZoom ?? 16,
        ),
      );
      return;
    }
    final bounds = _boundsFor(points);
    final edgePadding = [
      padding.left,
      padding.top,
      padding.right,
      padding.bottom,
    ].reduce((a, b) => a > b ? a : b);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, edgePadding),
    );
    if (maxZoom != null) {
      final zoom = await controller.getZoomLevel();
      if (zoom > maxZoom) {
        await controller.animateCamera(CameraUpdate.zoomTo(maxZoom));
      }
    }
  }

  Future<void> move(TripMapPoint point, double zoom) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(point.toGoogleLatLng(), zoom),
    );
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }

  LatLngBounds _boundsFor(List<TripMapPoint> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

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
    this.onTap,
    this.mapKey = const ValueKey('google-trip-map-canvas'),
  });

  final GoogleTripMapController controller;
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
  final TripMapTapCallback? onTap;
  final Key mapKey;
}

Widget buildTripMapCanvas(
  TripMapCanvasConfig config, {
  TripMapCanvasBuilder? builder,
}) {
  return builder?.call(config) ?? GoogleTripMapCanvas(config: config);
}

class GoogleTripMapCanvas extends StatelessWidget {
  const GoogleTripMapCanvas({super.key, required this.config});

  final TripMapCanvasConfig config;

  @override
  Widget build(BuildContext context) {
    final initialTarget =
        config.initialCenter ??
        (config.initialFitPoints.isEmpty
            ? const TripMapPoint(25.033, 121.5654)
            : config.initialFitPoints.first);
    return GoogleMap(
      key: config.mapKey,
      initialCameraPosition: CameraPosition(
        target: initialTarget.toGoogleLatLng(),
        zoom: config.initialZoom,
      ),
      mapType: config.tilePreset.mapType,
      compassEnabled: true,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      padding: config.initialPadding,
      onTap: config.onTap == null
          ? null
          : (point) => config.onTap!(TripMapPoint.fromGoogleLatLng(point)),
      onMapCreated: (controller) {
        config.controller.attach(controller);
        unawaited(
          config.controller.fitPoints(
            config.initialFitPoints,
            padding: config.initialPadding,
            maxZoom: config.initialMaxZoom,
          ),
        );
        config.onMapReady?.call();
      },
      clusterManagers: config.clusterMarkers
          ? {const ClusterManager(clusterManagerId: _tripClusterManagerId)}
          : const <ClusterManager>{},
      markers: {
        for (final marker in config.markers)
          Marker(
            markerId: MarkerId(marker.id),
            position: marker.point.toGoogleLatLng(),
            consumeTapEvents: marker.onTap != null,
            onTap: marker.onTap,
            zIndexInt: marker.zIndex,
            clusterManagerId: config.clusterMarkers && marker.clusterable
                ? _tripClusterManagerId
                : null,
            icon: marker.glyph == null
                ? BitmapDescriptor.defaultMarkerWithHue(
                    HSVColor.fromColor(marker.color).hue,
                  )
                : BitmapDescriptor.pinConfig(
                    backgroundColor: marker.color,
                    glyph: TextGlyph(
                      text: marker.glyph!,
                      textColor: Colors.white,
                    ),
                  ),
            infoWindow: marker.title == null && marker.snippet == null
                ? InfoWindow.noText
                : InfoWindow(title: marker.title, snippet: marker.snippet),
          ),
      },
      polylines: {
        for (final route in config.routes) ...{
          if (route.borderColor != null && route.borderStrokeWidth > 0)
            Polyline(
              polylineId: PolylineId('${route.id}-border'),
              points: [
                for (final point in route.points) point.toGoogleLatLng(),
              ],
              color: route.borderColor!,
              width: (route.strokeWidth + route.borderStrokeWidth * 2).round(),
              zIndex: 0,
            ),
          Polyline(
            polylineId: PolylineId(route.id),
            points: [for (final point in route.points) point.toGoogleLatLng()],
            color: route.color,
            width: route.strokeWidth.round(),
            zIndex: 1,
          ),
        },
      },
    );
  }
}
