/// Account sessions settings screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import 'account_display.dart';
import 'connected_apps_screen.dart';
import 'settings/theme_mode_controller.dart';

/// 登入裝置清單 provider（GET /account/sessions）。
final accountSessionsProvider = FutureProvider<AccountSessionsPage>((ref) {
  return ref.watch(tripRepositoryProvider).fetchAccountSessions();
});

/// 登入裝置管理頁。
class AccountSessionsScreen extends ConsumerStatefulWidget {
  const AccountSessionsScreen({super.key});

  @override
  ConsumerState<AccountSessionsScreen> createState() =>
      _AccountSessionsScreenState();
}

class _AccountSessionsScreenState extends ConsumerState<AccountSessionsScreen> {
  String? _busySessionSid;
  String? _mutationError;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(accountSessionsProvider);
    final currentUser = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final sessionsPage = sessionsAsync.value;
    final canRevokeOthers =
        sessionsPage?.sessions.any((session) => !session.isCurrent) ?? false;

    return Scaffold(
      appBar: TpAppBar(
        role: TpAppBarRole.detail,
        title: const Text('登入裝置'),
        actions: [
          TpToolbarGlassButton(
            key: const Key('account-sessions-revoke-others'),
            tooltip: '登出其他裝置',
            onPressed: canRevokeOthers
                ? () => unawaited(_showRevokeOtherSessionsBlocked())
                : null,
            child: const Icon(CupertinoIcons.square_arrow_right),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () =>
            const AppListLoadingSkeleton(key: Key('account-sessions-loading')),
        error: (error, stackTrace) => _SessionsLoadError(
          onRetry: () => ref.invalidate(accountSessionsProvider),
        ),
        data: (page) => _SessionsList(
          sessions: page.sessions,
          currentUserEmail: currentUser?.email,
          themeMode: themeMode,
          busySessionSid: _busySessionSid,
          mutationError: _mutationError,
          onRetry: () => ref.invalidate(accountSessionsProvider),
          onRevoke: _revokeSession,
          onThemeModeChanged: (mode) =>
              ref.read(themeModeProvider.notifier).setMode(mode),
          onOpenConnectedApps: () {
            unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const ConnectedAppsScreen(),
                ),
              ),
            );
          },
          onLogout: () => _confirmLogout(context, ref),
        ),
      ),
    );
  }

  Future<void> _showRevokeOtherSessionsBlocked() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('revoke-other-sessions-blocked-dialog'),
        title: const Text('需要重新驗證才能登出其他裝置'),
        content: const Text(
          '目前缺少可綁定伺服器操作的重新驗證機制，因此不會送出批次登出要求。'
          '你仍可返回裝置清單，逐一登出不再使用的裝置。',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<String?> _revokeSession(String sid) async {
    setState(() {
      _busySessionSid = sid;
      _mutationError = null;
    });
    try {
      await ref.read(tripRepositoryProvider).revokeAccountSession(sid);
      if (!mounted) return '登出裝置失敗，請稍後再試';
      ref.invalidate(accountSessionsProvider);
      showAppNotice(context, '已登出該裝置');
      return null;
    } catch (error) {
      final message = _errorMessage(error);
      if (!mounted) return message;
      setState(() {
        _mutationError = message;
      });
      return message;
    } finally {
      if (mounted) {
        setState(() {
          _busySessionSid = null;
        });
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(TpRadius.xl)),
          ),
          title: const Text('登出帳號'),
          content: const Text('確定要登出嗎？'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: const StadiumBorder(),
                foregroundColor: colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('登出'),
            ),
          ],
        );
      },
    );
    if (shouldLogout == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiError) return error.detail ?? error.message;
    return '登出裝置失敗，請稍後再試';
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({
    required this.sessions,
    required this.currentUserEmail,
    required this.themeMode,
    required this.busySessionSid,
    required this.mutationError,
    required this.onRetry,
    required this.onRevoke,
    required this.onThemeModeChanged,
    required this.onOpenConnectedApps,
    required this.onLogout,
  });

  final List<AccountSession> sessions;
  final String? currentUserEmail;
  final ThemeMode themeMode;
  final String? busySessionSid;
  final String? mutationError;
  final VoidCallback onRetry;
  final Future<String?> Function(String sid) onRevoke;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onOpenConnectedApps;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (currentUserEmail != null) ...[
            _SessionAccountHeader(email: currentUserEmail!),
            const SizedBox(height: TpSpacing.s4),
          ],
          if (mutationError != null) ...[
            _InlineErrorPanel(message: mutationError!, onRetry: onRetry),
            const SizedBox(height: TpSpacing.s4),
          ],
          if (sessions.isEmpty)
            const _EmptySessionsState()
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < sessions.length; index++) ...[
                    _SessionTile(
                      session: sessions[index],
                      isBusy: busySessionSid == sessions[index].sid,
                      onRevoke: () => onRevoke(sessions[index].sid),
                    ),
                    if (index != sessions.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: TpSpacing.s4),
          _SessionsInfoPanel(onOpenConnectedApps: onOpenConnectedApps),
          const SizedBox(height: TpSpacing.s4),
          _SessionsFooter(
            themeMode: themeMode,
            onThemeModeChanged: onThemeModeChanged,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SessionAccountHeader extends StatelessWidget {
  const _SessionAccountHeader({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '帳號',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s1),
          Text(
            email,
            key: const Key('account-sessions-user-email'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsInfoPanel extends StatelessWidget {
  const _SessionsInfoPanel({required this.onOpenConnectedApps});

  final VoidCallback onOpenConnectedApps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: const Key('account-sessions-oauth-note'),
      padding: const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: TpSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OAuth 已連結應用不受影響', style: theme.textTheme.titleSmall),
                const SizedBox(height: TpSpacing.s1),
                Text(
                  '登出裝置只會移除瀏覽器或手機的登入狀態；第三方應用請到已連結的應用程式管理。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: TpSpacing.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('account-sessions-connected-apps'),
                    onPressed: onOpenConnectedApps,
                    icon: const Icon(Icons.extension_outlined, size: 18),
                    label: const Text('管理已連結應用'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsFooter extends StatelessWidget {
  const _SessionsFooter({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLogout,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            key: const Key('account-sessions-theme-footer'),
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('深淺模式'),
            subtitle: Text(_themeModeLabel(themeMode)),
            trailing: PopupMenuButton<ThemeMode>(
              key: const Key('account-sessions-theme-menu'),
              tooltip: '變更深淺模式',
              initialValue: themeMode,
              onSelected: onThemeModeChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  key: Key('account-sessions-theme-system'),
                  value: ThemeMode.system,
                  child: Text('跟隨系統'),
                ),
                PopupMenuItem(
                  key: Key('account-sessions-theme-light'),
                  value: ThemeMode.light,
                  child: Text('淺色'),
                ),
                PopupMenuItem(
                  key: Key('account-sessions-theme-dark'),
                  value: ThemeMode.dark,
                  child: Text('深色'),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          ListTile(
            key: const Key('account-sessions-logout'),
            leading: Icon(Icons.logout, size: 20, color: colorScheme.error),
            title: Text(
              '登出此帳號',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟隨系統',
      ThemeMode.light => '淺色',
      ThemeMode.dark => '深色',
    };
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.isBusy,
    required this.onRevoke,
  });

  final AccountSession session;
  final bool isBusy;
  final Future<String?> Function() onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('account-session-row-${session.sid}'),
      onTap: () => _showDetails(context),
      leading: Icon(
        session.isCurrent
            ? CupertinoIcons.device_phone_portrait
            : CupertinoIcons.device_laptop,
        size: 22,
      ),
      title: Text(session.uaSummary ?? '未知裝置'),
      subtitle: Text(_subtitle),
      trailing: session.isCurrent
          ? const _CurrentSessionChip()
          : isBusy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const Icon(CupertinoIcons.chevron_forward, size: 18),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SessionDetails(
          session: session,
          subtitle: _subtitle,
          initiallyBusy: isBusy,
          onRevoke: onRevoke,
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[
      if (session.lastSeenAt.isNotEmpty)
        '最近活動：${humanAccountTime(session.lastSeenAt)}',
      if (session.createdAt.isNotEmpty)
        '首次登入：${humanAccountTime(session.createdAt)}',
    ];
    return parts.isEmpty ? '沒有活動時間' : parts.join('\n');
  }
}

class _SessionDetails extends StatefulWidget {
  const _SessionDetails({
    required this.session,
    required this.subtitle,
    required this.initiallyBusy,
    required this.onRevoke,
  });

  final AccountSession session;
  final String subtitle;
  final bool initiallyBusy;
  final Future<String?> Function() onRevoke;

  @override
  State<_SessionDetails> createState() => _SessionDetailsState();
}

class _SessionDetailsState extends State<_SessionDetails> {
  late bool _isBusy = widget.initiallyBusy;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      key: const ValueKey('account-session-details'),
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('裝置詳情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          TpSpacing.s5,
          TpSpacing.s2,
          TpSpacing.s5,
          TpSpacing.s5,
        ),
        children: [
          Text(
            session.uaSummary ?? '未知裝置',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: TpSpacing.s3),
          Text(widget.subtitle),
          if (session.ipHashPrefix != null) ...[
            const SizedBox(height: TpSpacing.s2),
            Text(
              '安全識別碼：${session.ipHashPrefix}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (!session.isCurrent) ...[
            if (_errorText != null) ...[
              const SizedBox(height: TpSpacing.s4),
              _InlineErrorPanel(
                message: _errorText!,
                onRetry: () => unawaited(_confirmRevoke()),
              ),
            ],
            const SizedBox(height: TpSpacing.s5),
            FilledButton.icon(
              key: Key('account-session-revoke-${session.sid}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(TpSpacing.tapMin),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: _isBusy ? null : _confirmRevoke,
              icon: _isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.square_arrow_right),
              label: const Text('登出此裝置'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRevoke() async {
    final sessionName = widget.session.uaSummary ?? '此裝置';
    final confirmed = await showAppConfirm(
      context,
      title: '登出 $sessionName？',
      message: '這會立即移除此裝置的登入狀態，之後必須重新登入。這項操作無法復原。',
      confirmLabel: '登出',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final error = await widget.onRevoke();
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _errorText = error;
    });
    if (error == null) await Navigator.of(context).maybePop();
  }
}

class _CurrentSessionChip extends StatelessWidget {
  const _CurrentSessionChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s2,
        vertical: TpSpacing.s1,
      ),
      decoration: ShapeDecoration(
        color: colorScheme.primaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Text(
        '目前裝置',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SessionsLoadError extends StatelessWidget {
  const _SessionsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [_InlineErrorPanel(message: '無法載入登入裝置', onRetry: onRetry)],
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
    return Semantics(
      liveRegion: true,
      child: Card(
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
                key: const Key('account-sessions-retry'),
                onPressed: onRetry,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySessionsState extends StatelessWidget {
  const _EmptySessionsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: TpSpacing.s8),
      child: Center(child: Text('目前沒有登入裝置')),
    );
  }
}
