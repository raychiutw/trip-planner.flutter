import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('iOS 所有 Runner build configuration 都包含 Keychain Sharing', () {
    final debugProfile = read('ios/Runner/DebugProfile.entitlements');
    final release = read('ios/Runner/Release.entitlements');
    final project = read('ios/Runner.xcodeproj/project.pbxproj');

    for (final entitlements in [debugProfile, release]) {
      expect(entitlements, contains('<key>keychain-access-groups</key>'));
      expect(
        entitlements,
        contains(
          r'<string>$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)</string>',
        ),
      );
    }

    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;'.allMatches(
        project,
      ),
      hasLength(2),
    );
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;'.allMatches(
        project,
      ),
      hasLength(1),
    );
  });
}
