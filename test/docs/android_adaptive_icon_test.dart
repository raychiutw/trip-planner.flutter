import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';
const _densities = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

// 守門：Android adaptive icon（#571）。底層色必須與 iOS 同一個 tint #8A6038。
void main() {
  final xml = File('$_res/mipmap-anydpi-v26/ic_launcher.xml');

  test('adaptive-icon 宣告 background、foreground、monochrome', () {
    expect(xml.existsSync(), isTrue);
    final s = xml.readAsStringSync();
    expect(s, contains('<adaptive-icon'));
    expect(
      s,
      contains('<background android:drawable="@color/ic_launcher_background"'),
    );
    expect(
      s,
      contains('<foreground android:drawable="@mipmap/ic_launcher_foreground"'),
    );
    expect(
      s,
      contains('<monochrome android:drawable="@mipmap/ic_launcher_monochrome"'),
    );
  });

  test('底層色是 tint #8A6038', () {
    final colors = File('$_res/values/ic_launcher_background.xml');
    expect(colors.existsSync(), isTrue);
    expect(
      colors.readAsStringSync(),
      matches(
        RegExp(
          r'name="ic_launcher_background">#FF8A6038</color>',
          caseSensitive: false,
        ),
      ),
    );
  });

  testWidgets('前景與 monochrome 五密度存在、透明底、圖形在 66dp 安全區內', (tester) async {
    await tester.runAsync(() async {
      for (final layer in [
        'ic_launcher_foreground',
        'ic_launcher_monochrome',
      ]) {
        for (final e in _densities.entries) {
          final f = File('$_res/mipmap-${e.key}/$layer.png');
          expect(f.existsSync(), isTrue, reason: '$layer ${e.key}');
          final img = (await (await ui.instantiateImageCodec(
            f.readAsBytesSync(),
          )).getNextFrame()).image;
          expect(img.width, e.value, reason: '$layer ${e.key} 尺寸');
          final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final c = e.value / 2;
          final limit = c * 66 / 108; // 安全區半徑 33dp
          var opaque = 0;
          var maxR = 0.0;
          for (var y = 0; y < img.height; y++) {
            for (var x = 0; x < img.width; x++) {
              if (d.getUint8((y * img.width + x) * 4 + 3) > 8) {
                opaque++;
                maxR = math.max(
                  maxR,
                  math.sqrt(math.pow(x + .5 - c, 2) + math.pow(y + .5 - c, 2)),
                );
              }
            }
          }
          expect(d.getUint8(3), 0, reason: '$layer ${e.key} 角落透明');
          expect(
            opaque,
            greaterThan(e.value * e.value ~/ 40),
            reason: '$layer ${e.key} 有圖形',
          );
          expect(
            maxR,
            lessThanOrEqualTo(limit),
            reason: '$layer ${e.key} 超出安全區',
          );
        }
      }
    });
  });
}
