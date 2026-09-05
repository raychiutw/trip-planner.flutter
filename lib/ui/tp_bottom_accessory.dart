import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';

/// Root tab 上方的單一固定高度 accessory host。
///
/// 這個 primitive 只管理材質與幾何；水平分頁由內層 [PageView] 負責，
/// 不介入垂直拖曳或收合狀態。
class TpBottomAccessory extends StatelessWidget {
  const TpBottomAccessory({
    super.key,
    required this.child,
    this.accessoryHeight = height,
  });

  /// V3 mobile rail: 76pt card + 12pt page indicator.
  static const height = 88.0;

  final Widget child;
  final double accessoryHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: TpSpacing.s3,
      right: TpSpacing.s3,
      bottom: TpRootTabGeometry.clearance(context) + TpSpacing.s1,
      child: SizedBox(
        key: const ValueKey('tp-bottom-accessory'),
        height: accessoryHeight,
        child: TpGlassSurface(
          blurSigma: 28,
          platformViewBackdrop: TpMediaBackdropScope.of(context),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: child,
        ),
      ),
    );
  }
}
