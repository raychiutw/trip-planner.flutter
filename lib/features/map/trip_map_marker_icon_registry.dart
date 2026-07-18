import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'map_adapter.dart';
import 'map_style.dart';

class TripMapMarkerBitmap {
  const TripMapMarkerBitmap(this.bytes, this.pixelRatio);

  final Uint8List bytes;
  final double pixelRatio;
}

class TripMapMarkerIconRegistry {
  final Map<_MarkerBitmapKey, Future<TripMapMarkerBitmap>> _cache = {};

  Future<TripMapMarkerBitmap> bitmapFor(
    TripMapMarker marker, {
    required double pixelRatio,
  }) => _cache.putIfAbsent(
    _MarkerBitmapKey(marker.glyph, marker.style, marker.color, pixelRatio),
    () => _render(marker, pixelRatio),
  );

  Future<TripMapMarkerBitmap> _render(
    TripMapMarker marker,
    double pixelRatio,
  ) async {
    final style = marker.style;
    final diameter = (style?.diameter ?? 20) * pixelRatio;
    const shadowRing = 3.0;
    final canvasSize = diameter + shadowRing * 2 * pixelRatio;
    final center = Offset(canvasSize / 2, canvasSize / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      center,
      diameter / 2 + shadowRing * pixelRatio,
      Paint()..color = const Color(0x2E000000),
    );
    canvas.drawCircle(
      center,
      diameter / 2,
      Paint()..color = style?.fill ?? marker.color,
    );
    canvas.drawCircle(
      center,
      diameter / 2 - (style?.borderWidth ?? 2) * pixelRatio / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (style?.borderWidth ?? 2) * pixelRatio
        ..color = style?.stroke ?? Colors.white,
    );

    final glyph = marker.glyph;
    if (glyph != null && glyph.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: glyph,
          style: TextStyle(
            color: style?.text ?? Colors.white,
            fontSize: (style?.fontSize ?? 11) * pixelRatio,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final image = await recorder.endRecording().toImage(
      canvasSize.ceil(),
      canvasSize.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return TripMapMarkerBitmap(data!.buffer.asUint8List(), pixelRatio);
  }
}

class _MarkerBitmapKey {
  const _MarkerBitmapKey(this.glyph, this.style, this.color, this.pixelRatio);

  final String? glyph;
  final TripMapMarkerStyle? style;
  final Color color;
  final double pixelRatio;

  @override
  bool operator ==(Object other) =>
      other is _MarkerBitmapKey &&
      other.glyph == glyph &&
      other.style == style &&
      other.color == color &&
      other.pixelRatio == pixelRatio;

  @override
  int get hashCode => Object.hash(glyph, style, color, pixelRatio);
}
