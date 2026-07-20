import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/tokens.dart';

/// iOS 慣例的尾端左滑刪除外殼。
///
/// 手勢只揭露紅色動作；[onDelete] 負責確認、刪除與資料更新。
class SwipeToDelete extends StatefulWidget {
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
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const _groupTag = 'tripline-delete-actions';
  static const _actionWidth = 92.0;
  late final SlidableController _controller;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _controller = SlidableController(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runDelete() async {
    if (_running) return;
    _running = true;
    try {
      await widget.onDelete();
    } finally {
      _running = false;
      if (mounted) {
        await _controller.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.actionLabel): () =>
            unawaited(_runDelete()),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extentRatio = constraints.maxWidth.isFinite
              ? (_actionWidth / constraints.maxWidth).clamp(0.0, 1.0)
              : 0.24;
          return Slidable(
            key: widget.dismissKey,
            controller: _controller,
            groupTag: _groupTag,
            closeOnScroll: true,
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: extentRatio,
              children: [
                CustomSlidableAction(
                  autoClose: false,
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  onPressed: (_) => unawaited(_runDelete()),
                  child: Container(
                    key: ValueKey<Object>((
                      'swipe-delete-action',
                      widget.dismissKey,
                    )),
                    width: double.infinity,
                    height: double.infinity,
                    margin: widget.backgroundMargin,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(TpRadius.md),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.delete, color: scheme.onError),
                          const SizedBox(height: TpSpacing.s1),
                          Text(
                            widget.actionLabel,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: scheme.onError,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}
