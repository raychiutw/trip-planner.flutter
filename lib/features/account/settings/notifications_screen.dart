/// 通知偏好設定: GET/PATCH /account/notifications。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../app/notification_permission.dart';
import '../../../models/user.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import '../../../ui/tp_settings_group.dart';

/// 帳號通知偏好 provider。
final accountNotificationPreferencesProvider =
    FutureProvider<AccountNotificationPreferences>((ref) {
      return ref
          .watch(accountRepositoryProvider)
          .fetchAccountNotificationPreferences();
    });

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  String? _busyKey;
  String? _mutationError;
  String? _permissionError;
  bool _permissionDenied = false;
  bool _permissionFlowBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncPermissionStatus());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncPermissionStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(accountNotificationPreferencesProvider);
    return Scaffold(
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('通知設定')),
      body: prefsAsync.when(
        loading: () => const AppListLoadingSkeleton(
          key: ValueKey('notifications-loading'),
          itemCount: 4,
        ),
        error: (error, stackTrace) => _LoadError(
          onRetry: () => ref.invalidate(accountNotificationPreferencesProvider),
        ),
        data: (preferences) => RefreshIndicator.adaptive(
          onRefresh: () =>
              ref.refresh(accountNotificationPreferencesProvider.future),
          child: _NotificationsList(
            preferences: preferences,
            busyKey: _busyKey,
            mutationError: _permissionError ?? _mutationError,
            permissionDenied: _permissionDenied,
            interactionLocked: _permissionFlowBusy,
            onRetry: () => unawaited(_retry()),
            onOpenSettings: () =>
                ref.read(notificationPermissionServiceProvider).openSettings(),
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
    if (_busyKey != null || _permissionFlowBusy) return;
    if (value) {
      setState(() => _permissionFlowBusy = true);
      var canEnable = false;
      try {
        canEnable = await _canEnableNotifications();
      } on Exception {
        if (mounted) {
          setState(() => _permissionError = '無法讀取通知權限，請稍後再試');
        }
      } finally {
        if (mounted) setState(() => _permissionFlowBusy = false);
      }
      if (!mounted) return;
      if (!canEnable) return;
    }
    setState(() {
      _busyKey = setting.key;
      _mutationError = null;
    });
    try {
      final repo = ref.read(accountRepositoryProvider);
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
      showAppNotice(context, '通知設定已更新');
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

  Future<bool> _canEnableNotifications() async {
    final permission = ref.read(notificationPermissionServiceProvider);
    final currentStatus = await permission.getStatus();
    if (!mounted) return false;
    if (currentStatus == NotificationPermissionStatus.granted) {
      setState(() => _permissionDenied = false);
      return true;
    }
    if (currentStatus == NotificationPermissionStatus.denied) {
      setState(() => _permissionDenied = true);
      return false;
    }

    final shouldRequest = await showAppConfirm(
      context,
      title: '允許 Tripline 傳送通知？',
      message: '開啟後，Tripline 可在行程異動、旅伴邀請或重要服務消息發生時通知你。',
      confirmLabel: '允許通知',
      cancelLabel: '暫時不要',
    );
    if (!shouldRequest || !mounted) return false;

    final requestedStatus = await permission.request();
    if (!mounted) return false;
    final granted = requestedStatus == NotificationPermissionStatus.granted;
    setState(() => _permissionDenied = !granted);
    return granted;
  }

  Future<void> _syncPermissionStatus() async {
    if (_permissionFlowBusy) return;
    setState(() => _permissionFlowBusy = true);
    try {
      final status = await ref
          .read(notificationPermissionServiceProvider)
          .getStatus();
      if (!mounted) return;
      setState(() {
        _permissionDenied = status == NotificationPermissionStatus.denied;
        _permissionError = null;
      });
    } on Exception {
      if (mounted) {
        setState(() => _permissionError = '無法讀取通知權限，請稍後再試');
      }
    } finally {
      if (mounted) setState(() => _permissionFlowBusy = false);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _mutationError = null;
      _permissionError = null;
    });
    ref.invalidate(accountNotificationPreferencesProvider);
    await _syncPermissionStatus();
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
    required this.permissionDenied,
    required this.interactionLocked,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onChanged,
  });

  static const _settings = [
    _NotificationSetting(
      key: 'trip-updates',
      icon: CupertinoIcons.house,
      title: '行程更新通知',
      subtitle: '旅伴改了行程、AI 排程完成',
    ),
    _NotificationSetting(
      key: 'invitations',
      icon: CupertinoIcons.person_2,
      title: '旅伴邀請',
      subtitle: '收到新的共編邀請',
    ),
    _NotificationSetting(
      key: 'system',
      icon: CupertinoIcons.info_circle,
      title: '系統通知',
      subtitle: 'Tripline 維護、版本更新',
    ),
  ];

  final AccountNotificationPreferences preferences;
  final String? busyKey;
  final String? mutationError;
  final bool permissionDenied;
  final bool interactionLocked;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final Future<void> Function(_NotificationSetting setting, bool value)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('notifications-page'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (permissionDenied)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TpSpacing.s4,
              TpSpacing.s4,
              TpSpacing.s4,
              0,
            ),
            child: _PermissionDeniedPanel(onOpenSettings: onOpenSettings),
          ),
        if (mutationError != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TpSpacing.s4,
              TpSpacing.s4,
              TpSpacing.s4,
              0,
            ),
            child: _InlineErrorPanel(message: mutationError!, onRetry: onRetry),
          ),
        ],
        TpSettingsGroup(
          children: [
            for (final setting in _settings)
              _NotificationSwitchTile(
                setting: setting,
                value: _valueFor(setting.key),
                isBusy: busyKey == setting.key,
                isDisabled: busyKey != null || interactionLocked,
                onChanged: (nextValue) =>
                    unawaited(onChanged(setting, nextValue)),
              ),
          ],
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

class _PermissionDeniedPanel extends StatelessWidget {
  const _PermissionDeniedPanel({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(TpRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('通知權限尚未開啟', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s1),
            const Text('Tripline 不會重複顯示系統提示；你可從系統設定開啟通知。'),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('notifications-open-settings'),
                onPressed: onOpenSettings,
                child: const Text('前往系統設定'),
              ),
            ),
          ],
        ),
      ),
    );
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
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: colorScheme.onErrorContainer,
            ),
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
