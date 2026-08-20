/// 帳號 hub 畫面：由內容頁右上角 Account sheet 開啟，包含 profile、設定與登出。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/auth_repository.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_version.dart';
import '../../app/external_links.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_settings_group.dart';
import 'account_sessions_screen.dart';
import 'connected_apps_screen.dart';
import 'developer_apps_screen.dart';
import 'settings/appearance_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/profile_edit_screen.dart';
import 'settings/theme_mode_controller.dart';

/// 帳號 hub。
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _loadingAccountDeletion = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    // 未登入（含登出後）由 router redirect 導向 /login，這裡不渲染內容。
    if (currentUser == null) return const SizedBox.shrink();

    return CustomScrollView(
      key: const ValueKey('account-sheet-content'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.zero,
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              TpSettingsGroup(
                children: [
                  TpSettingsRow(
                    key: const ValueKey('account-sheet-profile'),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        _resolveDisplayName(
                          currentUser,
                        ).characters.first.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: _resolveDisplayName(currentUser),
                    subtitle: '帳號資訊與個人資料',
                    onTap: () =>
                        _openSheetPage(context, const ProfileEditScreen()),
                  ),
                ],
              ),
              const _SettingsGroup(),
              _PrivacyAndAccountGroup(
                loadingDeletion: _loadingAccountDeletion,
                onPrivacyPolicy: openPrivacyPolicy,
                onDeleteAccount: _confirmDeleteAccount,
              ),
              _LogoutRow(onTap: () => _confirmLogout(context, ref)),
              const _VersionFooter(),
            ]),
          ),
        ),
      ],
    );
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
        final viewHelp = await showAppConfirm(
          context,
          title: '需要重新驗證才能刪除',
          message:
              '此帳號沒有可在 App 內重新驗證的密碼。目前無法在 App 內安全地重新驗證，'
              '因此不會送出刪除要求。你可以查看安全刪除方式，使用註冊信箱提出申請。',
          confirmLabel: '查看安全刪除方式',
        );
        if (viewHelp) unawaited(openAccountDeletionHelp());
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
      Navigator.of(context).pop();
      router?.go('/welcome');
    } on Exception {
      if (!mounted) return;
      await showAppAlert(context, title: '無法載入刪除資訊', message: '請檢查網路連線後再試一次。');
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

/// 設定群組：iOS grouped inset 風格,依語意分「帳號」「偏好」「安全性」三 section。
class _SettingsGroup extends ConsumerWidget {
  const _SettingsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(Widget page) => _openSheetPage(context, page);
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TpSettingsGroup(
          title: '偏好',
          children: [
            TpSettingsRow(
              key: const ValueKey('settings-appearance'),
              leading: const Icon(CupertinoIcons.paintbrush),
              title: '外觀',
              value: themeModeLabel(themeMode),
              onTap: () => open(const AppearanceScreen()),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-notifications'),
              leading: const Icon(CupertinoIcons.bell),
              title: '通知',
              onTap: () => open(const NotificationsScreen()),
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
              onTap: () => open(const AccountSessionsScreen()),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-connected-apps'),
              leading: const Icon(CupertinoIcons.square_grid_2x2),
              title: '已連結的應用程式',
              onTap: () => open(const ConnectedAppsScreen()),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-developer-apps'),
              leading: const Icon(
                CupertinoIcons.chevron_left_slash_chevron_right,
              ),
              title: '開發者應用',
              onTap: () => open(const DeveloperAppsScreen()),
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
