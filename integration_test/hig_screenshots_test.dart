/// 擷圖驗證（#415–#430 的 HIG 修補），淺色／深色各拍一輪，存成 PNG。
///
/// 全程走 mock repository（見 support/hig_screenshot_scenes.dart），不碰 prod，
/// 也不用鍵盤輸入。深淺色只走 App 的 `themeModeProvider`，並在測試內比對同一情境
/// 兩張圖，深色必須與淺色不同（bytes 不同、像素差異達門檻、平均亮度下降）。
///
/// 執行：
/// ```
/// flutter test integration_test/hig_screenshots_test.dart -d <UDID> \
///   --dart-define=HIG_SHOT_DIR=$PWD/docs/qa/2026-10-hig-screenshots
/// ```
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/hig_screenshot_scenes.dart';

const _shotDir = String.fromEnvironment('HIG_SHOT_DIR');
const _only = String.fromEnvironment('HIG_ONLY');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HIG 修補截圖：淺色與深色各一輪', (tester) async {
    final root = Directory(
      _shotDir.isNotEmpty ? _shotDir : '${Directory.systemTemp.path}/hig',
    );
    final failures = <String>[];
    final report = <String>[];

    Future<Uint8List> shoot(String mode, String name) async {
      await tester.pump(const Duration(milliseconds: 200));
      final bytes = Uint8List.fromList(
        await binding.takeScreenshot('$mode-$name'),
      );
      binding.reportData = null; // 不累積 base64 報表
      final file = File('${root.path}/$mode/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return bytes;
    }

    Future<void> pair(
      String name,
      Future<void> Function(ThemeMode mode, HigCapture cap) run,
    ) async {
      Uint8List? light;
      Uint8List? dark;
      try {
        await run(
          ThemeMode.light,
          (_) async => light = await shoot('light', name),
        );
        await run(
          ThemeMode.dark,
          (_) async => dark = await shoot('dark', name),
        );
      } on Object catch (e) {
        failures.add('$name: 畫面跑不到定位 → ${'$e'.split('\n').first}');
        return;
      }
      final l = light;
      final d = dark;
      if (l == null || d == null) {
        failures.add('$name: 沒有產生截圖');
        return;
      }
      final stats = await _compare(l, d);
      final same = _equal(l, d);
      report.add(
        'HIGSHOT\t$name\tbytesEqual=$same'
        '\tlumLight=${stats.lightLum.toStringAsFixed(1)}'
        '\tlumDark=${stats.darkLum.toStringAsFixed(1)}'
        '\tdiffPixels=${(stats.diffRatio * 100).toStringAsFixed(1)}%',
      );
      if (same) failures.add('$name: 深淺 bytes 完全相同');
      if (stats.diffRatio < 0.05) {
        failures.add(
          '$name: 深淺像素差異只有 ${(stats.diffRatio * 100).toStringAsFixed(1)}%',
        );
      }
      if (stats.darkLum >= stats.lightLum) {
        failures.add('$name: 深色平均亮度沒有比淺色低');
      }
    }

    for (final scene in higScenes()) {
      if (_only.isNotEmpty && !scene.name.contains(_only)) continue;
      await pair(
        scene.name,
        (mode, cap) => runHigScene(tester, scene, mode, cap),
      );
    }
    if (_only.isEmpty || 'components'.contains(_only)) {
      await pair(
        'components',
        (mode, cap) => runHigComponentsScene(tester, mode, cap),
      );
      await pair(
        'ax-components-2x',
        (mode, cap) => runHigComponentsScene(
          tester,
          mode,
          cap,
          name: 'ax-components-2x',
          textScale: 2.0,
        ),
      );
    }

    await File(
      '${root.path}/report.tsv',
    ).writeAsString('${report.join('\n')}\n');
    for (final line in report) {
      debugPrint(line);
    }
    for (final f in failures) {
      debugPrint('HIGFAIL\t$f');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

bool _equal(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _Stats {
  _Stats(this.lightLum, this.darkLum, this.diffRatio);
  final double lightLum;
  final double darkLum;
  final double diffRatio;
}

Future<_Stats> _compare(Uint8List light, Uint8List dark) async {
  Future<(ByteData, int, int)> decode(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData();
    final result = (data!, image.width, image.height);
    image.dispose();
    codec.dispose();
    return result;
  }

  final (l, lw, lh) = await decode(light);
  final (d, dw, dh) = await decode(dark);
  final n = (lw == dw && lh == dh) ? lw * lh : 0;
  var lumL = 0.0;
  var lumD = 0.0;
  var diff = 0;
  var samples = 0;
  const step = 7; // 取樣即可，不必逐像素
  for (var i = 0; i < n; i += step) {
    final o = i * 4;
    double lum(ByteData b) =>
        0.2126 * b.getUint8(o) +
        0.7152 * b.getUint8(o + 1) +
        0.0722 * b.getUint8(o + 2);
    final a = lum(l);
    final b = lum(d);
    lumL += a;
    lumD += b;
    if ((a - b).abs() > 24) diff++;
    samples++;
  }
  if (samples == 0) return _Stats(0, 0, 0);
  return _Stats(lumL / samples, lumD / samples, diff / samples);
}
