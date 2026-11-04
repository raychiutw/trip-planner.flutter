import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _tint = 0x8A6038;

/// 回傳 (x, y) 像素的 0xRRGGBB。
Future<int> _pixel(String path, int x, int y) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * image.width + x) * 4;
  return (data.getUint8(i) << 16) |
      (data.getUint8(i + 1) << 8) |
      data.getUint8(i + 2);
}

String _hex(int v) => '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  // 守門：App icon 的品牌色只能是單一 tint #8A6038（GLOSSARY「tint」）。
  testWidgets('iOS Default 底色與 Dark 圖形色是 tint', (tester) async {
    await tester.runAsync(() async {
      final bg = await _pixel('$_ios/Icon-App-1024x1024@1x.png', 2, 2);
      final ring = await _pixel(
        '$_ios/Icon-App-1024x1024-dark@1x.png',
        210,
        420,
      );
      expect(_hex(bg), _hex(_tint), reason: 'Default 底色');
      expect(_hex(ring), _hex(_tint), reason: 'Dark 圖形色');
    });
  });

  testWidgets('Android 五種密度底色是 tint', (tester) async {
    await tester.runAsync(() async {
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        final bg = await _pixel(
          'android/app/src/main/res/mipmap-$d/ic_launcher.png',
          1,
          1,
        );
        expect(_hex(bg), _hex(_tint), reason: d);
      }
    });
  });
}
