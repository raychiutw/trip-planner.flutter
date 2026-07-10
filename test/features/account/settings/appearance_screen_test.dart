import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/features/account/settings/appearance_screen.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('點「深色」→ themeMode 變 dark + 打勾', (tester) async {
    final semantics = tester.ensureSemantics();
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

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    // 深色列出現打勾
    final darkTile = tester.widget<ListTile>(
      find.byKey(const ValueKey('theme-dark')),
    );
    expect(darkTile.trailing, isA<Icon>());
    expect(
      tester.getSemantics(find.byKey(const ValueKey('theme-dark-semantics'))),
      matchesSemantics(
        label: '深色',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
