import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';

/// Root tab 上方的單一 accessory host，高度由內容依文字尺寸提供。
///
/// 這個 primitive 只管理材質與幾何；水平分頁由內層 [PageView] 負責，
/// 不介入垂直拖曳或收合狀態。
class TpBottomAccessory extends StatelessWidget {
  const TpBottomAccessory({
    super.key,
    required this.child,
    this.accessoryHeight = height,
  });

  /// 一般文字尺寸的基準高度；放大文字由呼叫端傳入所需高度。
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
          platformViewBackdrop: TpMediaBackdropScope.of(context),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: child,
        ),
      ),
    );
  }
}
