/// 帳號 hub 畫面（tab 5）：profile hero、統計、設定 rows、登出。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// 帳號統計（GET /account/stats）。
final accountStatsProvider = FutureProvider<AccountStats>(
  (ref) => ref.watch(tripRepositoryProvider).fetchStats(),
);

/// 帳號 hub。
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    // 未登入（含登出後）由 router redirect 導向 /login，這裡不渲染內容。
    if (currentUser == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final accountStats = ref.watch(accountStatsProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('帳號')),
      body: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          const SizedBox(height: TpSpacing.s4),
          _ProfileHero(user: currentUser),
          const SizedBox(height: TpSpacing.s6),
          _StatsRow(stats: accountStats),
          const SizedBox(height: TpSpacing.s6),
          const _SettingsGroup(),
          const SizedBox(height: TpSpacing.s4),
          _LogoutRow(onTap: () => _confirmLogout(context, ref)),
        ],
      ),
    );
  }

  /// 登出前 AlertDialog 確認，確認才呼叫 authStateProvider.logout()。
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(TpRadius.xl)),
          ),
          title: const Text('登出帳號'),
          content: const Text('確定要登出嗎？'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: const StadiumBorder(),
                foregroundColor: colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('登出'),
            ),
          ],
        );
      },
    );
    if (shouldLogout == true) {
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
class _ProfileHero extends ConsumerStatefulWidget {
  const _ProfileHero({required this.user});

  final UserInfo user;

  @override
  ConsumerState<_ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends ConsumerState<_ProfileHero> {
  final _displayNameController = TextEditingController();
  final _displayNameFocusNode = FocusNode();
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.user.displayName?.trim() ?? '';
    _displayNameFocusNode.addListener(_handleDisplayNameFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ProfileHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.user.displayName != widget.user.displayName) {
      _displayNameController.text = widget.user.displayName?.trim() ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameFocusNode.removeListener(_handleDisplayNameFocusChange);
    _displayNameFocusNode.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _handleDisplayNameFocusChange() {
    if (!_displayNameFocusNode.hasFocus && _isEditing) {
      unawaited(_saveDisplayName());
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _errorText = null;
      _displayNameController.text = widget.user.displayName?.trim() ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _displayNameFocusNode.requestFocus();
      _displayNameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _displayNameController.text.length,
      );
    });
  }

  Future<void> _saveDisplayName() async {
    if (_isSaving || !_isEditing) return;

    final nextDisplayName = _normalizedDisplayName(_displayNameController.text);
    final currentDisplayName = _normalizedDisplayName(
      widget.user.displayName ?? '',
    );
    if (nextDisplayName == currentDisplayName) {
      setState(() {
        _isEditing = false;
        _errorText = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .updateProfile(displayName: nextDisplayName);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = '無法更新顯示名稱';
      });
    }
  }

  String? _normalizedDisplayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final resolvedName = _resolveDisplayName(widget.user);

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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isEditing
              ? _DisplayNameField(
                  controller: _displayNameController,
                  focusNode: _displayNameFocusNode,
                  errorText: _errorText,
                  isSaving: _isSaving,
                  onSubmitted: _saveDisplayName,
                )
              : _DisplayNameLabel(
                  displayName: resolvedName,
                  onEdit: _startEditing,
                ),
        ),
        const SizedBox(height: TpSpacing.s1),
        Text(
          widget.user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!widget.user.emailVerified) ...[
          const SizedBox(height: TpSpacing.s2),
          _UnverifiedChip(warningColor: tones.warning),
        ],
      ],
    );
  }
}

/// 可點擊編輯的 displayName label。
class _DisplayNameLabel extends StatelessWidget {
  const _DisplayNameLabel({required this.displayName, required this.onEdit});

  final String displayName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: const ValueKey('account-display-name-label'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: TpSpacing.s1),
        IconButton(
          key: const Key('account-display-name-edit'),
          tooltip: '編輯顯示名稱',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
      ],
    );
  }
}

/// displayName inline 編輯欄位；失焦或送出都會儲存。
class _DisplayNameField extends StatelessWidget {
  const _DisplayNameField({
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.isSaving,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final bool isSaving;
  final Future<void> Function() onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('account-display-name-field-shell'),
      constraints: const BoxConstraints(maxWidth: 320),
      child: TextField(
        key: const Key('account-display-name-field'),
        controller: controller,
        focusNode: focusNode,
        enabled: !isSaving,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '顯示名稱',
          errorText: errorText,
          isDense: true,
          suffixIcon: isSaving
              ? const Padding(
                  padding: EdgeInsets.all(TpSpacing.s3),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  key: const Key('account-display-name-save'),
                  tooltip: '儲存顯示名稱',
                  onPressed: () => unawaited(onSubmitted()),
                  icon: const Icon(Icons.check),
                ),
        ),
        onSubmitted: (_) => unawaited(onSubmitted()),
        onTapOutside: (_) => focusNode.unfocus(),
      ),
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
          Icon(Icons.error_outline, size: 14, color: warningColor),
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

/// 設定群組：外觀與通知子頁入口。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup();

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
            '設定',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SettingsNavigationRow(
                icon: Icons.palette_outlined,
                title: '外觀',
                onTap: () => context.go('/account/appearance'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              _SettingsNavigationRow(
                icon: Icons.notifications_outlined,
                title: '通知',
                onTap: () => context.go('/account/notifications'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 可進入設定子頁的 row。
class _SettingsNavigationRow extends StatelessWidget {
  const _SettingsNavigationRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
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
        leading: Icon(Icons.logout, size: 20, color: colorScheme.error),
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
