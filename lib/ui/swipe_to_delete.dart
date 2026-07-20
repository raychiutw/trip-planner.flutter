import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

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
    this.actionLabel = '刪除',
    this.backgroundMargin = EdgeInsets.zero,
  });

  final Key dismissKey;
  final Future<void> Function() onDelete;
  final Widget child;
  final String actionLabel;
  final EdgeInsetsGeometry backgroundMargin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: actionLabel): () => unawaited(onDelete()),
      },
      child: Dismissible(
        key: dismissKey,
        direction: DismissDirection.endToStart,
        background: _SwipeDeleteBackground(margin: backgroundMargin),
        confirmDismiss: (_) async {
          await onDelete();
          return false;
        },
        child: child,
      ),
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
        color: scheme.error,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: OverflowBox(
        alignment: Alignment.centerRight,
        minWidth: 0,
        maxWidth: double.infinity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.delete, color: scheme.onError),
            const SizedBox(width: TpSpacing.s2),
            Text(
              '刪除',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onError,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
