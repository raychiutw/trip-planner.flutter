import 'dart:io';

import 'package:patrol/patrol.dart';

const _springBoardBundleId = 'com.apple.springboard';
const _tutorialWaitAttempts = 20;
const _tutorialPollInterval = Duration(milliseconds: 100);

Future<void> dismissStaleSpringBoardTutorial(
  PatrolIntegrationTester patrol,
) async {
  if (!Platform.isIOS) return;

  final tutorialAlert = IOSSelector(
    elementType: IOSElementType.alert,
    text: 'Edit Home Screen',
  );
  final dismissButton = IOSSelector(
    elementType: IOSElementType.button,
    label: 'Dismiss',
    isEnabled: true,
  );
  Future<bool> tutorialIsVisible() async {
    final views = await patrol.platform.ios.getNativeViews(
      tutorialAlert,
      appId: _springBoardBundleId,
    );
    return views.roots.isNotEmpty;
  }

  for (var attempt = 0; attempt < _tutorialWaitAttempts; attempt += 1) {
    if (await tutorialIsVisible()) {
      await patrol.platform.ios.tap(
        dismissButton,
        appId: _springBoardBundleId,
        timeout: const Duration(seconds: 2),
      );
      for (
        var dismissAttempt = 0;
        dismissAttempt < _tutorialWaitAttempts;
        dismissAttempt += 1
      ) {
        if (!await tutorialIsVisible()) return;
        await Future<void>.delayed(_tutorialPollInterval);
      }
      throw StateError('The Edit Home Screen tutorial did not close.');
    }
    await Future<void>.delayed(_tutorialPollInterval);
  }
}
