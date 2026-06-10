import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/widgets/entry_tone.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  const tones = TpTones.light;

  void expectTone(
    EntryToneColors actual, {
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

  group('resolveEntryTone', () {
    test('hotel / transport / parking → sage', () {
      for (final poiType in ['hotel', 'transport', 'parking']) {
        expectTone(
          resolveEntryTone(tones, poiType),
          base: tones.sage,
          deep: tones.sageDeep,
          subtle: tones.sageSubtle,
          bg: tones.sageBg,
        );
      }
    });

    test('restaurant → pink', () {
      expectTone(
        resolveEntryTone(tones, 'restaurant'),
        base: tones.pink,
        deep: tones.pinkDeep,
        subtle: tones.pinkSubtle,
        bg: tones.pinkBg,
      );
    });

    test('其他類型與 null → accent', () {
      for (final poiType in [null, 'attraction', 'shopping', 'activity']) {
        expectTone(
          resolveEntryTone(tones, poiType),
          base: tones.accent,
          deep: tones.accentDeep,
          subtle: tones.accentSubtle,
          bg: tones.accentBg,
        );
      }
    });
  });
}
