import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class AppContentWidth {
  static const double form = 720;
  static const double conversation = 860;
  static const double feed = 920;
}

/// 在寬螢幕置中內容、手機維持全寬；保留父層的完整高度約束。
class AppAdaptiveContent extends StatelessWidget {
  const AppAdaptiveContent({
    super.key,
    required this.maxWidth,
    required this.child,
    this.contentKey,
  });

  final double maxWidth;
  final Widget child;
  final Key? contentKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = math.max(0.0, (constraints.maxWidth - maxWidth) / 2);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sideInset),
          child: SizedBox(
            key: contentKey,
            width: double.infinity,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
