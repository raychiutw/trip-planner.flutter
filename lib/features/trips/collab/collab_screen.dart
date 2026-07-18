/// 共編設定:已授權成員(改角色/移除)+ 待接受邀請(撤銷)+ 新增成員(email + 角色)。
/// 管理限 owner/admin(否則顯示提示)。owner/admin 列不可改不可移除。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/trip_member.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import 'collab_controller.dart';

const _roleLabels = {
  'owner': '擁有者',
  'admin': '管理員',
  'member': '共編成員',
  'viewer': '檢視成員',
};

String _roleLabel(String r) => _roleLabels[r] ?? r;

class CollabScreen extends ConsumerStatefulWidget {
  const CollabScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<CollabScreen> createState() => _CollabScreenState();
}

class _CollabScreenState extends ConsumerState<CollabScreen> {
  final _email = TextEditingController();
  String _role = 'member';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  CollabController get _ctrl =>
      ref.read(collabControllerProvider(widget.tripId).notifier);

  Future<bool> _confirm(String title, String message) {
    return showAppConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: '確定',
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collabControllerProvider(widget.tripId));

    return Scaffold(
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('共編設定')),
      body: state.loading
          ? const AppListLoadingSkeleton(key: ValueKey('collab-loading'))
          : !state.canManage
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(TpSpacing.s6),
                child: Text('只有行程擁有者或管理者可管理共編。', textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(TpSpacing.s4),
              children: [
                Text(
                  '已授權成員（${state.members.length}）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: TpSpacing.s2),
                for (final m in state.members) _memberTile(m, state),
                if (state.invites.isNotEmpty) ...[
                  const SizedBox(height: TpSpacing.s5),
                  Text('待接受邀請', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: TpSpacing.s2),
                  for (final i in state.invites) _inviteTile(i, state),
                ],
                const SizedBox(height: TpSpacing.s5),
                Text('新增成員', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: TpSpacing.s2),
                _addRow(state),
                if (state.actionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s2),
                    child: Text(
                      state.actionError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _memberTile(TripMember m, CollabState state) {
    return ListTile(
      key: ValueKey('member-${m.id}'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(
          (m.displayName?.isNotEmpty == true ? m.displayName! : m.email)
              .characters
              .first,
        ),
      ),
      title: Text(m.email),
      subtitle: m.displayName == null ? null : Text(m.displayName!),
      trailing: m.isManageable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  key: ValueKey('member-role-${m.id}'),
                  initialValue: m.role,
                  enabled: state.changingId == null,
                  onSelected: (r) => _ctrl.changeRole(m.id, r),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'member', child: Text('共編成員')),
                    PopupMenuItem(value: 'viewer', child: Text('檢視成員')),
                  ],
                  child: Chip(label: Text(_roleLabel(m.role))),
                ),
                IconButton(
                  key: ValueKey('member-remove-${m.id}'),
                  icon: const Icon(CupertinoIcons.person_badge_minus),
                  onPressed: state.removingId == m.id
                      ? null
                      : () async {
                          if (await _confirm(
                            '移除共編成員',
                            '${m.email} 將失去此行程的存取權。確定移除?',
                          )) {
                            await _ctrl.removeMember(m.id);
                          }
                        },
                ),
              ],
            )
          : Chip(label: Text(_roleLabel(m.role))),
    );
  }

  Widget _inviteTile(TripInvite i, CollabState state) {
    final status = i.isExpired
        ? '已過期'
        : (i.daysRemaining != null ? '剩 ${i.daysRemaining} 天' : '待接受');
    return ListTile(
      key: ValueKey('invite-${i.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(CupertinoIcons.mail),
      title: Text(i.invitedEmail),
      subtitle: Text(status),
      trailing: TextButton(
        onPressed: state.revokingEmail == i.invitedEmail
            ? null
            : () async {
                if (await _confirm('撤銷邀請', '對 ${i.invitedEmail} 的邀請將失效。')) {
                  await _ctrl.revokeInvite(i.invitedEmail);
                }
              },
        child: const Text('撤銷'),
      ),
    );
  }

  Widget _addRow(CollabState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('collab-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'email',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: TpSpacing.s2),
        Row(
          children: [
            ChoiceChip(
              label: const Text('共編成員'),
              selected: _role == 'member',
              onSelected: (_) => setState(() => _role = 'member'),
            ),
            const SizedBox(width: TpSpacing.s2),
            ChoiceChip(
              label: const Text('檢視成員'),
              selected: _role == 'viewer',
              onSelected: (_) => setState(() => _role = 'viewer'),
            ),
            const Spacer(),
            FilledButton(
              key: const ValueKey('collab-add'),
              onPressed: state.adding
                  ? null
                  : () {
                      _ctrl.invite(_email.text, _role);
                      _email.clear();
                    },
              child: state.adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Text('新增'),
            ),
          ],
        ),
      ],
    );
  }
}
