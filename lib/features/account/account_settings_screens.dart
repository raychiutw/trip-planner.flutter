/// Account settings subpages for appearance and notifications.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_preferences.dart';
import '../../theme/tokens.dart';

/// 外觀設定頁：切換 app ThemeMode。
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('外觀')),
      body: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          Text(
            '主題',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s2),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ThemeModeTile(
                  key: const Key('appearance-theme-system'),
                  icon: Icons.brightness_auto_outlined,
                  title: '跟隨系統',
                  selected: themeMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.system),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                _ThemeModeTile(
                  key: const Key('appearance-theme-light'),
                  icon: Icons.light_mode_outlined,
                  title: '淺色',
                  selected: themeMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.light),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                _ThemeModeTile(
                  key: const Key('appearance-theme-dark'),
                  icon: Icons.dark_mode_outlined,
                  title: '深色',
                  selected: themeMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 通知設定頁：本機通知偏好切換。
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          Text(
            '通知偏好',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s2),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('notifications-trip-reminders'),
                  secondary: const Icon(Icons.event_available_outlined),
                  title: const Text('行程提醒'),
                  value: preferences.tripReminders,
                  onChanged: (value) {
                    notifier.update(preferences.copyWith(tripReminders: value));
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                SwitchListTile(
                  key: const Key('notifications-collaboration-updates'),
                  secondary: const Icon(Icons.group_outlined),
                  title: const Text('共編更新'),
                  value: preferences.collaborationUpdates,
                  onChanged: (value) {
                    notifier.update(
                      preferences.copyWith(collaborationUpdates: value),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                SwitchListTile(
                  key: const Key('notifications-ai-updates'),
                  secondary: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('AI 完成通知'),
                  value: preferences.aiUpdates,
                  onChanged: (value) {
                    notifier.update(preferences.copyWith(aiUpdates: value));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check, color: colorScheme.primary)
          : const SizedBox.shrink(),
      selected: selected,
      onTap: onTap,
    );
  }
}
