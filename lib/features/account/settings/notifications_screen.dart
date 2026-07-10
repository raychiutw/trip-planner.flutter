/// 通知偏好設定: GET/PATCH /account/notifications。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../models/user.dart';
import '../../../theme/tokens.dart';

/// 帳號通知偏好 provider。
final accountNotificationPreferencesProvider =
    FutureProvider<AccountNotificationPreferences>((ref) {
      return ref
          .watch(tripRepositoryProvider)
          .fetchAccountNotificationPreferences();
    });

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _busyKey;
  String? _mutationError;

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(accountNotificationPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: prefsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(
            key: ValueKey('notifications-loading'),
          ),
        ),
        error: (error, stackTrace) => _LoadError(
          onRetry: () => ref.invalidate(accountNotificationPreferencesProvider),
        ),
        data: (preferences) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(accountNotificationPreferencesProvider.future),
          child: _NotificationsList(
            preferences: preferences,
            busyKey: _busyKey,
            mutationError: _mutationError,
            onRetry: () =>
                ref.invalidate(accountNotificationPreferencesProvider),
            onChanged: _updatePreference,
          ),
        ),
      ),
    );
  }

  Future<void> _updatePreference(
    _NotificationSetting setting,
    bool value,
  ) async {
    setState(() {
      _busyKey = setting.key;
      _mutationError = null;
    });
    try {
      final repo = ref.read(tripRepositoryProvider);
      switch (setting.key) {
        case 'trip-updates':
          await repo.updateAccountNotificationPreferences(tripUpdates: value);
        case 'invitations':
          await repo.updateAccountNotificationPreferences(invitations: value);
        case 'system':
          await repo.updateAccountNotificationPreferences(system: value);
      }
      if (!mounted) return;
      ref.invalidate(accountNotificationPreferencesProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通知設定已更新')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mutationError = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiError) return error.detail ?? error.message;
    return '更新通知設定失敗，請稍後再試';
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.preferences,
    required this.busyKey,
    required this.mutationError,
    required this.onRetry,
    required this.onChanged,
  });

  static const _settings = [
    _NotificationSetting(
      key: 'trip-updates',
      icon: Icons.home_outlined,
      title: '行程更新通知',
      subtitle: '旅伴改了行程、AI 排程完成',
    ),
    _NotificationSetting(
      key: 'invitations',
      icon: Icons.group_outlined,
      title: '旅伴邀請',
      subtitle: '收到新的共編邀請',
    ),
    _NotificationSetting(
      key: 'system',
      icon: Icons.info_outline,
      title: '系統通知',
      subtitle: 'Tripline 維護、版本更新',
    ),
  ];

  final AccountNotificationPreferences preferences;
  final String? busyKey;
  final String? mutationError;
  final VoidCallback onRetry;
  final Future<void> Function(_NotificationSetting setting, bool value)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('notifications-page'),
      padding: const EdgeInsets.all(TpSpacing.s4),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (mutationError != null) ...[
          _InlineErrorPanel(message: mutationError!, onRetry: onRetry),
          const SizedBox(height: TpSpacing.s4),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, setting) in _settings.indexed) ...[
                _NotificationSwitchTile(
                  setting: setting,
                  value: _valueFor(setting.key),
                  isBusy: busyKey == setting.key,
                  isDisabled: busyKey != null,
                  onChanged: (nextValue) =>
                      unawaited(onChanged(setting, nextValue)),
                ),
                if (index != _settings.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _valueFor(String key) {
    return switch (key) {
      'trip-updates' => preferences.tripUpdates,
      'invitations' => preferences.invitations,
      'system' => preferences.system,
      _ => true,
    };
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  const _NotificationSwitchTile({
    required this.setting,
    required this.value,
    required this.isBusy,
    required this.isDisabled,
    required this.onChanged,
  });

  final _NotificationSetting setting;
  final bool value;
  final bool isBusy;
  final bool isDisabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: ValueKey('notif-switch-${setting.key}'),
      secondary: isBusy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Icon(setting.icon, size: 22),
      title: Text(setting.title),
      subtitle: Text(setting.subtitle),
      value: value,
      onChanged: isDisabled
          ? null
          : (nextValue) {
              HapticFeedback.selectionClick();
              onChanged(nextValue);
            },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [_InlineErrorPanel(message: '無法載入通知設定', onRetry: onRetry)],
    );
  }
}

class _InlineErrorPanel extends StatelessWidget {
  const _InlineErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            TextButton(
              key: const ValueKey('notifications-retry'),
              onPressed: onRetry,
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSetting {
  const _NotificationSetting({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
}
