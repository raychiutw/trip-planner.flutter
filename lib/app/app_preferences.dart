/// App-wide local preferences used by settings screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App theme mode preference. Defaults to following the platform setting.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Sets the current app theme mode.
  void setMode(ThemeMode mode) {
    state = mode;
  }
}

/// Current app theme mode provider.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Local notification preference flags shown in the account settings flow.
class NotificationPreferences {
  const NotificationPreferences({
    this.tripReminders = true,
    this.collaborationUpdates = true,
    this.aiUpdates = true,
  });

  /// Trip date and itinerary reminder preference.
  final bool tripReminders;

  /// Collaboration invitation and member update preference.
  final bool collaborationUpdates;

  /// AI request completion and health-check update preference.
  final bool aiUpdates;

  NotificationPreferences copyWith({
    bool? tripReminders,
    bool? collaborationUpdates,
    bool? aiUpdates,
  }) {
    return NotificationPreferences(
      tripReminders: tripReminders ?? this.tripReminders,
      collaborationUpdates: collaborationUpdates ?? this.collaborationUpdates,
      aiUpdates: aiUpdates ?? this.aiUpdates,
    );
  }
}

/// Notification preferences for the current app session.
class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() => const NotificationPreferences();

  /// Replaces notification preferences.
  void update(NotificationPreferences preferences) {
    state = preferences;
  }
}

/// Current notification preferences provider.
final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
      NotificationPreferencesNotifier.new,
    );
