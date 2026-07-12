import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 地圖套件無關的座標值物件(lat/lng)。
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

/// google_maps_flutter 版地圖抽象。放獨立檔避免與 google 的 `LatLng` 於呼叫端
/// 命名衝突(呼叫端只碰 [TripMapPoint])。
LatLng _toGoogle(TripMapPoint p) => LatLng(p.latitude, p.longitude);

/// 地圖 marker:圖示須為預先 resolve 的 [BitmapDescriptor](Google Marker 不吃
/// 任意 Widget,見 marker_bitmap.dart)。
class TripMapBitmapMarker {
  const TripMapBitmapMarker({
    required this.id,
    required this.point,
    required this.icon,
    required this.label,
    this.onTap,
    this.anchor = const Offset(0.5, 0.5),
    this.zIndex = 0,
  });

  final String id;
  final TripMapPoint point;
  final BitmapDescriptor icon;
  final String label;
  final VoidCallback? onTap;
  final Offset anchor;
  final double zIndex;
}

/// 路線折線(C2 polyline 用)。Google Polyline 無 border → C2 以兩條疊放模擬。
class TripMapPolyline {
  const TripMapPolyline({
    required this.id,
    required this.points,
    required this.color,
    this.width = 4,
    this.dashed = false,
    this.zIndex = 0,
  });

  final String id;
  final List<TripMapPoint> points;
  final Color color;
  final double width;
  final bool dashed;
  final double zIndex;
}

enum TripMapType { normal, satellite, hybrid }

MapType _toGoogleMapType(TripMapType t) => switch (t) {
  TripMapType.normal => MapType.normal,
  TripMapType.satellite => MapType.satellite,
  TripMapType.hybrid => MapType.hybrid,
};

/// 由點集合算出可涵蓋全部的 [LatLngBounds](單點會 southwest==northeast)。
LatLngBounds tripMapBounds(List<TripMapPoint> points) {
  assert(points.isNotEmpty);
  var minLat = points.first.latitude, maxLat = points.first.latitude;
  var minLng = points.first.longitude, maxLng = points.first.longitude;
  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

/// 地圖控制器:包 [GoogleMapController]。map 未 layout 前呼叫 fit/move 會 throw,
/// 故以 [Completer] 做 ready gate — 未 ready 時 await 到 ready 後再執行。
class GoogleTripMapController {
  final Completer<GoogleMapController> _ready =
      Completer<GoogleMapController>();

  bool get isReady => _ready.isCompleted;

  void attach(GoogleMapController controller) {
    if (!_ready.isCompleted) _ready.complete(controller);
  }

  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required EdgeInsets padding,
    double? maxZoom,
  }) async {
    if (points.isEmpty) return;
    final controller = await _ready.future;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_toGoogle(points.first), maxZoom ?? 15),
      );
      return;
    }
    // Google 只吃單一 padding 值 → 取四邊最大。
    final pad = [
      padding.left,
      padding.right,
      padding.top,
      padding.bottom,
    ].reduce((a, b) => a > b ? a : b);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(tripMapBounds(points), pad),
    );
  }

  Future<void> move(TripMapPoint point, double zoom) async {
    final controller = await _ready.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(_toGoogle(point), zoom),
    );
  }

  void dispose() {
    if (_ready.isCompleted) {
      _ready.future.then((controller) => controller.dispose());
    }
  }
}

/// GoogleMap 畫布。markers/polylines 由呼叫端預先組好(bitmap 已 resolve)。
class GoogleMapCanvas extends StatelessWidget {
  const GoogleMapCanvas({
    super.key,
    required this.controller,
    required this.initialFitPoints,
    this.initialPadding = const EdgeInsets.all(32),
    this.initialMaxZoom,
    this.markers = const [],
    this.polylines = const [],
    this.mapType = TripMapType.normal,
    this.onMapReady,
    this.onTap,
  });

  final GoogleTripMapController controller;
  final List<TripMapPoint> initialFitPoints;
  final EdgeInsets initialPadding;
  final double? initialMaxZoom;
  final List<TripMapBitmapMarker> markers;
  final List<TripMapPolyline> polylines;
  final TripMapType mapType;
  final VoidCallback? onMapReady;
  final void Function(TripMapPoint point)? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = initialFitPoints.isEmpty
        ? const CameraPosition(target: LatLng(0, 0), zoom: 2)
        : CameraPosition(target: _toGoogle(initialFitPoints.first), zoom: 12);
    final onTapCallback = onTap;

    return GoogleMap(
      initialCameraPosition: initial,
      mapType: _toGoogleMapType(mapType),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        for (final m in markers)
          Marker(
            markerId: MarkerId(m.id),
            position: _toGoogle(m.point),
            icon: m.icon,
            infoWindow: InfoWindow(title: m.label),
            anchor: m.anchor,
            zIndexInt: m.zIndex.round(),
            onTap: m.onTap,
            consumeTapEvents: m.onTap != null,
          ),
      },
      polylines: {
        for (final p in polylines)
          Polyline(
            polylineId: PolylineId(p.id),
            points: [for (final point in p.points) _toGoogle(point)],
            color: p.color,
            width: p.width.round(),
            zIndex: p.zIndex.round(),
            patterns: p.dashed
                ? [PatternItem.dash(20), PatternItem.gap(10)]
                : const [],
          ),
      },
      onMapCreated: (googleController) {
        controller.attach(googleController);
        onMapReady?.call();
        if (initialFitPoints.length > 1) {
          controller.fitPoints(
            initialFitPoints,
            padding: initialPadding,
            maxZoom: initialMaxZoom,
          );
        }
      },
      onTap: onTapCallback == null
          ? null
          : (pos) => onTapCallback(TripMapPoint(pos.latitude, pos.longitude)),
    );
  }
}
