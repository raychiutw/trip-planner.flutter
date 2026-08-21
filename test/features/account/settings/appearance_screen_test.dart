import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/features/account/settings/appearance_screen.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('外觀頁以互斥三選一顯示目前模式並立即切換', (tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('appearance-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-system')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-light')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-dark')), findsOneWidget);
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('theme-system')))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    final darkSemantics = tester
        .getSemantics(find.byKey(const ValueKey('theme-dark')))
        .getSemanticsData();
    expect(darkSemantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(darkSemantics.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    final darkCheckmark = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('theme-dark')),
        matching: find.byIcon(CupertinoIcons.checkmark),
      ),
    );
    expect(
      darkCheckmark.color,
      Theme.of(
        tester.element(find.byKey(const ValueKey('theme-dark'))),
      ).colorScheme.primary,
    );
  });

  testWidgets('320×568 與 200% Dynamic Type 下三個外觀選項仍完整可操作', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('跟隨系統'), findsOneWidget);
    expect(find.text('淺色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('theme-light')))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
