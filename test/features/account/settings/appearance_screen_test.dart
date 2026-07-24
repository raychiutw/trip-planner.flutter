import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/features/account/settings/appearance_screen.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_settings_group.dart';

void main() {
  testWidgets('點「深色」→ themeMode 變 dark + 打勾', (tester) async {
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

    expect(find.byType(TpSettingsGroup), findsOneWidget);
    expect(find.text('App 外觀'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(
      tester
          .widget<TpSettingsRow>(find.byKey(const ValueKey('theme-system')))
          .trailing,
      isA<Icon>(),
    );
    final systemSemantics = tester
        .getSemantics(find.byKey(const ValueKey('theme-system')))
        .getSemanticsData()
        .flagsCollection;
    expect(systemSemantics.isSelected, Tristate.isTrue);
    expect(systemSemantics.isInMutuallyExclusiveGroup, isTrue);

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    // 深色列出現打勾
    final darkTile = tester.widget<TpSettingsRow>(
      find.byKey(const ValueKey('theme-dark')),
    );
    expect(darkTile.trailing, isA<Icon>());
    final darkSemantics = tester
        .getSemantics(find.byKey(const ValueKey('theme-dark')))
        .getSemanticsData()
        .flagsCollection;
    expect(darkSemantics.isSelected, Tristate.isTrue);
    expect(darkSemantics.isInMutuallyExclusiveGroup, isTrue);
  });

  testWidgets('200% Dynamic Type 下外觀選項仍完整顯示', (tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
  });
}
