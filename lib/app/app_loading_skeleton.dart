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

class AppMapLoadingSkeleton extends StatelessWidget {
  const AppMapLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '正在載入地圖',
      child: ExcludeSemantics(
        child: ColoredBox(
          color: colors.surfaceContainer,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapSkeletonPainter(
                    lineColor: colors.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const Positioned(left: 92, top: 112, child: _MapPinSkeleton()),
              const Positioned(right: 76, top: 220, child: _MapPinSkeleton()),
              const Positioned(
                left: 140,
                bottom: 148,
                child: _MapPinSkeleton(),
              ),
              Positioned(
                left: TpSpacing.s4,
                right: TpSpacing.s4,
                bottom: TpSpacing.s4,
                child: Container(
                  height: 104,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(TpRadius.lg),
                  ),
                ),
              ),
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
      padding: const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(TpRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBar(color: colors.surfaceContainerHighest, width: 96),
          const Spacer(),
          _SkeletonBar(color: colors.surfaceContainerHighest),
          const SizedBox(height: TpSpacing.s2),
          _SkeletonBar(color: colors.surfaceContainerHighest, width: 180),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.color, this.width});

  final Color color;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(TpRadius.sm),
    ),
  );
}

class _MapPinSkeleton extends StatelessWidget {
  const _MapPinSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    width: TpSpacing.tapMin,
    height: TpSpacing.tapMin,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: BoxShape.circle,
    ),
  );
}

class _MapSkeletonPainter extends CustomPainter {
  const _MapSkeletonPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final first = Path()
      ..moveTo(0, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.12,
        size.width,
        size.height * 0.34,
      );
    final second = Path()
      ..moveTo(size.width * 0.15, 0)
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.48,
        size.width * 0.48,
        size.height,
      );
    canvas
      ..drawPath(first, paint)
      ..drawPath(second, paint);
  }

  @override
  bool shouldRepaint(covariant _MapSkeletonPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
