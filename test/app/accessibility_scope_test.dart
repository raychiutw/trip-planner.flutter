import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/accessibility_scope.dart';

void main() {
  testWidgets('injected Reduce Transparency is available to descendants', (
    tester,
  ) async {
    bool? value;
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccessibilityScope(
          reduceTransparency: true,
          child: Builder(
            builder: (context) {
              value = AppAccessibilityScope.reduceTransparencyOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(value, isTrue);
  });

  testWidgets('missing iOS channel fails closed to opaque surfaces', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    bool? value;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: AppAccessibilityScope(
            child: Builder(
              builder: (context) {
                value = AppAccessibilityScope.reduceTransparencyOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(value, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('scope is optional outside the production wrapper', (
    tester,
  ) async {
    bool? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            value = AppAccessibilityScope.reduceTransparencyOf(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(value, isFalse);
  });
}
