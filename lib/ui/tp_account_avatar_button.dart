import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import '../app/adaptive.dart';
import '../features/account/account_screen.dart';
import '../theme/app_theme.dart';
import 'tp_app_bar.dart';

/// 主畫面右上角固定帳號入口。
class TpAccountAvatarButton extends ConsumerWidget {
  const TpAccountAvatarButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName?.trim();
    final fallback = user?.email.split('@').first.trim();
    final label = switch ((displayName, fallback)) {
      (final String name, _) when name.isNotEmpty => name,
      (_, final String email) when email.isNotEmpty => email,
      _ => '?',
    };
    final initial = label.characters.first.toUpperCase();
    return TpToolbarGlassButton(
      key: const ValueKey('account-avatar-button'),
      tooltip: '帳號',
      onPressed:
          onPressed ??
          () {
            showAppContentSheet<void>(
              context,
              title: '帳號',
              builder: (_) => const AccountScreen(embedded: true),
            );
          },
      child: Text(
        initial,
        style: theme.textTheme.labelLarge?.copyWith(
          color: tones.accentDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
