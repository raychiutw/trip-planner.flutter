/// 帳號 hub 畫面：由內容頁右上角 Account sheet 開啟，包含 profile、設定與登出。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/auth_repository.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_version.dart';
import '../../app/external_links.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_content_surface.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_settings_group.dart';
import 'account_sessions_screen.dart';
import 'connected_apps_screen.dart';
import 'developer_apps_screen.dart';
import 'settings/appearance_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/profile_edit_screen.dart';

/// 帳號統計（GET /account/stats）。
final accountStatsProvider = FutureProvider<AccountStats>(
  (ref) => ref.watch(tripRepositoryProvider).fetchStats(),
);

/// 帳號 hub。
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  late final FocusNode _nameFocusNode;
  bool _editingName = false;
  bool _savingName = false;
  String _nameBaseline = '';
  String? _nameError;
  UserInfo? _profileOverride;
  bool _loadingAccountDeletion = false;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode(onKeyEvent: _handleNameKeyEvent)
      ..addListener(_handleNameFocusChange);
  }

  @override
  void dispose() {
    _nameFocusNode
      ..removeListener(_handleNameFocusChange)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    // 未登入（含登出後）由 router redirect 導向 /login，這裡不渲染內容。
    if (currentUser == null) {
      return widget.embedded
          ? const SizedBox.shrink()
          : const Scaffold(body: SizedBox.shrink());
    }
    final effectiveUser = _effectiveUser(currentUser);

    final accountStats = widget.embedded
        ? null
        : ref.watch(accountStatsProvider).value;

    final content = widget.embedded
        ? <Widget>[
            TpSettingsGroup(
              children: [
                TpSettingsRow(
                  key: const ValueKey('account-sheet-profile'),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(
                      context,
                    ).extension<TpTones>()!.accentBg,
                    child: Text(
                      _resolveDisplayName(
                        effectiveUser,
                      ).characters.first.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).extension<TpTones>()!.accentDeep,
                      ),
                    ),
                  ),
                  title: _resolveDisplayName(effectiveUser),
                  subtitle: '帳號資訊與個人資料',
                  onTap: () =>
                      _openSheetPage(context, const ProfileEditScreen()),
                ),
              ],
            ),
            const _SettingsGroup(embedded: true),
            _PrivacyAndAccountGroup(
              loadingDeletion: _loadingAccountDeletion,
              onPrivacyPolicy: openPrivacyPolicy,
              onDeleteAccount: _confirmDeleteAccount,
            ),
            _LogoutRow(onTap: () => _confirmLogout(context, ref)),
            const _VersionFooter(),
          ]
        : <Widget>[
            Padding(
              padding: const EdgeInsets.all(TpSpacing.s4),
              child: _ProfileHero(
                user: effectiveUser,
                editingName: _editingName,
                savingName: _savingName,
                nameError: _nameError,
                nameController: _nameController,
                nameFocusNode: _nameFocusNode,
                onEditName: () => _startEditName(effectiveUser),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
              child: _StatsRow(stats: accountStats),
            ),
            const SizedBox(height: TpSpacing.s2),
            const _SettingsGroup(),
            _PrivacyAndAccountGroup(
              loadingDeletion: _loadingAccountDeletion,
              onPrivacyPolicy: openPrivacyPolicy,
              onDeleteAccount: _confirmDeleteAccount,
            ),
            _LogoutRow(onTap: () => _confirmLogout(context, ref)),
            const _VersionFooter(),
          ];

    final slivers = [
      SliverPadding(
        padding: EdgeInsets.zero,
        sliver: SliverList(delegate: SliverChildListDelegate([...content])),
      ),
    ];

    if (widget.embedded) {
      return CustomScrollView(
        key: const ValueKey('account-sheet-content'),
        slivers: slivers,
      );
    }

    return Scaffold(
      appBar: TpAppBar(role: TpAppBarRole.standalone, title: const Text('帳號')),
      body: CustomScrollView(
        key: const ValueKey('account-root-content'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          ...slivers,
          SliverToBoxAdapter(
            child: SizedBox(
              height: TpRootTabGeometry.clearance(context) + TpSpacing.s4,
            ),
          ),
        ],
      ),
    );
  }

  UserInfo _effectiveUser(UserInfo currentUser) {
    final updated = _profileOverride;
    if (updated == null) return currentUser;
    if (updated.id == currentUser.id && updated.email == currentUser.email) {
      return updated;
    }
    return currentUser;
  }

  KeyEventResult _handleNameKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _editingName) {
      _cancelEditName();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleNameFocusChange() {
    if (_editingName && !_nameFocusNode.hasFocus && !_savingName) {
      unawaited(_commitEditName());
    }
  }

  void _startEditName(UserInfo user) {
    final currentName = user.displayName ?? '';
    _nameController.text = currentName;
    _nameBaseline = currentName;
    setState(() {
      _editingName = true;
      _nameError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editingName) return;
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _cancelEditName() {
    _nameController.text = _nameBaseline;
    setState(() {
      _editingName = false;
      _nameError = null;
    });
    _nameFocusNode.unfocus();
  }

  Future<void> _commitEditName() async {
    if (!_editingName || _savingName) return;
    final trimmed = _nameController.text.trim();
    if (trimmed == _nameBaseline.trim()) {
      if (mounted) setState(() => _editingName = false);
      return;
    }
    setState(() {
      _savingName = true;
      _nameError = null;
    });
    try {
      final updatedUser = await ref
          .read(tripRepositoryProvider)
          .updateProfile(displayName: trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      setState(() {
        _profileOverride = updatedUser;
        _nameBaseline = updatedUser.displayName ?? '';
        _editingName = false;
      });
      ref.invalidate(authStateProvider);
    } on Exception {
      if (mounted) setState(() => _nameError = '儲存失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  /// 登出前確認，確認才呼叫 authStateProvider.logout()。
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirm(
      context,
      title: '登出帳號',
      message: '確定要登出嗎？',
      confirmLabel: '登出',
      isDestructive: true,
    );
    if (ok) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (_loadingAccountDeletion) return;
    setState(() => _loadingAccountDeletion = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final preview = await repository.fetchAccountDeletionPreview();
      if (!mounted) return;
      setState(() => _loadingAccountDeletion = false);
      if (!preview.hasPassword) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            key: const ValueKey('oauth-account-deletion-blocked-dialog'),
            title: const Text('需要重新驗證才能刪除'),
            content: const Text(
              '此帳號沒有可在 App 內重新驗證的密碼。目前無法在 App 內安全地重新驗證，'
              '因此不會送出刪除要求。你可以查看安全刪除方式，使用註冊信箱提出申請。',
            ),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(openAccountDeletionHelp());
                },
                child: const Text('查看安全刪除方式'),
              ),
            ],
          ),
        );
        return;
      }
      final deleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DeleteAccountDialog(
          preview: preview,
          onDelete: (confirmation) => repository.deleteAccount(
            hasPassword: preview.hasPassword,
            confirmation: confirmation,
          ),
        ),
      );
      if (deleted != true || !mounted) return;
      final router = GoRouter.maybeOf(context);
      await ref.read(authStateProvider.notifier).accountDeleted();
      if (!mounted) return;
      if (widget.embedded) Navigator.of(context).pop();
      router?.go('/welcome');
    } on Exception {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('無法載入刪除資訊'),
          content: const Text('請檢查網路連線後再試一次。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingAccountDeletion = false);
    }
  }
}

