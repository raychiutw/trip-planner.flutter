import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/accessibility_scope.dart';

import '../../integration_test/support/app_flow_fixture.dart';

class _ArtifactState {
  const _ArtifactState({
    required this.layout,
    required this.size,
    required this.brightness,
    this.textScale = 1,
    this.reduceMotion = false,
    this.increasedContrast = false,
    this.reduceTransparency = false,
  });

  final String layout;
  final ui.Size size;
  final Brightness brightness;
  final double textScale;
  final bool reduceMotion;
  final bool increasedContrast;
  final bool reduceTransparency;

  String get suffix {
    final appearance = brightness == Brightness.dark ? 'dark' : 'light';
    final text = textScale == 1 ? 'text100' : 'text300';
    final motion = reduceMotion ? 'motion-reduced' : 'motion-full';
    final contrast = increasedContrast
        ? 'contrast-increased'
        : 'contrast-normal';
    final transparency = reduceTransparency
        ? 'transparency-reduced'
        : 'transparency-normal';
    return '$layout-$appearance-$text-$motion-$contrast-$transparency';
  }
}

const _artifactStates = [
  _ArtifactState(
    layout: 'compact',
    size: ui.Size(390, 844),
    brightness: Brightness.light,
  ),
  _ArtifactState(
    layout: 'compact',
    size: ui.Size(390, 844),
    brightness: Brightness.dark,
  ),
  _ArtifactState(
    layout: 'compact',
    size: ui.Size(390, 844),
    brightness: Brightness.light,
    textScale: 3,
  ),
  _ArtifactState(
    layout: 'compact',
    size: ui.Size(390, 844),
    brightness: Brightness.dark,
    textScale: 3,
  ),
  _ArtifactState(
    layout: 'landscape',
    size: ui.Size(844, 390),
    brightness: Brightness.light,
  ),
  _ArtifactState(
    layout: 'regular-tablet',
    size: ui.Size(1024, 1366),
    brightness: Brightness.dark,
  ),
  _ArtifactState(
    layout: 'regular-split',
    size: ui.Size(744, 1024),
    brightness: Brightness.light,
  ),
  _ArtifactState(
    layout: 'compact',
    size: ui.Size(390, 844),
    brightness: Brightness.dark,
    reduceMotion: true,
  ),
  _ArtifactState(
    layout: 'compact',
    size: ui.Size(390, 844),
    brightness: Brightness.light,
    increasedContrast: true,
  ),
  _ArtifactState(
    layout: 'compact',
    size: ui.Size(390, 844),
    brightness: Brightness.light,
    reduceTransparency: true,
  ),
];

void main() {
  final output = Directory('build/test-artifacts/app-owned');
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
    'login',
    'trips',
    'offline',
    'error',
  };

  setUpAll(() {
    if (output.existsSync()) output.deleteSync(recursive: true);
    output.createSync(recursive: true);
  });

  test(
    'artifact matrix keeps Increased Contrast and Reduce Transparency separate',
    () {
      expect(_artifactStates, hasLength(10));
      expect(
        _artifactStates.where((state) => state.increasedContrast),
        hasLength(1),
      );
      expect(
        _artifactStates.where((state) => state.reduceTransparency),
        hasLength(1),
      );
      expect(
        _artifactStates.where(
          (state) => state.increasedContrast && state.reduceTransparency,
        ),
        isEmpty,
      );
      expect(expected.length * _artifactStates.length, 140);
    },
  );

  for (final state in _artifactStates) {
    testWidgets(
      '${state.suffix} writes the complete release evidence set',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearAllTestValues);

        final boundaryKey = GlobalKey();
        tester.view.physicalSize = state.size;
        tester.platformDispatcher.platformBrightnessTestValue =
            state.brightness;
        tester.platformDispatcher.textScaleFactorTestValue = state.textScale;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(
              disableAnimations: state.reduceMotion,
              reduceMotion: state.reduceMotion,
              highContrast: state.increasedContrast,
            );

        await runAppOwnedReleaseFlow(
          tester,
          appWrapper: (child) => AppAccessibilityScope(
            reduceTransparency: state.reduceTransparency,
            child: RepaintBoundary(key: boundaryKey, child: child),
          ),
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

        final files = output
            .listSync()
            .whereType<File>()
            .where(
              (file) =>
                  file.uri.pathSegments.last.endsWith('-${state.suffix}.png'),
            )
            .toList();
        for (final name in expected) {
          expect(
            files.map((file) => file.uri.pathSegments.last),
            contains('$name-${state.suffix}.png'),
          );
        }
        expect(files, hasLength(expected.length));
        expect(
          files,
          everyElement(predicate<File>((file) => file.lengthSync() > 1000)),
        );
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }
}
