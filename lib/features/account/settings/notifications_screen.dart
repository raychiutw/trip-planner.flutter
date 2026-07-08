/// 通知設定:後端通知 preference 尚未開放,先對齊 web 版的規劃類型頁。
library;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _plans = [
    _NotificationPlan(
      key: 'trip-update',
      icon: Icons.home_outlined,
      title: '行程更新通知',
      helper: '旅伴改了行程、AI 排程完成',
    ),
    _NotificationPlan(
      key: 'invitation',
      icon: Icons.group_outlined,
      title: '旅伴邀請',
      helper: '收到新的共編邀請',
    ),
    _NotificationPlan(
      key: 'system',
      icon: Icons.info_outline,
      title: '系統通知',
      helper: 'Tripline 維護、版本更新',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: ListView(
        key: const ValueKey('notifications-page'),
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          _StatusPanel(accentColor: tones.accent, accentBg: tones.accentBg),
          const SizedBox(height: TpSpacing.s4),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, plan) in _plans.indexed) ...[
                  _NotificationPlanRow(plan: plan),
                  if (index < _plans.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.accentColor, required this.accentBg});

  final Color accentColor;
  final Color accentBg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s5,
          vertical: TpSpacing.s6,
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: accentBg,
              child: Icon(
                Icons.notifications_outlined,
                color: accentColor,
                size: 28,
              ),
            ),
            const SizedBox(height: TpSpacing.s3),
            Text('即將推出', style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '通知功能還在開發中。下面列的是規劃中的通知類型，未來開放後可以分別開啟或關閉。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPlanRow extends StatelessWidget {
  const _NotificationPlanRow({required this.plan});

  final _NotificationPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('notif-row-${plan.key}'),
      enabled: false,
      leading: Icon(plan.icon),
      title: Text(plan.title),
      subtitle: Text(plan.helper),
      trailing: Text(
        '即將推出',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.disabledColor,
        ),
      ),
    );
  }
}

class _NotificationPlan {
  const _NotificationPlan({
    required this.key,
    required this.icon,
    required this.title,
    required this.helper,
  });

  final String key;
  final IconData icon;
  final String title;
  final String helper;
}
