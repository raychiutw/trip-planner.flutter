import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// 隨 Dynamic Type 放大的最小觸控高度。
///
/// 固定 44 的水平 chip 列在 AX 字級會裁切文字;高度跟著 [TextScaler] 長,
/// 一般字級維持 [TpSpacing.tapMin]。
double scaledTapMin(BuildContext context) => math.max(
  TpSpacing.tapMin,
  MediaQuery.textScalerOf(context).scale(TpSpacing.tapMin),
);

/// 字級放大到 Accessibility Size 一帶(約 iOS AX1 以上)。
///
/// 單列並排塞不下時,用它決定改成上下堆疊,而不是縮字或截斷。
bool isLargeTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= 1.5;
