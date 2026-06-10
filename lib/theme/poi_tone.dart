import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 單一 tone 的 4 階色組（base/deep/subtle/bg），供 POI 元件套色階梯：
/// 卡底 subtle → icon 底 bg → glyph/圓點 deep。
class PoiToneColors {
  const PoiToneColors({
    required this.base,
    required this.deep,
    required this.subtle,
    required this.bg,
  });

  final Color base;
  final Color deep;
  final Color subtle;
  final Color bg;
}

/// poi_type → 三色 tone：玩/看/買=accent、住/移動=sage、吃=pink；未分類視同 accent。
PoiToneColors resolvePoiTone(TpTones tones, String? poiType) {
  switch (poiType) {
    case 'hotel':
    case 'transport':
    case 'parking':
      return PoiToneColors(
        base: tones.sage,
        deep: tones.sageDeep,
        subtle: tones.sageSubtle,
        bg: tones.sageBg,
      );
    case 'restaurant':
      return PoiToneColors(
        base: tones.pink,
        deep: tones.pinkDeep,
        subtle: tones.pinkSubtle,
        bg: tones.pinkBg,
      );
    default:
      return PoiToneColors(
        base: tones.accent,
        deep: tones.accentDeep,
        subtle: tones.accentSubtle,
        bg: tones.accentBg,
      );
  }
}
