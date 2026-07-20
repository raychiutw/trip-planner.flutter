import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// iOS 慣例的尾端左滑刪除外殼。
///
/// [onDelete] 負責確認、刪除及更新資料源；元件本身不直接移除 child，
/// 避免與 provider／repository 更新造成重複移除。
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    super.key,
    required this.dismissKey,
    required this.onDelete,
    required this.child,
    this.backgroundMargin = EdgeInsets.zero,
  });

  final Key dismissKey;
  final Future<void> Function() onDelete;
  final Widget child;
  final EdgeInsetsGeometry backgroundMargin;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      background: _SwipeDeleteBackground(margin: backgroundMargin),
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      child: child,
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground({required this.margin});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Icon(CupertinoIcons.delete, color: scheme.onErrorContainer),
    );
  }
}
