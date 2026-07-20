import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/app_flow_fixture.dart';

class _ArtifactState {
  const _ArtifactState({
    required this.brightness,
    this.textScale = 1,
    this.reduceMotion = false,
    this.reduceTransparency = false,
  });

  final Brightness brightness;
  final double textScale;
  final bool reduceMotion;
  final bool reduceTransparency;

  String get suffix {
    final appearance = brightness == Brightness.dark ? 'dark' : 'light';
    final text = textScale == 1 ? 'text100' : 'text200';
    final motion = reduceMotion ? 'motion-reduced' : 'motion-full';
    final transparency = reduceTransparency
        ? 'transparency-reduced'
        : 'transparency-glass';
    return 'widget-$appearance-$text-$motion-$transparency';
  }
}

const _artifactStates = [
  _ArtifactState(brightness: Brightness.light),
  _ArtifactState(brightness: Brightness.dark),
  _ArtifactState(brightness: Brightness.light, textScale: 2),
  _ArtifactState(brightness: Brightness.dark, textScale: 2),
  _ArtifactState(
    brightness: Brightness.light,
    reduceMotion: true,
    reduceTransparency: true,
  ),
  _ArtifactState(
    brightness: Brightness.dark,
    reduceMotion: true,
    reduceTransparency: true,
  ),
];

void main() {
  testWidgets('release flow writes named product-state screenshots', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final boundaryKey = GlobalKey();
    final output = Directory('build/test-artifacts/app-owned');
    if (output.existsSync()) output.deleteSync(recursive: true);
    output.createSync(recursive: true);

    const expected = {
      'welcome',
      'chat',
      'itinerary',
      'map-tripline-poi',
      'map-native-google-poi',
      'favorites',
      'trip-picker',
      'account',
      'form',
      'destructive-confirm',
    };
    for (final state in _artifactStates) {
      tester.platformDispatcher.platformBrightnessTestValue = state.brightness;
      tester.platformDispatcher.textScaleFactorTestValue = state.textScale;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(
            disableAnimations: state.reduceMotion,
            reduceMotion: state.reduceMotion,
            highContrast: state.reduceTransparency,
          );

      await runAppOwnedReleaseFlow(
        tester,
        appWrapper: (child) => RepaintBoundary(key: boundaryKey, child: child),
        capture: (name) async {
          await tester.pump();
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final layer = boundary.debugLayer! as OffsetLayer;
            final image = await layer.toImage(boundary.paintBounds);
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '${output.path}/$name-${state.suffix}.png',
              ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
            } finally {
              image.dispose();
            }
          });
        },
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    final files = output.listSync().whereType<File>().toList();
    for (final state in _artifactStates) {
      for (final name in expected) {
        expect(
          files.map((file) => file.uri.pathSegments.last),
          contains('$name-${state.suffix}.png'),
        );
      }
    }
    expect(files, hasLength(expected.length * _artifactStates.length));
    expect(
      files,
      everyElement(predicate<File>((file) => file.lengthSync() > 1000)),
    );
  });
}
