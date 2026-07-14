/// 帳號 hub 畫面（tab 5）：profile hero、統計、設定 rows、登出。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/adaptive_content.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// 帳號統計（GET /account/stats）。
final accountStatsProvider = FutureProvider<AccountStats>(
  (ref) => ref.watch(tripRepositoryProvider).fetchStats(),
);

/// 帳號 hub。
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

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
      return const Scaffold(body: SizedBox.shrink());
    }
    final effectiveUser = _effectiveUser(currentUser);

    final accountStats = ref.watch(accountStatsProvider).value;

    return Scaffold(
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.form,
        contentKey: const ValueKey('account-content'),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(pinned: true, title: Text('帳號')),
            SliverPadding(
              padding: const EdgeInsets.all(TpSpacing.s4),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ProfileHero(
                    user: effectiveUser,
                    editingName: _editingName,
                    savingName: _savingName,
                    nameError: _nameError,
                    nameController: _nameController,
                    nameFocusNode: _nameFocusNode,
                    onEditName: () => _startEditName(effectiveUser),
                  ),
                  const SizedBox(height: TpSpacing.s6),
                  _StatsRow(stats: accountStats),
                  const SizedBox(height: TpSpacing.s6),
                  const _SettingsGroup(),
                  const SizedBox(height: TpSpacing.s4),
                  _LogoutRow(onTap: () => _confirmLogout(context, ref)),
                ]),
              ),
            ),
          ],
        ),
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
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('account-edit-name-btn'),
                tooltip: '編輯名稱',
                onPressed: onEditName,
                icon: const Icon(Icons.edit_outlined),
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
          style: theme.textTheme.bodyMedium?.copyWith(
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

/// 3 統計卡橫排；帳號頁分區 categorical 用色（accent/sage/pink）。
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  /// 載入中或失敗時為 null，顯示「—」。
  final AccountStats? stats;

  @override
  Widget build(BuildContext context) {
    final tones = Theme.of(context).extension<TpTones>()!;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '行程數',
            value: _formatCount(stats?.tripCount),
            cardColor: tones.accentSubtle,
            borderColor: tones.accentBg,
          ),
        ),
        const SizedBox(width: TpSpacing.s3),
        Expanded(
          child: _StatCard(
            label: '旅程天數',
            value: _formatCount(stats?.totalDays),
            cardColor: tones.sageSubtle,
            borderColor: tones.sageBg,
          ),
        ),
        const SizedBox(width: TpSpacing.s3),
        Expanded(
          child: _StatCard(
            label: '旅伴數',
            value: _formatCount(stats?.collaboratorCount),
            cardColor: tones.pinkSubtle,
            borderColor: tones.pinkBg,
          ),
        ),
      ],
    );
  }

  String _formatCount(int? count) => count == null ? '—' : '$count';
}

/// 單一統計卡：tone subtle 底 + tone bg hairline、數字 tabular figures。
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.cardColor,
    required this.borderColor,
  });

  final String label;
  final String value;
  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: TpSpacing.s4,
        horizontal: TpSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: borderColor),
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
  const _SettingsGroup();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSection(
          title: '帳號',
          tiles: [
            _SettingsTileData(
              key: const ValueKey('settings-profile'),
              icon: CupertinoIcons.person,
              label: '個人資料',
              onTap: () => context.push('/settings/profile'),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s4),
        _SettingsSection(
          title: '偏好',
          tiles: [
            _SettingsTileData(
              key: const ValueKey('settings-appearance'),
              icon: CupertinoIcons.paintbrush,
              label: '外觀',
              onTap: () => context.push('/settings/appearance'),
            ),
            _SettingsTileData(
              key: const ValueKey('settings-notifications'),
              icon: CupertinoIcons.bell,
              label: '通知',
              onTap: () => context.push('/settings/notifications'),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s4),
        _SettingsSection(
          title: '安全性',
          tiles: [
            _SettingsTileData(
              key: const ValueKey('settings-sessions'),
              icon: CupertinoIcons.device_phone_portrait,
              label: '登入裝置',
              onTap: () => context.push('/settings/sessions'),
            ),
            _SettingsTileData(
              key: const ValueKey('settings-connected-apps'),
              icon: CupertinoIcons.square_grid_2x2,
              label: '已連結的應用程式',
              onTap: () => context.push('/settings/connected-apps'),
            ),
            _SettingsTileData(
              key: const ValueKey('settings-developer-apps'),
              icon: CupertinoIcons.chevron_left_slash_chevron_right,
              label: '開發者應用',
              onTap: () => context.push('/settings/developer-apps'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 單一 grouped inset section 的資料：section 標題 + 一組 tile。
class _SettingsTileData {
  const _SettingsTileData({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// iOS 設定頁常見的 grouped inset section:小灰標題 + 圓角 Card 包住多個 ListTile。
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.tiles});

  final String title;
  final List<_SettingsTileData> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: TpSpacing.s1,
            bottom: TpSpacing.s2,
          ),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ListTile(
                  key: tiles[i].key,
                  leading: Icon(tiles[i].icon),
                  title: Text(tiles[i].label),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: tiles[i].onTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 登出 destructive row。
class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          CupertinoIcons.square_arrow_right,
          size: 20,
          color: colorScheme.error,
        ),
        title: Text(
          '登出',
          style: TextStyle(
            color: colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