class _VersionFooter extends ConsumerWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref
        .watch(appVersionProvider)
        .when(
          data: (version) => version.label,
          loading: () => '版本 …',
          error: (_, _) => '版本資訊無法取得',
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s3,
        TpSpacing.s4,
        TpSpacing.s4,
      ),
      child: Text(
        label,
        key: const ValueKey('account-version-footer'),
        textAlign: TextAlign.center,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// displayName 為空時 fallback 至 email local part。
String _resolveDisplayName(UserInfo user) {
  final displayName = user.displayName;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName;
  }
  return user.email.split('@').first;
}

/// 圓形 avatar（首字母大寫）+ 名稱 + email + 未驗證警示。
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.editingName,
    required this.savingName,
    required this.nameController,
    required this.nameFocusNode,
    required this.onEditName,
    this.nameError,
  });

  final UserInfo user;
  final bool editingName;
  final bool savingName;
  final String? nameError;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final resolvedName = _resolveDisplayName(user);

    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: tones.accentBg,
          child: Text(
            resolvedName.characters.first.toUpperCase(),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: tones.accentDeep,
            ),
          ),
        ),
        const SizedBox(height: TpSpacing.s3),
        if (editingName)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: TextField(
              key: const ValueKey('account-edit-name-input'),
              controller: nameController,
              focusNode: nameFocusNode,
              enabled: !savingName,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              maxLength: 50,
              decoration: InputDecoration(
                counterText: '',
                hintText: user.email.split('@').first,
                suffixIcon: savingName
                    ? const Padding(
                        padding: EdgeInsets.all(TpSpacing.s3),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: (_) => nameFocusNode.unfocus(),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(TpRadius.sm),
                  onTap: onEditName,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TpSpacing.s1,
                      vertical: TpSpacing.s1,
                    ),
                    child: Text(
                      resolvedName,
                      style: theme.textTheme.headlineMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('account-edit-name-btn'),
                tooltip: '編輯名稱',
                onPressed: onEditName,
                icon: const Icon(CupertinoIcons.pencil),
              ),
            ],
          ),
        if (nameError != null) ...[
          const SizedBox(height: TpSpacing.s1),
          Text(
            nameError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: TpSpacing.s1),
        Text(
          user.email,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!user.emailVerified) ...[
          const SizedBox(height: TpSpacing.s2),
          _UnverifiedChip(warningColor: tones.warning),
        ],
      ],
    );
  }
}

