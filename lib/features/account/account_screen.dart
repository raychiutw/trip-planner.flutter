/// 帳號 hub 畫面（tab 5）：profile hero、統計、設定 rows、登出。
library;

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
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final UserInfo user;

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
        Text(resolvedName, style: theme.textTheme.titleLarge),
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

/// 設定群組：「個人資料」「外觀」「登入裝置」「OAuth app」「通知」可進子頁。
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
              ListTile(
                key: const ValueKey('settings-profile'),
                leading: const Icon(Icons.person_outline),
                title: const Text('個人資料'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/profile'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                key: const ValueKey('settings-appearance'),
                leading: const Icon(Icons.palette_outlined),
                title: const Text('外觀'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/appearance'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                key: const ValueKey('settings-sessions'),
                leading: const Icon(Icons.devices_outlined),
                title: const Text('登入裝置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/sessions'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                key: const ValueKey('settings-connected-apps'),
                leading: const Icon(Icons.extension_outlined),
                title: const Text('已連結的應用程式'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/connected-apps'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                key: const ValueKey('settings-developer-apps'),
                leading: const Icon(Icons.code_outlined),
                title: const Text('開發者應用'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/developer-apps'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              ListTile(
                key: const ValueKey('settings-notifications'),
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('通知'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/notifications'),
              ),
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
