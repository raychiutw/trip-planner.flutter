import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 畫「彩色實心圓 + 白邊 + 置中白數字」pin,回傳 PNG bytes。
///
/// Google [Marker] 只吃 [BitmapDescriptor],不能放任意 Widget → 用 Canvas 畫成點陣圖。
/// 依 [devicePixelRatio] 放大繪製尺寸,避免 retina 上糊。
Future<Uint8List> paintNumberedPinPng({
  required Color color,
  required int number,
  required double devicePixelRatio,
  bool focused = false,
  Color borderColor = Colors.white,
}) async {
  final logical = focused ? 40.0 : 32.0;
  final size = logical * devicePixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  final border = 2.0 * devicePixelRatio;
  final radius = size / 2 - border / 2;

  canvas.drawCircle(center, radius, Paint()..color = color);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = border,
  );

  final painter = TextPainter(
    text: TextSpan(
      text: '$number',
      style: TextStyle(
        color: borderColor,
        fontSize: 13 * devicePixelRatio,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );

  final image = await recorder.endRecording().toImage(size.ceil(), size.ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// 以 (color, number, focused) 快取 [BitmapDescriptor],避免每 frame 重繪。
class PinBitmapCache {
  final Map<String, BitmapDescriptor> _cache = {};

  Future<BitmapDescriptor> resolve({
    required Color color,
    required int number,
    required double devicePixelRatio,
    bool focused = false,
  }) async {
    final key = '${color.toARGB32()}-$number-$focused';
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = await paintNumberedPinPng(
      color: color,
      number: number,
      devicePixelRatio: devicePixelRatio,
      focused: focused,
    );
    final descriptor = BitmapDescriptor.bytes(bytes);
    _cache[key] = descriptor;
    return descriptor;
  }
}
