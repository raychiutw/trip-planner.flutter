import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature screens use shared app bar and root scaffold primitives', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (RegExp(
        r'\b(?:AppBar|SliverAppBar|GlassAppBar)\s*\(',
      ).hasMatch(source)) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Root/detail title geometry must come from TpRootScaffold or TpAppBar.',
    );
  });

  test('legacy root scaffold and feature-owned map app bar cannot return', () {
    expect(File('lib/ui/tp_root_scroll_scaffold.dart').existsSync(), isFalse);

    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('TpRootScrollScaffold') ||
          source.contains('_MapRootAppBar')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('features use only semantic app sheet wrappers', () {
    const forbidden = [
      'showModalBottomSheet',
      'showCupertinoModalPopup',
      'showGeneralDialog',
      'showAppLargeSheet',
      'showAppLargeScreenSheet',
    ];
    final violations = <String>[];

    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final token in forbidden) {
        if (source.contains(token)) violations.add('${entity.path}: $token');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
