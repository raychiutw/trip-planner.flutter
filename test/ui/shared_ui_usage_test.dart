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

    // 日期選擇器的軌也是導覽玻璃的消費者（#169 改回玻璃）。先前排除它的理由
    // 「玻璃在純色頁面上等於無色」是模擬器的假象。一樣不得自行組裝 settings。
    final selector = File(
      'lib/ui/tp_horizontal_selector.dart',
    ).readAsStringSync();
    expect(selector, contains('tpNavigationGlassSettings('));
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

  test('媒體背景由 TpMediaBackdropScope 宣告;features 不傳 bool、tab bar 不用魔術索引', () {
    final tabBar = File(
      'lib/features/shell/apple_root_tab_bar.dart',
    ).readAsStringSync();
    expect(
      RegExp(r'selectedIndex\s*==\s*\d').hasMatch(tabBar),
      isFalse,
      reason: '「是不是地圖分頁」不能用整數索引猜,要讀 TpMediaBackdropScope。',
    );
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (RegExp(
        r'platformViewBackdrop:\s*(?:true|false)\b',
      ).hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: '媒體背景是 scope,不是 widget 之間手傳的 bool。');
  });
}
