/// Account sessions settings screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';

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
  bool _isRevokingOthers = false;
  String? _mutationError;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(accountSessionsProvider);
    final sessionsPage = sessionsAsync.value;
    final canRevokeOthers =
        sessionsPage?.sessions.any((session) => !session.isCurrent) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登入裝置'),
        actions: [
          IconButton(
            key: const Key('account-sessions-revoke-others'),
            tooltip: '登出其他裝置',
            onPressed: canRevokeOthers && !_isRevokingOthers
                ? () => unawaited(_confirmRevokeOtherSessions())
                : null,
            icon: _isRevokingOthers
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(
            key: Key('account-sessions-loading'),
          ),
        ),
        error: (error, stackTrace) => _SessionsLoadError(
          onRetry: () => ref.invalidate(accountSessionsProvider),
        ),
        data: (page) => _SessionsList(
          sessions: page.sessions,
          busySessionSid: _busySessionSid,
          mutationError: _mutationError,
          onRetry: () => ref.invalidate(accountSessionsProvider),
          onRevoke: _revokeSession,
        ),
      ),
    );
  }

  Future<void> _confirmRevokeOtherSessions() async {
    final shouldRevoke = await showAppConfirm(
      context,
      title: '登出其他裝置',
      message: '這會保留目前裝置，並登出其他所有登入裝置。',
      confirmLabel: '登出',
      isDestructive: true,
    );
    if (!shouldRevoke || !mounted) return;

    setState(() {
      _isRevokingOthers = true;
      _mutationError = null;
    });
    try {
      await ref.read(tripRepositoryProvider).revokeOtherAccountSessions();
      if (!mounted) return;
      ref.invalidate(accountSessionsProvider);
      showAppNotice(context, '已登出其他裝置');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mutationError = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRevokingOthers = false;
        });
      }
    }
  }

  Future<void> _revokeSession(String sid) async {
    setState(() {
      _busySessionSid = sid;
      _mutationError = null;
    });
    try {
      await ref.read(tripRepositoryProvider).revokeAccountSession(sid);
      if (!mounted) return;
      ref.invalidate(accountSessionsProvider);
      showAppNotice(context, '已登出該裝置');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mutationError = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busySessionSid = null;
        });
      }
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
    required this.busySessionSid,
    required this.mutationError,
    required this.onRetry,
    required this.onRevoke,
  });

  final List<AccountSession> sessions;
  final String? busySessionSid;
  final String? mutationError;
  final VoidCallback onRetry;
  final Future<void> Function(String sid) onRevoke;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
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
                      onRevoke: () => unawaited(onRevoke(sessions[index].sid)),
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
        ],
      ),
    );
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
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('account-session-row-${session.sid}'),
      leading: Icon(
        session.isCurrent ? Icons.devices_outlined : Icons.phonelink_outlined,
        size: 22,
      ),
      title: Text(session.uaSummary ?? '未知裝置'),
      subtitle: Text(_subtitle),
      trailing: session.isCurrent
          ? const _CurrentSessionChip()
          : TextButton(
              key: Key('account-session-revoke-${session.sid}'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                shape: const StadiumBorder(),
              ),
              onPressed: isBusy ? null : onRevoke,
              child: isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('登出'),
            ),
    );
  }

  String get _subtitle {
    final parts = <String>[
      if (session.lastSeenAt.isNotEmpty) '最近活動：${session.lastSeenAt}',
      if (session.createdAt.isNotEmpty) '建立時間：${session.createdAt}',
      if (session.ipHashPrefix != null) 'IP 指紋：${session.ipHashPrefix}',
    ];
    return parts.isEmpty ? '沒有活動時間' : parts.join('\n');
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
              key: const Key('account-sessions-retry'),
              onPressed: onRetry,
              child: const Text('重試'),
            ),
          ],
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
