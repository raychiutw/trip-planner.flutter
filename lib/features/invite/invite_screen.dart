/// Public invitation accept page (`/invite?token=`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/trip_member.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'invite_controller.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  String get _token => widget.token.trim();
  String get _inviteLocation =>
      '/invite?token=${Uri.encodeQueryComponent(_token)}';
  String get _loginLocation =>
      '/login?redirect_after=${Uri.encodeComponent(_inviteLocation)}';

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.watch(inviteControllerProvider(_token));
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final authLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('邀請確認')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('invite-page'),
          padding: const EdgeInsets.fromLTRB(
            TpSpacing.s4,
            TpSpacing.s4,
            TpSpacing.s4,
            TpSpacing.s8,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _InviteBody(
                  state: inviteState,
                  user: user,
                  authLoading: authLoading,
                  onLogin: _goLogin,
                  onSwitchAccount: () => unawaited(_switchAccount()),
                  onAccept:
                      inviteState.canAccept(user, authLoading: authLoading)
                      ? () => unawaited(_accept())
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goLogin() {
    if (_token.isEmpty) return;
    context.go(_loginLocation);
  }

  Future<void> _switchAccount() async {
    if (_token.isEmpty) return;
    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;
    context.go(_loginLocation);
  }

  Future<void> _accept() async {
    final result = await ref
        .read(inviteControllerProvider(_token).notifier)
        .accept();
    if (!mounted || result == null) return;
    context.go('/trips/${Uri.encodeComponent(result.tripId)}');
  }
}

class _InviteBody extends StatelessWidget {
  const _InviteBody({
    required this.state,
    required this.user,
    required this.authLoading,
    required this.onLogin,
    required this.onSwitchAccount,
    required this.onAccept,
  });

  final InviteState state;
  final UserInfo? user;
  final bool authLoading;
  final VoidCallback onLogin;
  final VoidCallback onSwitchAccount;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    if (state.loading) return const _LoadingView();
    if (state.error != null || state.invitation == null) {
      return _ErrorView(message: state.error ?? '邀請連結無效，請聯絡邀請者重寄。');
    }

    final invitation = state.invitation!;
    final accountStatus = state.accountStatusFor(
      user,
      authLoading: authLoading,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InviteHero(invitation: invitation),
        const SizedBox(height: TpSpacing.s3),
        _ChecklistCard(
          invitation: invitation,
          user: user,
          status: accountStatus,
          accepting: state.accepting,
          onLogin: onLogin,
          onSwitchAccount: onSwitchAccount,
          onAccept: onAccept,
        ),
        if (state.acceptError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _ProblemPanel(
            key: const ValueKey('invite-accept-error'),
            title: '接受失敗',
            message: state.acceptError!,
          ),
        ],
      ],
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero({required this.invitation});

  final InvitationDetails invitation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final inviter = invitation.inviterDisplayName?.trim().isNotEmpty == true
        ? invitation.inviterDisplayName!.trim()
        : invitation.inviterEmail;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tones.accentSubtle,
        border: Border.all(color: tones.accentBg),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '共編邀請',
              style: theme.textTheme.labelLarge?.copyWith(
                color: tones.accentDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: TpSpacing.s2),
            Text(invitation.tripTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: TpSpacing.s3),
            Text(
              '$inviter 邀請 ${invitation.invitedEmail} 加入此行程。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.invitation,
    required this.user,
    required this.status,
    required this.accepting,
    required this.onLogin,
    required this.onSwitchAccount,
    required this.onAccept,
  });

  final InvitationDetails invitation;
  final UserInfo? user;
  final InviteAccountStatus status;
  final bool accepting;
  final VoidCallback onLogin;
  final VoidCallback onSwitchAccount;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outlineVariant,
    );

    return Card(
      key: status == InviteAccountStatus.mismatch
          ? const ValueKey('invite-mismatch')
          : null,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryRow(
              title: '邀請連結有效',
              body: _expiryLabel(invitation.expiresAt),
              trailing: Icons.check_rounded,
              tone: _SummaryTone.success,
            ),
            divider,
            _SummaryRow(
              title: _accountTitle(status),
              body: _accountBody(status, invitation, user),
              trailing: _accountIcon(status),
              tone: _accountTone(status),
            ),
            const SizedBox(height: TpSpacing.s4),
            _PrimaryAction(
              status: status,
              accepting: accepting,
              onLogin: onLogin,
              onSwitchAccount: onSwitchAccount,
              onAccept: onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.title,
    required this.body,
    required this.trailing,
    required this.tone,
  });

  final String title;
  final String body;
  final IconData trailing;
  final _SummaryTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(context, tone);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: TpSpacing.s1),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TpSpacing.s3),
          Icon(trailing, color: color, size: 22),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.status,
    required this.accepting,
    required this.onLogin,
    required this.onSwitchAccount,
    required this.onAccept,
  });

  final InviteAccountStatus status;
  final bool accepting;
  final VoidCallback onLogin;
  final VoidCallback onSwitchAccount;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      InviteAccountStatus.anonymous => FilledButton.icon(
        key: const ValueKey('invite-login'),
        onPressed: onLogin,
        icon: const Icon(Icons.login_outlined),
        label: const Text('登入後加入'),
      ),
      InviteAccountStatus.matching => FilledButton.icon(
        key: const ValueKey('invite-accept'),
        onPressed: accepting ? null : onAccept,
        icon: accepting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_circle_outline),
        label: Text(accepting ? '接受中...' : '接受邀請'),
      ),
      InviteAccountStatus.mismatch => FilledButton.icon(
        key: const ValueKey('invite-switch-account'),
        onPressed: onSwitchAccount,
        icon: const Icon(Icons.switch_account_outlined),
        label: const Text('切換帳號'),
      ),
      InviteAccountStatus.checking => OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('確認帳號中...'),
      ),
    };
  }
}

