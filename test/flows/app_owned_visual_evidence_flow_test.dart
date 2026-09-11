import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/theme/tokens.dart';

import '../../integration_test/support/app_flow_fixture.dart';

void main() {
  testWidgets(
    'visual evidence flow walks production chrome on the host runner',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PackageInfo.setMockInitialValues(
        appName: 'Tripline',
        packageName: 'com.raychiu.tripline',
        version: '9.9.9',
        buildNumber: 'host',
        buildSignature: '',
      );

      final scenes = <String>[];
      final logLines = <String>[];
      final textEntries = <({Key? key, String text})>[];
      final mapEvidence = TripMapCanvasEvidence(canvas: fakeTripMapBuilder);

      await runAppOwnedVisualEvidenceFlow(
        tester,
        mapEvidence: mapEvidence,
        enterText: (finder, text) async {
          textEntries.add((
            key: finder.evaluate().single.widget.key,
            text: text,
          ));
          await tester.enterText(finder, text);
        },
        capture: (name) async => scenes.add(name),
        log: logLines.add,
      );

      expect(scenes, [
        'light/trips-list',
        'light/trip-card-menu',
        'light/trip-card-long-press-menu',
        'light/collab-from-trip-card-menu',
        'light/account-sheet',
        'light/timeline-day-2',
        'light/timeline-after-account-close',
        'light/timeline-header-menu',
        'light/map',
        'light/map-day-1',
        'light/map-account-sheet',
        'light/map-trip-picker',
        'light/chat-composer',
        'light/chat-composer-draft',
        'light/chat-draft-after-account-close',
        'light+increased-contrast/trip-card-menu',
        'light+increased-contrast/map',
        'light+reduce-transparency/trip-card-menu',
        'light+reduce-transparency/map',
        'light+reduce-motion/trip-card-menu',
        'light+reduce-motion/account-sheet',
        'light+reduce-motion/map',
        'dark/trips-list',
        'dark/trip-card-menu',
        'dark/account-sheet',
        'dark/map',
        'dark/chat-composer',
        'dark+increased-contrast/trip-card-menu',
        'dark+increased-contrast/map',
        'dark+reduce-transparency/trip-card-menu',
        'dark+reduce-transparency/map',
        'dark+reduce-motion/trip-card-menu',
        'dark+reduce-motion/account-sheet',
        'dark+reduce-motion/map',
      ]);
      expect(
        textEntries,
        contains((
          key: const ValueKey('chat-input'),
          text: 'visual evidence draft',
        )),
      );
      // production 只在 view 建立時回報 onMapReady；回到保留中的地圖不會再回報，
      // 流程不得為了等 ready 而強制重建地圖。
      expect(mapEvidence.readyCount, 1);
      expect(logLines, contains(contains('map ready count=1')));

      String sceneLine(String scene) => logLines.singleWhere(
        (line) => line.contains('scene=$scene |'),
        orElse: () => fail('missing scene log: $scene'),
      );
      // 淺色是明確選的 App 外觀，不依賴 Test Lab 裝置的系統外觀。
      expect(
        sceneLine('light/trips-list'),
        allOf(
          contains('appearance=light'),
          contains('App 外觀=淺色'),
          contains('injected accessibility=none'),
        ),
      );
      expect(
        sceneLine('light/map'),
        allOf(contains('appearance=light'), contains('App 外觀=淺色')),
      );
      expect(
        sceneLine('light+increased-contrast/map'),
        allOf(
          contains('increasedContrast=true'),
          contains('reduceTransparency=false'),
          contains('injected accessibility=increasedContrast'),
        ),
      );
      expect(
        sceneLine('light+reduce-transparency/trip-card-menu'),
        allOf(
          contains('increasedContrast=false'),
          contains('reduceTransparency=true'),
          contains('injected accessibility=reduceTransparency'),
        ),
      );
      expect(
        sceneLine('light+reduce-motion/map'),
        allOf(contains('appearance=light'), contains('reduceMotion=true')),
      );
      expect(
        sceneLine('dark/trips-list'),
        allOf(
          contains('appearance=dark'),
          contains('App 外觀=深色'),
          contains('injected accessibility=none'),
        ),
      );
      expect(
        sceneLine('dark+reduce-motion/account-sheet'),
        allOf(
          contains('appearance=dark'),
          contains('reduceMotion=true'),
          contains('injected accessibility=reduceMotion'),
        ),
      );
      expect(
        sceneLine('dark+increased-contrast/map'),
        allOf(contains('appearance=dark'), contains('increasedContrast=true')),
      );
      expect(
        sceneLine('dark+reduce-transparency/trip-card-menu'),
        allOf(contains('appearance=dark'), contains('reduceTransparency=true')),
      );
      expect(
        logLines.where((line) => line.contains('injected accessibility=')),
        everyElement(contains('test wrapper')),
        reason: '注入的無障礙情境要標明不是 OS 設定',
      );
      // build 身分來自平台 PackageInfo，不是既有 fixture 的 0.9.1（12）替身。
      expect(
        logLines,
        contains(allOf(contains('build identity'), contains('版本 9.9.9（host）'))),
      );
      expect(logLines, isNot(contains(contains('版本 0.9.1（12）'))));
    },
  );

  test('device glass bootstrap reproduces the production glow tint', () {
    // lib/main.dart 的 _triplineGlassTheme 只把光暈主色換成品牌 tint；真機
    // bootstrap 用公開的 AppTheme primary，這裡確認它就是同一個 token。
    final theme = productionEquivalentGlassTheme();
    expect(theme.light.glowColors?.primary, TpSystemColorsLight.tint);
    expect(theme.dark.glowColors?.primary, TpSystemColorsDark.tint);
  });

  testWidgets(
    'map readiness is false before mount, before the real callback, and after unmount',
    (tester) async {
      // 由測試掌控 onMapReady 何時發生的 canvas，不放假 ready 訊號。
      VoidCallback? mapReady;
      final evidence = TripMapCanvasEvidence(
        canvas: (config) {
          mapReady = config.onMapReady;
          return const SizedBox.expand();
        },
      );
      final controller = TripMapController();
      addTearDown(controller.dispose);
      final config = TripMapCanvasConfig(
        controller: controller,
        tilePreset: kTripMapTilePresets.first,
        initialFitPoints: const [],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(evidence.isCurrentCanvasReady(tester), isFalse);

      await tester.pumpWidget(evidence.build(config));
      expect(evidence.isCurrentCanvasReady(tester), isFalse);
      mapReady!();
      expect(evidence.isCurrentCanvasReady(tester), isTrue);
      expect(evidence.readyCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(evidence.isCurrentCanvasReady(tester), isFalse);
    },
  );
}
