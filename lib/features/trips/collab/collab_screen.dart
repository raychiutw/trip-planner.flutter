/// 共編設定:已授權成員(改角色/移除)+ 待接受邀請(撤銷)+ 新增成員(email + 角色)。
/// 管理限 owner/admin(否則顯示提示)。owner/admin 列不可改不可移除。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../app/adaptive_content.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../app/irreversible_action.dart';
import '../../../models/trip_member.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_action_item.dart';
import '../../../ui/tp_app_bar.dart';
import 'collab_controller.dart';

const _roleLabels = {
  'owner': '擁有者',
  'admin': '管理員',
  'member': '共編成員',
  'viewer': '檢視成員',
};

String _roleLabel(String r) => _roleLabels[r] ?? r;

enum _MemberAction { member, viewer, remove }

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

  Future<void> _invite(CollabState state) async {
    if (state.adding) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final succeeded = await _ctrl.invite(_email.text, _role);
    if (succeeded) _email.clear();
  }

  Future<void> _runMemberAction(_MemberAction action, TripMember member) async {
    switch (action) {
      case _MemberAction.member:
        await _ctrl.changeRole(member.id, 'member');
      case _MemberAction.viewer:
        await _ctrl.changeRole(member.id, 'viewer');
      case _MemberAction.remove:
        await confirmAndRunIrreversibleAction(
          context,
          source: TpDestructiveConfirmSource.menu,
          title: '移除「${member.email}」？',
          message: '這位成員將失去此行程的存取權，且無法復原。',
          actionLabel: '移除',
          progressLabel: '正在移除…',
          successMessage: '已移除共編成員',
          failureMessage: '移除失敗，原權限已保留',
          action: () => _ctrl.removeMember(member.id),
        );
    }
  }

  Future<void> _revokeInvite(TripInvite invite) {
    return confirmAndRunIrreversibleAction(
      context,
      // 邀請列上的撤銷是直接按鈕、不經選單，alert 仍合規。
      source: TpDestructiveConfirmSource.direct,
      title: '撤銷「${invite.invitedEmail}」的邀請？',
      message: '這封邀請將立即失效，且無法復原。',
      actionLabel: '撤銷',
      progressLabel: '正在撤銷…',
      successMessage: '已撤銷邀請',
      failureMessage: '撤銷失敗，原邀請已保留',
      action: () => _ctrl.revokeInvite(invite.invitedEmail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collabControllerProvider(widget.tripId));

    return Scaffold(
      // 本頁在 StatefulShellRoute 之外、沒有 root tab bar，
      // 帳號入口是這裡唯一的路徑，明文保留。
      appBar: const TpAppBar(
        role: TpAppBarRole.detail,
        title: Text('共編設定'),
        accountEntry: TpAccountAvatarButton(),
      ),
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.form,
        contentKey: const ValueKey('collab-content'),
        child: state.loading
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
                  if (state.error != null)
                    Semantics(
                      key: const ValueKey('collab-page-error'),
                      liveRegion: true,
                      container: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: TpSpacing.s3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _ctrl.retry,
                              child: const Text('重試'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    '已授權成員（${state.members.length}）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  for (final m in state.members) _memberTile(m, state),
                  if (state.invites.isNotEmpty) ...[
                    const SizedBox(height: TpSpacing.s5),
                    Text(
                      '待接受邀請',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: TpSpacing.s2),
                    for (final i in state.invites) _inviteTile(i, state),
                  ],
                  const SizedBox(height: TpSpacing.s5),
                  Text('新增成員', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: TpSpacing.s2),
                  _addRow(state),
                  if (state.actionError != null)
                    Semantics(
                      key: const ValueKey('collab-action-error'),
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: TpSpacing.s2),
                        child: Text(
                          state.actionError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
      subtitle: Text(
        [
          if (m.displayName?.isNotEmpty == true) m.displayName!,
          '角色：${_roleLabel(m.role)}',
        ].join('\n'),
      ),
      trailing: m.isManageable
          ? TpMoreMenuButton<_MemberAction>(
              key: ValueKey('member-actions-${m.id}'),
              tooltip: '成員動作',
              enabled: state.changingId != m.id && state.removingId != m.id,
              items: [
                TpActionItem(
                  key: ValueKey('member-role-member-${m.id}'),
                  value: _MemberAction.member,
                  label: '共編成員',
                  icon: CupertinoIcons.person_2,
                  selected: m.role == 'member',
                ),
                TpActionItem(
                  key: ValueKey('member-role-viewer-${m.id}'),
                  value: _MemberAction.viewer,
                  label: '檢視成員',
                  icon: CupertinoIcons.eye,
                  selected: m.role == 'viewer',
                ),
                TpActionItem(
                  key: ValueKey('member-remove-${m.id}'),
                  value: _MemberAction.remove,
                  label: '移除成員',
                  icon: CupertinoIcons.person_badge_minus,
                  dividerBefore: true,
                  role: TpActionRole.destructive,
                ),
              ],
              onSelected: (action) => _runMemberAction(action, m),
            )
          : null,
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
            : () => _revokeInvite(i),
        child: const Text('撤銷'),
      ),
    );
  }

  Widget _addRow(CollabState state) {
    return AbsorbPointer(
      key: const ValueKey('collab-invite-form'),
      absorbing: state.adding,
      child: ExcludeFocus(
        excluding: state.adding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('collab-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _invite(state),
              decoration: const InputDecoration(
                hintText: 'email',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: TpSpacing.s2),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('共編成員'),
                  selected: _role == 'member',
                  onSelected: (_) => setState(() => _role = 'member'),
                ),
                ChoiceChip(
                  label: const Text('檢視成員'),
                  selected: _role == 'viewer',
                  onSelected: (_) => setState(() => _role = 'viewer'),
                ),
                FilledButton(
                  key: const ValueKey('collab-add'),
                  onPressed: state.adding ? null : () => _invite(state),
                  child: state.adding
                      ? Semantics(
                          key: const ValueKey('collab-invite-progress'),
                          liveRegion: true,
                          label: '正在新增共編成員',
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Text('新增'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
