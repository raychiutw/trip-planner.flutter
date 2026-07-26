import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature screens use shared app bar and root scaffold primitives', () {
    const standaloneLandingPages = {'lib/features/auth/welcome_screen.dart'};
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (standaloneLandingPages.contains(normalizedPath)) continue;
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

  test('shared boundaries own platform presentation and map SDK imports', () {
    final violations = <String>[];
    final mapSdkOwners = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (entity.path != 'lib/app/adaptive.dart' &&
          (source.contains('showModalBottomSheet(') ||
              source.contains('showCupertinoModalPopup(') ||
              source.contains('showGeneralDialog('))) {
        violations.add('${entity.path}: platform sheet API');
      }
      if (source.contains(
        "package:google_navigation_flutter/google_navigation_flutter.dart",
      )) {
        mapSdkOwners.add(entity.path.replaceAll('\\', '/'));
      }
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    if (!pubspec.contains('google_navigation_flutter:')) {
      violations.add('pubspec.yaml: missing google_navigation_flutter');
    }
    if (pubspec.contains('google_maps_flutter:')) {
      violations.add('pubspec.yaml: legacy google_maps_flutter');
    }
    expect(mapSdkOwners, ['lib/features/map/map_canvas_mobile.dart']);

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('compact navigation glass has one settings source', () {
    final appBar = File('lib/ui/tp_app_bar.dart').readAsStringSync();
    const consumers = [
      'lib/features/shell/apple_root_tab_bar.dart',
      'lib/ui/tp_root_scaffold.dart',
    ];

    expect(appBar, contains('tpNavigationGlassSettings('));
    expect(appBar, isNot(contains('tpToolbarGlassSettings')));
    for (final path in consumers) {
      final source = File(path).readAsStringSync();
      expect(source, contains('tpNavigationGlassSettings('));
      expect(source, isNot(contains('LiquidGlassSettings(')));
    }

    // 日期選擇器刻意**不是**導覽玻璃的消費者：LiquidGlass shader 會把 tint
    // 衰減到約 14%，而導覽配方的 tint 在淺色是 `surface`（白），疊在白色頁面
    // 上等於無色 —— 實測軌與頁面同為 #FFFFFF。它改用自己畫的半透明填色 +
    // `BackdropFilter`，色值可控。仍然不得自行組裝 glass settings。
    final selector = File(
      'lib/ui/tp_horizontal_selector.dart',
    ).readAsStringSync();
    expect(selector, isNot(contains('tpNavigationGlassSettings(')));
    expect(selector, isNot(contains('LiquidGlassSettings(')));
  });

  test('root and routed headers share title and action geometry owners', () {
    final appBar = File('lib/ui/tp_app_bar.dart').readAsStringSync();
    final rootHeader = File('lib/ui/tp_root_scaffold.dart').readAsStringSync();

    expect(appBar, contains('class TpHeaderTitle'));
    expect(appBar, contains('class TpHeaderActionRow'));
    expect(rootHeader, contains('TpHeaderTitle('));
    expect(rootHeader, contains('TpHeaderActionRow('));
  });

  test('removed compatibility symbols cannot return', () {
    const removed = [
      'TpRootScrollScaffold',
      '_MapRootAppBar',
      'TpMenuAction',
      'AppSheetAction',
      'GoogleTripMapController',
      'kTripMapDarkStyle',
      'showAppLargeSheet',
      'showAppLargeScreenSheet',
    ];
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final symbol in removed) {
        if (source.contains(symbol)) violations.add('${entity.path}: $symbol');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
