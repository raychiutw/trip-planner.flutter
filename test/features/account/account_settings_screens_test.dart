import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/app_preferences.dart';
import 'package:tripline/features/account/account_settings_screens.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('AppearanceSettingsScreen 可切換 themeMode provider', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const AppearanceSettingsScreen(),
        ),
      ),
    );

    expect(container.read(themeModeProvider), ThemeMode.system);

    await tester.tap(find.byKey(const Key('appearance-theme-dark')));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('NotificationSettingsScreen 可更新通知偏好 provider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NotificationSettingsScreen(),
        ),
      ),
    );

    expect(
      container.read(notificationPreferencesProvider).tripReminders,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('notifications-trip-reminders')));
    await tester.pumpAndSettle();

    expect(
      container.read(notificationPreferencesProvider).tripReminders,
      isFalse,
    );
  });
}
