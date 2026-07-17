import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 主畫面右上角固定帳號入口。
class TpAccountAvatarButton extends StatelessWidget {
  const TpAccountAvatarButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      key: const ValueKey('account-avatar-button'),
      tooltip: '帳號',
      onPressed: onPressed ?? () => context.push('/account'),
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: colors.surfaceContainerHigh,
        child: Icon(
          CupertinoIcons.person_fill,
          size: 18,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
