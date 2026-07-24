import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/app_flow_fixture.dart';

void main() {
  test('release fixture 包含 Day fallback 與有座標的行程 POI', () {
    expect(releaseSmokeTrips, hasLength(2));
    expect(releaseSmokeDays.length, greaterThan(1));
    expect(releaseSmokeTokyoDays, hasLength(1));
    expect(releaseSmokeFavorites, isNotEmpty);
    expect(
      releaseSmokeDays
          .expand((day) => day.timeline)
          .where(
            (entry) =>
                entry.master?.lat != null &&
                entry.master?.lng != null &&
                entry.master?.type != null,
          ),
      isNotEmpty,
    );
  });

  testWidgets('app-owned release flow completes on the host runner', (
    tester,
  ) async {
    final textEntries = <({Key? key, String text})>[];
    final captures = <String>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await runAppOwnedReleaseFlow(
      tester,
      capture: (name) async => captures.add(name),
      enterText: (finder, text) async {
        textEntries.add((key: finder.evaluate().single.widget.key, text: text));
        await tester.enterText(finder, text);
      },
      setKeyboardVisible: (visible) async {
        tester.view.viewInsets = visible
            ? const FakeViewPadding(bottom: 300)
            : FakeViewPadding.zero;
        await tester.pumpAndSettle();
      },
    );
    expect(textEntries, [
      (key: const ValueKey('login-email-field'), text: 'ray@example.com'),
      (key: const ValueKey('login-password-field'), text: 'secret'),
      (key: const ValueKey('chat-input'), text: 'device smoke draft'),
      (key: const ValueKey('favorites-search-input'), text: '牧志'),
      (key: const ValueKey('favorites-search-input'), text: ''),
    ]);
    expect(
      captures,
      containsAllInOrder([
        'welcome',
        'login',
        'trips',
        'destructive-confirm',
        'itinerary',
        'form',
        'map-tripline-poi',
        'map-native-google-poi',
        'trip-picker',
        'account',
        'chat',
        'favorites',
        'offline',
        'error',
      ]),
    );
  });
}
