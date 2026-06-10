import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/poi_tone.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  const tones = TpTones.light;

  void expectTone(
    PoiToneColors actual, {
    required Color base,
    required Color deep,
    required Color subtle,
    required Color bg,
  }) {
    expect(actual.base, base);
    expect(actual.deep, deep);
    expect(actual.subtle, subtle);
    expect(actual.bg, bg);
  }

  group('resolvePoiTone', () {
    test('hotel / transport / parking → sage', () {
      for (final poiType in ['hotel', 'transport', 'parking']) {
        expectTone(
          resolvePoiTone(tones, poiType),
          base: tones.sage,
          deep: tones.sageDeep,
          subtle: tones.sageSubtle,
          bg: tones.sageBg,
        );
      }
    });

    test('restaurant → pink', () {
      expectTone(
        resolvePoiTone(tones, 'restaurant'),
        base: tones.pink,
        deep: tones.pinkDeep,
        subtle: tones.pinkSubtle,
        bg: tones.pinkBg,
      );
    });

    test('其他類型與 null → accent', () {
      for (final poiType in [null, 'attraction', 'shopping', 'activity']) {
        expectTone(
          resolvePoiTone(tones, poiType),
          base: tones.accent,
          deep: tones.accentDeep,
          subtle: tones.accentSubtle,
          bg: tones.accentBg,
        );
      }
    });
  });
}
