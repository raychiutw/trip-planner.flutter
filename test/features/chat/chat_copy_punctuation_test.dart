import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 繁體中文文案一律用全形標點：中文字後面接半形逗號再接中文字，視為漏改。
void main() {
  test('聊天功能的文案沒有「中文,中文」式的半形逗號', () {
    final cjkComma = RegExp(r'[一-鿿],[一-鿿]');
    final offenders = <String>[];
    for (final file in Directory(
      'lib/features/chat',
    ).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        if (cjkComma.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
