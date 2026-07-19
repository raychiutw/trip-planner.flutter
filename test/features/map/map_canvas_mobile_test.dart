import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:tripline/features/map/map_canvas_mobile.dart';

void main() {
  test('trip map remains light in both app appearances', () {
    expect(tripMapColorScheme(Brightness.light), nav.MapColorScheme.light);
    expect(tripMapColorScheme(Brightness.dark), nav.MapColorScheme.light);
  });
}
