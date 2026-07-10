import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 地圖套件無關的座標值物件。
class TripMapPoint {
  const TripMapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  LatLng toLatLng() => LatLng(latitude, longitude);

  static TripMapPoint fromLatLng(LatLng point) {
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
    required this.urlTemplate,
    required this.attribution,
  });

  final TripMapTileStyle style;
  final String label;
  final String urlTemplate;
  final String attribution;
}

const String kTripMapUserAgentPackageName = 'com.raychiu.tripline';

const List<TripMapTilePreset> kTripMapTilePresets = [
  TripMapTilePreset(
    style: TripMapTileStyle.roadmap,
    label: '路線圖',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: 'OpenStreetMap contributors',
  ),
  TripMapTilePreset(
    style: TripMapTileStyle.terrain,
    label: '地形',
    urlTemplate: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: 'OpenTopoMap, OpenStreetMap contributors',
  ),
  TripMapTilePreset(
    style: TripMapTileStyle.satellite,
    label: '衛星',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Esri, OpenStreetMap contributors',
  ),
];

typedef TripMapTileProvider = TileProvider;
typedef TripMapTapCallback = void Function(TripMapPoint point);

class TripMapRoute {
  const TripMapRoute({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.borderColor,
    this.borderStrokeWidth = 0,
  });

  final List<TripMapPoint> points;
  final Color color;
  final double strokeWidth;
  final Color? borderColor;
  final double borderStrokeWidth;
}

class TripMapMarker {
  const TripMapMarker({
    required this.point,
    required this.width,
    required this.height,
    required this.child,
  });

  final TripMapPoint point;
  final double width;
  final double height;
  final Widget child;
}

class FlutterTripMapController {
  final MapController _controller = MapController();

  void fitPoints(
    List<TripMapPoint> points, {
    required EdgeInsets padding,
    double? maxZoom,
  }) {
    if (points.isEmpty) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final point in points) point.toLatLng(),
        ]),
        padding: padding,
        maxZoom: maxZoom,
      ),
    );
  }

  void move(TripMapPoint point, double zoom) {
    _controller.move(point.toLatLng(), zoom);
  }

  void dispose() {
    _controller.dispose();
  }
}

class FlutterMapCanvas extends StatelessWidget {
  const FlutterMapCanvas({
    super.key,
    required this.controller,
    required this.tilePreset,
    required this.initialFitPoints,
    this.initialCenter,
    this.initialZoom = 14,
    this.initialPadding = const EdgeInsets.all(32),
    this.initialMaxZoom,
    this.tileProvider,
    this.routes = const [],
    this.markers = const [],
    this.onMapReady,
    this.onTap,
    this.tileLayerKey = const ValueKey('trip-map-canvas-tile-layer'),
    this.routeLayerKey = const ValueKey('trip-map-canvas-routes'),
  });

  final FlutterTripMapController controller;
  final TripMapTilePreset tilePreset;
  final List<TripMapPoint> initialFitPoints;
  final TripMapPoint? initialCenter;
  final double initialZoom;
  final EdgeInsets initialPadding;
  final double? initialMaxZoom;
  final TripMapTileProvider? tileProvider;
  final List<TripMapRoute> routes;
  final List<TripMapMarker> markers;
  final VoidCallback? onMapReady;
  final TripMapTapCallback? onTap;
  final Key tileLayerKey;
  final Key routeLayerKey;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller._controller,
      options: _mapOptions(),
      children: [
        TileLayer(
          key: tileLayerKey,
          urlTemplate: tilePreset.urlTemplate,
          userAgentPackageName: kTripMapUserAgentPackageName,
          tileProvider: tileProvider,
        ),
        if (routes.isNotEmpty)
          PolylineLayer<Object>(
            key: routeLayerKey,
            polylines: [
              for (final route in routes)
                Polyline<Object>(
                  points: [for (final point in route.points) point.toLatLng()],
                  color: route.color,
                  strokeWidth: route.strokeWidth,
                  borderColor: route.borderColor ?? Colors.transparent,
                  borderStrokeWidth: route.borderStrokeWidth,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final marker in markers)
              Marker(
                point: marker.point.toLatLng(),
                width: marker.width,
                height: marker.height,
                child: marker.child,
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution(tilePreset.attribution)],
        ),
      ],
    );
  }

  MapOptions _mapOptions() {
    final onTapCallback = onTap;
    final fitPoints = initialFitPoints;
    if (fitPoints.isNotEmpty) {
      return MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            for (final point in fitPoints) point.toLatLng(),
          ]),
          padding: initialPadding,
          maxZoom: initialMaxZoom,
        ),
        onMapReady: onMapReady,
        onTap: onTapCallback == null
            ? null
            : (_, point) => onTapCallback(TripMapPoint.fromLatLng(point)),
      );
    }

    return MapOptions(
      initialCenter: initialCenter?.toLatLng() ?? const LatLng(0, 0),
      initialZoom: initialZoom,
      onMapReady: onMapReady,
      onTap: onTapCallback == null
          ? null
          : (_, point) => onTapCallback(TripMapPoint.fromLatLng(point)),
    );
  }
}