/// email 未驗證警示 chip（warning tone）。
class _UnverifiedChip extends StatelessWidget {
  const _UnverifiedChip({required this.warningColor});

  final Color warningColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s3,
        vertical: TpSpacing.s1,
      ),
      decoration: ShapeDecoration(
        color: warningColor.withValues(alpha: 0.15),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 14,
            color: warningColor,
          ),
          const SizedBox(width: TpSpacing.s1),
          Text(
            'Email 未驗證',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: warningColor),
          ),
        ],
      ),
    );
  }
}

/// 3 統計卡橫排；同層資訊使用一致的中性內容 surface。
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  /// 載入中或失敗時為 null，顯示「—」。
  final AccountStats? stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: '行程數', value: _formatCount(stats?.tripCount)),
        ),
        const SizedBox(width: TpSpacing.s3),
        Expanded(
          child: _StatCard(
            label: '旅程天數',
            value: _formatCount(stats?.totalDays),
          ),
        ),
        const SizedBox(width: TpSpacing.s3),
        Expanded(
          child: _StatCard(
            label: '旅伴數',
            value: _formatCount(stats?.collaboratorCount),
          ),
        ),
      ],
    );
  }

  String _formatCount(int? count) => count == null ? '—' : '$count';
}

/// 單一統計卡：中性內容 surface + tabular figures。
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TpContentSurface(
      padding: const EdgeInsets.symmetric(
        vertical: TpSpacing.s4,
        horizontal: TpSpacing.s2,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: TpSpacing.s1),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 設定群組：iOS grouped inset 風格,依語意分「帳號」「偏好」「安全性」三 section。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    void open(String location, Widget page) {
      if (embedded) {
        _openSheetPage(context, page);
      } else {
        context.push(location);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded)
          TpSettingsGroup(
            title: '帳號',
            children: [
              TpSettingsRow(
                key: const ValueKey('settings-profile'),
                leading: const Icon(CupertinoIcons.person),
                title: '個人資料',
                onTap: () =>
                    open('/settings/profile', const ProfileEditScreen()),
              ),
            ],
          ),
        TpSettingsGroup(
          title: '偏好',
          children: [
            TpSettingsRow(
              key: const ValueKey('settings-appearance'),
              leading: const Icon(CupertinoIcons.paintbrush),
              title: '外觀',
              onTap: () =>
                  open('/settings/appearance', const AppearanceScreen()),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-notifications'),
              leading: const Icon(CupertinoIcons.bell),
              title: '通知',
              onTap: () =>
                  open('/settings/notifications', const NotificationsScreen()),
            ),
          ],
        ),
        TpSettingsGroup(
          title: '安全性',
          children: [
            TpSettingsRow(
              key: const ValueKey('settings-sessions'),
              leading: const Icon(CupertinoIcons.device_phone_portrait),
              title: '登入裝置',
              onTap: () =>
                  open('/settings/sessions', const AccountSessionsScreen()),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-connected-apps'),
              leading: const Icon(CupertinoIcons.square_grid_2x2),
              title: '已連結的應用程式',
              onTap: () =>
                  open('/settings/connected-apps', const ConnectedAppsScreen()),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-developer-apps'),
              leading: const Icon(
                CupertinoIcons.chevron_left_slash_chevron_right,
              ),
              title: '開發者應用',
              onTap: () =>
                  open('/settings/developer-apps', const DeveloperAppsScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivacyAndAccountGroup extends StatelessWidget {
  const _PrivacyAndAccountGroup({
    required this.loadingDeletion,
    required this.onPrivacyPolicy,
    required this.onDeleteAccount,
  });

  final bool loadingDeletion;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return TpSettingsGroup(
      title: '隱私與帳號',
      children: [
        TpSettingsRow(
          key: const ValueKey('settings-privacy-policy'),
          leading: const Icon(CupertinoIcons.lock_shield),
          title: '隱私權政策',
          onTap: onPrivacyPolicy,
        ),
        TpSettingsRow(
          key: const ValueKey('settings-delete-account'),
          leading: loadingDeletion
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(CupertinoIcons.delete),
          title: '刪除帳號',
          subtitle: loadingDeletion ? '正在載入刪除資訊…' : '永久刪除帳號與擁有的行程',
          destructive: true,
          onTap: loadingDeletion ? null : onDeleteAccount,
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.preview, required this.onDelete});

  final AccountDeletionPreview preview;
  final Future<void> Function(String confirmation) onDelete;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _canSubmit => widget.preview.hasPassword
      ? _controller.text.isNotEmpty
      : _controller.text == 'DELETE';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _error = null);

  Future<void> _delete() async {
    if (!_canSubmit || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onDelete(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'ACCOUNT_DELETE_PASSWORD_INVALID' => '密碼不正確，請重新輸入',
          'ACCOUNT_DELETE_CONFIRM_REQUIRED' => '請輸入確認內容',
          _ => '刪除失敗，請稍後再試',
        };
      });
    } on Exception {
      if (mounted) setState(() => _error = '刪除失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return AlertDialog(
      key: const ValueKey('delete-account-dialog'),
      title: const Text('永久刪除帳號？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '將一併刪除你擁有的 ${preview.tripsOwned} 個行程，'
              '並影響 ${preview.collaboratorsAffected} 位共編者。此操作無法復原。',
            ),
            const SizedBox(height: TpSpacing.s4),
            TextField(
              key: const ValueKey('delete-account-confirmation-field'),
              controller: _controller,
              enabled: !_submitting,
              obscureText: preview.hasPassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: preview.hasPassword ? '目前密碼（重新驗證）' : '輸入 DELETE 確認',
                errorText: _error,
              ),
              onSubmitted: (_) => _delete(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('delete-account-confirm-button'),
          onPressed: _canSubmit && !_submitting ? _delete : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('永久刪除'),
        ),
      ],
    );
  }
}

void _openSheetPage(BuildContext context, Widget page) {
  unawaited(
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page)),
  );
}

/// 登出 destructive row。
class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TpSettingsGroup(
      children: [
        TpSettingsRow(
          title: '登出',
          leading: const Icon(CupertinoIcons.square_arrow_right),
          destructive: true,
          onTap: onTap,
        ),
      ],
    );
  }
}
