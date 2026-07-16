import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature screens use shared app bar and root scaffold primitives', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (RegExp(r'\bAppBar\s*\(').hasMatch(source) ||
          source.contains('SliverAppBar.large(')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Root/detail title geometry must come from TpRootScrollScaffold or TpAppBar.',
    );
  });
}
