/// 帳號 hub 畫面（tab 5）：profile hero、統計、設定 rows、登出。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
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
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(pinned: true, title: Text('帳號')),
          SliverPadding(
            padding: const EdgeInsets.all(TpSpacing.s4),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ProfileHero(user: currentUser),
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

/// 3 個統計值共用一個 iOS grouped 容器；大字級時改為垂直排列。
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  /// 載入中或失敗時為 null，顯示「—」。
  final AccountStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      (label: '行程數', value: _formatCount(stats?.tripCount)),
      (label: '旅程天數', value: _formatCount(stats?.totalDays)),
      (label: '旅伴數', value: _formatCount(stats?.collaboratorCount)),
    ];
    final useVerticalLayout = MediaQuery.textScalerOf(context).scale(14) >= 24;
    final dividerColor = theme.colorScheme.outlineVariant;
    final content = useVerticalLayout
        ? Column(
            children: [
              _StatItem(label: values[0].label, value: values[0].value),
              Divider(height: 1, thickness: 1, color: dividerColor),
              _StatItem(label: values[1].label, value: values[1].value),
              Divider(height: 1, thickness: 1, color: dividerColor),
              _StatItem(label: values[2].label, value: values[2].value),
            ],
          )
        : IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: values[0].label,
                    value: values[0].value,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                Expanded(
                  child: _StatItem(
                    label: values[1].label,
                    value: values[1].value,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                Expanded(
                  child: _StatItem(
                    label: values[2].label,
                    value: values[2].value,
                  ),
                ),
              ],
            ),
          );

    return Semantics(
      key: const ValueKey('account-stats-group'),
      container: true,
      label: values.map((item) => '${item.label} ${item.value}').join('，'),
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
            border: Border.all(color: dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }

  String _formatCount(int? count) => count == null ? '—' : '$count';
}

/// grouped 容器中的單一統計值。
class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
