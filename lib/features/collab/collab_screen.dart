import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/collab.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';

class CollabScreen extends ConsumerStatefulWidget {
  const CollabScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<CollabScreen> createState() => _CollabScreenState();
}

class _CollabScreenState extends ConsumerState<CollabScreen> {
  final _emailController = TextEditingController();

  Trip? _trip;
  List<TripPermission> _permissions = const [];
  PendingInvitationPage _pendingInvitations = const PendingInvitationPage(
    items: [],
  );
  String _selectedRole = 'member';
  String? _loadError;
  String? _pendingError;
  String? _actionError;
  bool _loading = true;
  bool _submitting = false;
  String? _revokingEmail;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _emailController
      ..removeListener(_onEmailChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回行程',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.maybeOf(
            context,
          )?.go('/trips/${Uri.encodeComponent(widget.tripId)}'),
        ),
        title: const Text('共編設定'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => unawaited(_load()),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _trip == null) {
      return _ErrorState(message: _loadError!, onRetry: _load);
    }

    final trip = _trip;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s8,
      ),
      children: [
        if (trip != null) _TripHeader(trip: trip),
        if (_loadError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _loadError!),
        ],
        const SizedBox(height: TpSpacing.s4),
        _InviteForm(
          emailController: _emailController,
          selectedRole: _selectedRole,
          submitting: _submitting,
          canSubmit: _canSubmitInvite,
          onRoleChanged: (role) => setState(() => _selectedRole = role),
          onSubmit: _submitInvite,
        ),
        if (_actionError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _actionError!),
        ],
        const SizedBox(height: TpSpacing.s6),
        _SectionTitle(title: '成員', count: _permissions.length),
        const SizedBox(height: TpSpacing.s2),
        if (_permissions.isEmpty)
          const _EmptyText('尚無成員資料')
        else
          _PermissionList(permissions: _permissions),
        const SizedBox(height: TpSpacing.s6),
        _SectionTitle(title: '待接受邀請', count: _pendingInvitations.items.length),
        if (_pendingError != null) ...[
          const SizedBox(height: TpSpacing.s2),
          _InlineError(message: _pendingError!),
        ],
        const SizedBox(height: TpSpacing.s2),
        if (_pendingInvitations.items.isEmpty)
          const _EmptyText('沒有待接受邀請')
        else
          _PendingInvitationList(
            invitations: _pendingInvitations.items,
            revokingEmail: _revokingEmail,
            onRevoke: _revokeInvitation,
          ),
      ],
    );
  }

  bool get _canSubmitInvite {
    return !_submitting && _emailController.text.trim().isNotEmpty;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _pendingError = null;
      _actionError = null;
    });

    final repository = ref.read(tripRepositoryProvider);
    try {
      final trip = await repository.fetchTrip(widget.tripId);
      final permissions = await repository.fetchTripPermissions(widget.tripId);
      PendingInvitationPage pendingInvitations = const PendingInvitationPage(
        items: [],
      );
      String? pendingError;
      try {
        pendingInvitations = await repository.fetchPendingInvitations(
          widget.tripId,
        );
      } on Exception {
        pendingError = '無法載入待邀請清單';
      }
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _permissions = permissions;
        _pendingInvitations = pendingInvitations;
        _pendingError = pendingError;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '無法載入共編設定';
      });
    }
  }

  Future<void> _submitInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _actionError = null;
    });
    try {
      await ref
          .read(tripRepositoryProvider)
          .createTripPermissionInvite(
            tripId: widget.tripId,
            email: email,
            role: _selectedRole,
          );
      _emailController.clear();
      _selectedRole = 'member';
      await _load();
      if (!mounted) return;
      setState(() => _submitting = false);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _actionError = '邀請送出失敗，請確認 email 後再試一次';
      });
    }
  }

  Future<void> _revokeInvitation(PendingInvitation invitation) async {
    if (_revokingEmail != null) return;
    setState(() {
      _revokingEmail = invitation.invitedEmail;
      _actionError = null;
    });
    try {
      await ref
          .read(tripRepositoryProvider)
          .revokeTripInvitation(
            tripId: widget.tripId,
            email: invitation.invitedEmail,
          );
      await _load();
      if (!mounted) return;
      setState(() => _revokingEmail = null);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _revokingEmail = null;
        _actionError = '撤回邀請失敗，請稍後再試';
      });
    }
  }

  void _onEmailChanged() {
    if (mounted) setState(() {});
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _tripTitle(trip);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: TpSpacing.s1),
        Text(
          '管理可共同編輯或檢視此行程的人員。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _tripTitle(Trip trip) {
    final title = trip.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return trip.name;
  }
}

