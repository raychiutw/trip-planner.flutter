import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/collab.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  InvitationPreview? _preview;
  String? _error;
  bool _loading = true;
  bool _accepting = false;

  String get _token => widget.token?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant InviteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('加入行程')),
      body: SafeArea(child: _buildBody(context, authState)),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<UserInfo?> authState) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final preview = _preview;
    if (_error != null || preview == null) {
      return _ErrorState(
        message: _error ?? '邀請連結無效或已過期',
        onRetry: _token.isEmpty ? null : _load,
      );
    }

    return ListView(
      key: const ValueKey('invite-page'),
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s6,
        TpSpacing.s4,
        TpSpacing.s8,
      ),
      children: [
        _PreviewCard(preview: preview),
        const SizedBox(height: TpSpacing.s4),
        _InviteActionPanel(
          preview: preview,
          token: _token,
          currentUser: authState.value,
          authLoading: authState.isLoading,
          accepting: _accepting,
          onAccept: _accept,
        ),
        if (_error != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _error!),
        ],
      ],
    );
  }

  Future<void> _load() async {
    final token = _token;
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _preview = null;
        _error = '邀請連結缺少 token';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await ref
          .read(tripRepositoryProvider)
          .fetchInvitation(token);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _loading = false;
        _error = '邀請連結無效或已過期';
      });
    }
  }

  Future<void> _accept() async {
    if (_accepting || _token.isEmpty) return;
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(tripRepositoryProvider)
          .acceptInvitation(_token);
      if (!mounted) return;
      context.go('/trips/${Uri.encodeComponent(result.tripId)}');
    } on Exception {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = '接受邀請失敗，請稍後再試';
      });
    }
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final InvitationPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.group_add_outlined,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: TpSpacing.s4),
            Text(preview.tripTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '${preview.inviterLabel} 邀請你加入這趟行程。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            _InfoRow(
              icon: Icons.mail_outline,
              label: '受邀 email',
              value: preview.invitedEmail,
            ),
            const SizedBox(height: TpSpacing.s2),
            _InfoRow(
              icon: Icons.schedule_outlined,
              label: '有效期限',
              value: preview.expiresAt,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteActionPanel extends StatelessWidget {
  const _InviteActionPanel({
    required this.preview,
    required this.token,
    required this.currentUser,
    required this.authLoading,
    required this.accepting,
    required this.onAccept,
  });

  final InvitationPreview preview;
  final String token;
  final UserInfo? currentUser;
  final bool authLoading;
  final bool accepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    if (authLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = currentUser;
    if (user == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('請先登入', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: TpSpacing.s2),
              Text(
                '請使用 ${preview.invitedEmail} 登入或註冊後接受邀請。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TpSpacing.s4),
              FilledButton.icon(
                key: const ValueKey('invite-login-btn'),
                icon: const Icon(Icons.login),
                label: const Text('登入或註冊'),
                onPressed: () => context.go(
                  '/login?invitation=${Uri.encodeComponent(token)}',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_sameEmail(user.email, preview.invitedEmail)) {
      return _InlineError(
        key: const ValueKey('invite-mismatch'),
        message: '此邀請寄給 ${preview.invitedEmail}，目前登入帳號是 ${user.email}。',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('接受邀請', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '你將以 ${user.email} 加入這趟行程。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton.icon(
              key: const ValueKey('invite-accept-btn'),
              icon: accepting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('接受邀請'),
              onPressed: accepting ? null : onAccept,
            ),
          ],
        ),
      ),
    );
  }

  bool _sameEmail(String left, String right) {
    return left.trim().toLowerCase() == right.trim().toLowerCase();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: TpSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: TpSpacing.s3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TpSpacing.s4),
              FilledButton(onPressed: onRetry, child: const Text('重試')),
            ],
          ],
        ),
      ),
    );
  }
}
