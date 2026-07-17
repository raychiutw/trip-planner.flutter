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

/// poi_type 舊 tone 對照。sage／pink 現在映射中性階，只保留 API 相容性。
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
