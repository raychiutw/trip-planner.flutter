import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';

/// Root tab 上方的單一固定高度 accessory host。
///
/// 這個 primitive 只管理材質與幾何；水平分頁由內層 [PageView] 負責，
/// 不介入垂直拖曳或收合狀態。
class TpBottomAccessory extends StatelessWidget {
  const TpBottomAccessory({super.key, required this.child});

  static const height = 168.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('tp-bottom-accessory'),
      height: height,
      child: TpGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.xl)),
        child: child,
      ),
    );
  }
}
