import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 單一 tone 的 4 階色組（base/deep/subtle/bg），供 timeline 元件套色階梯：
/// 卡底 subtle → icon 底 bg → glyph/圓點 deep。
class EntryToneColors {
  const EntryToneColors({
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
EntryToneColors resolveEntryTone(TpTones tones, String? poiType) {
  switch (poiType) {
    case 'hotel':
    case 'transport':
    case 'parking':
      return EntryToneColors(
        base: tones.sage,
        deep: tones.sageDeep,
        subtle: tones.sageSubtle,
        bg: tones.sageBg,
      );
    case 'restaurant':
      return EntryToneColors(
        base: tones.pink,
        deep: tones.pinkDeep,
        subtle: tones.pinkSubtle,
        bg: tones.pinkBg,
      );
    default:
      return EntryToneColors(
        base: tones.accent,
        deep: tones.accentDeep,
        subtle: tones.accentSubtle,
        bg: tones.accentBg,
      );
  }
}
