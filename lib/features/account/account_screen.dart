/// 帳號 hub 畫面：由 root 畫面右上 avatar 進入，包含 profile、設定與登出。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_content_surface.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_settings_group.dart';
import '../../ui/tp_root_scroll_scaffold.dart';
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
            const _SettingsGroup(compact: true),
            _LogoutRow(onTap: () => _confirmLogout(context, ref)),
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
            _LogoutRow(onTap: () => _confirmLogout(context, ref)),
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

    return TpRootScrollScaffold(
      title: '帳號',
      actions: [
        TpToolbarIconButton(
          key: const ValueKey('account-close-button'),
          tooltip: '關閉',
          onPressed: () {
            final router = GoRouter.maybeOf(context);
            if (router == null) {
              Navigator.of(context).maybePop();
            } else if (router.canPop()) {
              router.pop();
            } else {
              router.go('/trips');
            }
          },
          icon: CupertinoIcons.xmark,
        ),
      ],
      slivers: slivers,
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
  const _SettingsGroup({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return TpSettingsGroup(
        children: [
          TpSettingsRow(
            key: const ValueKey('settings-appearance'),
            title: '外觀',
            onTap: () => _openSheetPage(context, const AppearanceScreen()),
          ),
          TpSettingsRow(
            key: const ValueKey('settings-notifications'),
            title: '通知',
            onTap: () => _openSheetPage(context, const NotificationsScreen()),
          ),
          TpSettingsRow(
            key: const ValueKey('settings-sessions'),
            title: '登入裝置',
            onTap: () => _openSheetPage(context, const AccountSessionsScreen()),
          ),
          TpSettingsRow(
            key: const ValueKey('settings-connected-apps'),
            title: '已連結的應用程式',
            onTap: () => _openSheetPage(context, const ConnectedAppsScreen()),
          ),
          TpSettingsRow(
            key: const ValueKey('settings-developer-apps'),
            title: '開發者 App',
            onTap: () => _openSheetPage(context, const DeveloperAppsScreen()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TpSettingsGroup(
          title: '帳號',
          children: [
            TpSettingsRow(
              key: const ValueKey('settings-profile'),
              leading: const Icon(CupertinoIcons.person),
              title: '個人資料',
              onTap: () => context.push('/settings/profile'),
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
              onTap: () => context.push('/settings/appearance'),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-notifications'),
              leading: const Icon(CupertinoIcons.bell),
              title: '通知',
              onTap: () => context.push('/settings/notifications'),
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
              onTap: () => context.push('/settings/sessions'),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-connected-apps'),
              leading: const Icon(CupertinoIcons.square_grid_2x2),
              title: '已連結的應用程式',
              onTap: () => context.push('/settings/connected-apps'),
            ),
            TpSettingsRow(
              key: const ValueKey('settings-developer-apps'),
              leading: const Icon(
                CupertinoIcons.chevron_left_slash_chevron_right,
              ),
              title: '開發者應用',
              onTap: () => context.push('/settings/developer-apps'),
            ),
          ],
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
