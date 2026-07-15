import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 保留內容版型的靜態載入提示；不使用 shimmer，避免無意義的持續動態。
class AppListLoadingSkeleton extends StatelessWidget {
  const AppListLoadingSkeleton({super.key, this.itemCount = 4})
    : assert(itemCount > 0);

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '正在載入內容',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: Column(
            children: [
              for (var index = 0; index < itemCount; index++) ...[
                const Expanded(child: _ListSkeletonCard()),
                if (index < itemCount - 1) const SizedBox(height: TpSpacing.s3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSkeletonCard extends StatelessWidget {
  const _ListSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(TpSpacing.s1),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(TpRadius.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBar(
            color: colors.surfaceContainerHighest,
            width: 96,
            height: 6,
          ),
          _SkeletonBar(color: colors.surfaceContainerHighest, height: 6),
          _SkeletonBar(
            color: colors.surfaceContainerHighest,
            width: 180,
            height: 6,
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.color, this.width, this.height = 12});

  final Color color;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(TpRadius.sm),
    ),
  );
}