class _ProblemPanel extends StatelessWidget {
  const _ProblemPanel({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.58),
        border: Border.all(color: colors.error.withValues(alpha: 0.28)),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: TpSpacing.s1),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('invite-loading'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: TpSpacing.s4),
            Text('載入邀請資料...', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProblemPanel(
          key: const ValueKey('invite-error'),
          title: '邀請無效',
          message: _errorMessageWithRecovery(message),
        ),
      ],
    );
  }
}

enum _SummaryTone { success, pending, error, muted }

Color _toneColor(BuildContext context, _SummaryTone tone) {
  final theme = Theme.of(context);
  final tones = theme.extension<TpTones>()!;
  return switch (tone) {
    _SummaryTone.success => tones.success,
    _SummaryTone.pending => tones.accent,
    _SummaryTone.error => theme.colorScheme.error,
    _SummaryTone.muted => theme.colorScheme.onSurfaceVariant,
  };
}

String _expiryLabel(String expiresAt) {
  final parsed = DateTime.tryParse(expiresAt);
  if (parsed == null) return '尚未過期或被接受';
  final local = parsed.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '有效至 $year/$month/$day';
}

String _accountTitle(InviteAccountStatus status) {
  return switch (status) {
    InviteAccountStatus.checking => '帳號確認中',
    InviteAccountStatus.anonymous => '帳號待確認',
    InviteAccountStatus.matching => '帳號已確認',
    InviteAccountStatus.mismatch => '帳號需要切換',
  };
}

String _accountBody(
  InviteAccountStatus status,
  InvitationDetails invitation,
  UserInfo? user,
) {
  return switch (status) {
    InviteAccountStatus.checking => '正在確認目前登入狀態',
    InviteAccountStatus.anonymous => '登入 ${invitation.invitedEmail} 後即可加入',
    InviteAccountStatus.matching =>
      '目前登入 ${user?.email ?? invitation.invitedEmail}',
    InviteAccountStatus.mismatch =>
      '切換至 ${invitation.invitedEmail}；目前登入 ${user?.email ?? '未知'}',
  };
}

IconData _accountIcon(InviteAccountStatus status) {
  return switch (status) {
    InviteAccountStatus.checking => Icons.more_horiz,
    InviteAccountStatus.anonymous => Icons.arrow_forward_rounded,
    InviteAccountStatus.matching => Icons.check_rounded,
    InviteAccountStatus.mismatch => Icons.arrow_forward_rounded,
  };
}

_SummaryTone _accountTone(InviteAccountStatus status) {
  return switch (status) {
    InviteAccountStatus.checking => _SummaryTone.muted,
    InviteAccountStatus.anonymous => _SummaryTone.pending,
    InviteAccountStatus.matching => _SummaryTone.success,
    InviteAccountStatus.mismatch => _SummaryTone.pending,
  };
}

String _errorMessageWithRecovery(String message) {
  if (message.contains('重寄') || message.contains('稍後再試')) return message;
  return '$message\n請稍後再試，或聯絡邀請者確認連結。';
}
