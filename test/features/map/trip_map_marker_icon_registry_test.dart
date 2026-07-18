import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_style.dart';
import 'package:tripline/features/map/trip_map_marker_icon_registry.dart';

void main() {
  test('equivalent marker requests reuse one rendered bitmap future', () async {
    final registry = TripMapMarkerIconRegistry();
    final first = registry.bitmapFor(_marker(), pixelRatio: 2);
    final second = registry.bitmapFor(_marker(), pixelRatio: 2);

    expect(identical(first, second), isTrue);
    final bitmap = await first;
    expect(bitmap.pixelRatio, 2);
    expect(bitmap.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test(
    'glyph, style, color, and pixel ratio each invalidate the cache key',
    () {
      final registry = TripMapMarkerIconRegistry();
      final base = registry.bitmapFor(_marker(), pixelRatio: 2);

      expect(
        identical(base, registry.bitmapFor(_marker(glyph: '2'), pixelRatio: 2)),
        isFalse,
      );
      expect(
        identical(
          base,
          registry.bitmapFor(_marker(focused: true), pixelRatio: 2),
        ),
        isFalse,
      );
      expect(
        identical(
          base,
          registry.bitmapFor(_marker(color: Colors.red), pixelRatio: 2),
        ),
        isFalse,
      );
      expect(
        identical(base, registry.bitmapFor(_marker(), pixelRatio: 3)),
        isFalse,
      );
    },
  );
}

TripMapMarker _marker({
  String glyph = '1',
  Color color = Colors.blue,
  bool focused = false,
}) => TripMapMarker(
  id: 'marker',
  point: const TripMapPoint(25.033, 121.565),
  color: color,
  glyph: glyph,
  style: tripMapMarkerStyle(dayColor: color, isFocused: focused),
);
