import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class AppContentWidth {
  /// 登入／註冊／密碼復原等 shell 外的認證卡片。
  ///
  /// 這些畫面是同一張視覺卡片的不同內容，寬度必須一致 —— 先前 `login_screen` 寫死
  /// `400`、`_AuthScaffold` 寫死 `420`，兩份實作各自漂移。
  static const double authCard = 420;

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
