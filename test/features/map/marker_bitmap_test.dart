import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/marker_bitmap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paintNumberedPinPng 產出非空 PNG(含 PNG 檔頭)', () async {
    final bytes = await paintNumberedPinPng(
      color: const Color(0xFFEF4444),
      number: 3,
      devicePixelRatio: 2,
    );
    expect(bytes, isNotEmpty);
    // PNG magic number: 89 50 4E 47
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('focused pin 與 idle 尺寸不同 → bytes 不同', () async {
    final idle = await paintNumberedPinPng(
      color: const Color(0xFF0EA5E9),
      number: 1,
      devicePixelRatio: 2,
    );
    final focused = await paintNumberedPinPng(
      color: const Color(0xFF0EA5E9),
      number: 1,
      devicePixelRatio: 2,
      focused: true,
    );
    expect(idle, isNot(equals(focused)));
  });

  test('PinBitmapCache 同參數回傳同一 descriptor 實例(cache 命中)', () async {
    final cache = PinBitmapCache();
    final a = await cache.resolve(
      color: const Color(0xFF10B981),
      number: 2,
      devicePixelRatio: 2,
    );
    final b = await cache.resolve(
      color: const Color(0xFF10B981),
      number: 2,
      devicePixelRatio: 2,
    );
    expect(identical(a, b), isTrue);
  });
}
