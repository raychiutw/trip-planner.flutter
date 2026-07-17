import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_style.dart';

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
    this.opacity = 1,
    this.dashed = false,
  });

  final String id;
  final List<TripMapPoint> points;
  final Color color;
  final double strokeWidth;
  final double opacity;

  /// 虛線：色盲使用者靠線型（而非只靠顏色）區分不同天。
  final bool dashed;
}

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

  /// 該 marker 的識別色（無 [style] 時用於原生 pin 的色相）。
  final Color color;

  /// 給定且有 [glyph] 時畫成白底圓形數字 chip；否則用原生 pin（如使用者定位）。
  final TripMapMarkerStyle? style;
  final String? title;
  final String? snippet;
  final VoidCallback? onTap;
  final int zIndex;
  final bool clusterable;
  final String? glyph;
}

class GoogleTripMapController {
  GoogleMapController? _controller;

  /// 系統開啟「減少動態效果」時設為 true → 鏡頭直接跳,不平移。
  ///
  /// 不能像其他動畫那樣走 `TpMotion.resolve` 把 duration 歸零 —— `animateCamera`
  /// 根本沒有 duration 參數,唯一的「零時間」選項就是換成 `moveCamera`。而鏡頭
  /// 平移正是最容易誘發動暈的動作,開這個設定的人多半就是為了避免它。
  ///
  /// 由 [GoogleTripMapCanvas] 在 build 時依 `MediaQuery.disableAnimationsOf`
  /// 同步,呼叫端不需各自處理。
  bool reduceMotion = false;

  void attach(GoogleMapController controller) {
    _controller?.dispose();
    _controller = controller;
  }

  Future<void> _applyCamera(
    GoogleMapController controller,
    CameraUpdate update,
  ) => reduceMotion
      ? controller.moveCamera(update)
      : controller.animateCamera(update);

  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required EdgeInsets padding,
    double? maxZoom,
  }) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      await _applyCamera(
        controller,
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
    await _applyCamera(
      controller,
      CameraUpdate.newLatLngBounds(bounds, edgePadding),
    );
    if (maxZoom != null) {
      final zoom = await controller.getZoomLevel();
      if (zoom > maxZoom) {
        await _applyCamera(controller, CameraUpdate.zoomTo(maxZoom));
      }
    }
  }

  Future<void> move(TripMapPoint point, double zoom) async {
    final controller = _controller;
    if (controller == null) return;
    await _applyCamera(
      controller,
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

/// chip 圖快取鍵：同標籤 + 同樣式 + 同像素密度只算一次圖。
@immutable
class _ChipKey {
  const _ChipKey(this.label, this.style, this.pixelRatio);

  final String label;
  final TripMapMarkerStyle style;
  final double pixelRatio;

  @override
  bool operator ==(Object other) {
    return other is _ChipKey &&
        other.label == label &&
        other.style == style &&
        other.pixelRatio == pixelRatio;
  }

  @override
  int get hashCode => Object.hash(label, style, pixelRatio);
}

class GoogleTripMapCanvas extends StatefulWidget {
  const GoogleTripMapCanvas({super.key, required this.config});

  final TripMapCanvasConfig config;

  @override
  State<GoogleTripMapCanvas> createState() => _GoogleTripMapCanvasState();
}

class _GoogleTripMapCanvasState extends State<GoogleTripMapCanvas> {
  /// 都心 marker 密集重疊時每顆重畫會掉幀，同樣式的 chip 只算一次。
  final Map<_ChipKey, BitmapDescriptor> _chipCache = {};
  double _pixelRatio = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pixelRatio = MediaQuery.devicePixelRatioOf(context);
    unawaited(_renderMissingChips());
  }

  @override
  void didUpdateWidget(covariant GoogleTripMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_renderMissingChips());
  }

  Iterable<_ChipKey> get _requiredChips sync* {
    for (final marker in widget.config.markers) {
      final style = marker.style;
      final glyph = marker.glyph;
      if (style != null && glyph != null) {
        yield _ChipKey(glyph, style, _pixelRatio);
      }
    }
  }

  Future<void> _renderMissingChips() async {
    final missing = {
      for (final key in _requiredChips)
        if (!_chipCache.containsKey(key)) key,
    };
    if (missing.isEmpty) return;
    for (final key in missing) {
      _chipCache[key] = await renderTripMapChip(
        key.label,
        key.style,
        pixelRatio: key.pixelRatio,
      );
    }
    if (mounted) setState(() {});
  }

  /// chip 圖還沒算完時先用原生 pin 佔位（同日別色），算完 setState 換上。
  BitmapDescriptor _iconFor(TripMapMarker marker) {
    final style = marker.style;
    final glyph = marker.glyph;
    if (style != null && glyph != null) {
      final chip = _chipCache[_ChipKey(glyph, style, _pixelRatio)];
      if (chip != null) return chip;
    }
    return BitmapDescriptor.defaultMarkerWithHue(
      HSVColor.fromColor(marker.color).hue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    // 在 build 同步而非只在 initState:使用者可能在 app 執行中才打開「減少動態
    // 效果」,MediaQuery 變動會觸發 rebuild,這裡跟著更新才不會停在舊值。
    config.controller.reduceMotion = MediaQuery.disableAnimationsOf(context);
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
            icon: _iconFor(marker),
            infoWindow: marker.title == null && marker.snippet == null
                ? InfoWindow.noText
                : InfoWindow(title: marker.title, snippet: marker.snippet),
          ),
      },
      polylines: {
        for (final route in config.routes)
          Polyline(
            polylineId: PolylineId(route.id),
            points: [for (final point in route.points) point.toGoogleLatLng()],
            color: route.color.withValues(alpha: route.opacity),
            width: route.strokeWidth.round(),
            patterns: route.dashed
                ? [PatternItem.dash(12), PatternItem.gap(8)]
                : const [],
          ),
      },
    );
  }
}

/// 把數字 chip 畫成點陣圖給原生 marker 用：白底圓形、日別色外圈 + 中央數字，
/// 外側再加一圈半透明黑做分離。
///
/// 那圈黑不是裝飾 —— marker 在都心密集重疊時（見沖繩那覇都心）沒有它會糊成一團
/// 認不出邊界，這是 web 從 production 使用者回饋學到的（見 mapHelpers.markerContent）。
///
/// 抽成頂層函式讓繪圖邏輯可獨立於原生 GoogleMap 測試。
Future<BitmapDescriptor> renderTripMapChip(
  String label,
  TripMapMarkerStyle style, {
  required double pixelRatio,
}) async {
  const shadowRing = 3.0;
  final canvasSize = (style.diameter + shadowRing * 2) * pixelRatio;
  final center = Offset(canvasSize / 2, canvasSize / 2);
  final borderWidth = style.borderWidth * pixelRatio;
  final radius = style.diameter * pixelRatio / 2 - borderWidth / 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawCircle(
    center,
    radius + borderWidth / 2 + shadowRing * pixelRatio,
    Paint()..color = const Color(0x2E000000),
  );
  canvas.drawCircle(center, radius, Paint()..color = style.fill);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = style.stroke,
  );

  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: style.text,
        fontSize: style.fontSize * pixelRatio,
        fontWeight: FontWeight.w700,
        height: 1,
        letterSpacing: 0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));

  final image = await recorder.endRecording().toImage(
    canvasSize.ceil(),
    canvasSize.ceil(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    imagePixelRatio: pixelRatio,
  );
}