class _InviteForm extends StatelessWidget {
  const _InviteForm({
    required this.emailController,
    required this.selectedRole,
    required this.submitting,
    required this.canSubmit,
    required this.onRoleChanged,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final String selectedRole;
  final bool submitting;
  final bool canSubmit;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('邀請旅伴', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s3),
            TextField(
              key: const ValueKey('collab-add-email'),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              onSubmitted: (_) {
                if (canSubmit) onSubmit();
              },
            ),
            const SizedBox(height: TpSpacing.s3),
            _RoleSelector(
              selectedRole: selectedRole,
              enabled: !submitting,
              onRoleChanged: onRoleChanged,
            ),
            const SizedBox(height: TpSpacing.s3),
            FilledButton.icon(
              key: const ValueKey('collab-add-submit'),
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('送出邀請'),
              onPressed: canSubmit ? onSubmit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.enabled,
    required this.onRoleChanged,
  });

  final String selectedRole;
  final bool enabled;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleButton(
            key: const ValueKey('collab-add-role-member'),
            value: 'member',
            selected: selectedRole == 'member',
            enabled: enabled,
            icon: Icons.edit_outlined,
            label: '可編輯',
            onSelected: onRoleChanged,
          ),
        ),
        const SizedBox(width: TpSpacing.s2),
        Expanded(
          child: _RoleButton(
            key: const ValueKey('collab-add-role-viewer'),
            value: 'viewer',
            selected: selectedRole == 'viewer',
            enabled: enabled,
            icon: Icons.visibility_outlined,
            label: '可檢視',
            onSelected: onRoleChanged,
          ),
        ),
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    super.key,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final String value;
  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final onPressed = enabled ? () => onSelected(value) : null;
    if (selected) {
      return FilledButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
      );
    }
    return OutlinedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class _PermissionList extends StatelessWidget {
  const _PermissionList({required this.permissions});

  final List<TripPermission> permissions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, permission) in permissions.indexed) ...[
            ListTile(
              key: ValueKey('collab-row-${permission.id}'),
              leading: Icon(
                permission.isOwner
                    ? Icons.admin_panel_settings_outlined
                    : permission.isViewer
                    ? Icons.visibility_outlined
                    : Icons.edit_outlined,
              ),
              title: Text(permission.displayLabel),
              subtitle: permission.displayLabel == permission.email
                  ? null
                  : Text(permission.email),
              trailing: Text(
                permission.roleLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: permission.isOwner
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (index != permissions.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _PendingInvitationList extends StatelessWidget {
  const _PendingInvitationList({
    required this.invitations,
    required this.revokingEmail,
    required this.onRevoke,
  });

  final List<PendingInvitation> invitations;
  final String? revokingEmail;
  final ValueChanged<PendingInvitation> onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, invitation) in invitations.indexed) ...[
            ListTile(
              key: ValueKey('pending-row-${invitation.invitedEmail}'),
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: Text(invitation.invitedEmail),
              subtitle: Text(invitation.statusLabel),
              trailing: IconButton(
                key: ValueKey('pending-revoke-${invitation.invitedEmail}'),
                tooltip: '撤回邀請',
                icon: revokingEmail == invitation.invitedEmail
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close),
                onPressed: revokingEmail == null
                    ? () => onRevoke(invitation)
                    : null,
              ),
            ),
            if (index != invitations.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(width: TpSpacing.s2),
        Text(
          '$count',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

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
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s3),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
