import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式主題只保留系統語意色與單一 tint 契約', () {
    const removedSymbols = [
      'TpColorsLight',
      'TpColorsDark',
      'TpTones',
      'AppTheme.higLight',
      'AppTheme.higDark',
    ];
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final symbol in removedSymbols) {
        if (source.contains(symbol)) {
          violations.add('${entity.path}: $symbol');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('TpSystemColorsLight.tint'));
    expect(mainSource, contains('TpSystemColorsDark.tint'));
    expect(mainSource, isNot(contains('0xFF8A6038')));
    expect(mainSource, isNot(contains('0xFFD0A576')));
  });

  test('Flutter 與 iOS launch surface 不得恢復舊暖白 palette', () {
    const removedPaletteFragments = [
      'fffbf5',
      'a97a4a',
      'cba06e',
      'eadfcf',
      '121214',
    ];
    const canonicalTintFragments = ['8a6038', 'd0a576'];
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync().toLowerCase();
      final normalizedPath = entity.path.replaceAll(r'\', '/');
      for (final fragment in removedPaletteFragments) {
        if (source.contains(fragment)) {
          violations.add('${entity.path}: $fragment');
        }
      }
      if (normalizedPath != 'lib/theme/tokens.dart') {
        for (final fragment in canonicalTintFragments) {
          if (source.contains(fragment)) {
            violations.add('${entity.path}: canonical tint $fragment');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));

    final asset =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/LaunchBackground.colorset/'
                'Contents.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final colors = asset['colors'] as List<dynamic>;
    Map<String, dynamic> componentsAt(int index) {
      final color = colors[index] as Map<String, dynamic>;
      final payload = color['color'] as Map<String, dynamic>;
      return payload['components'] as Map<String, dynamic>;
    }

    expect(componentsAt(0), {
      'alpha': '1.000',
      'red': '1.000',
      'green': '1.000',
      'blue': '1.000',
    });
    expect(componentsAt(1), {
      'alpha': '1.000',
      'red': '0.000',
      'green': '0.000',
      'blue': '0.000',
    });

    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(storyboard, contains('<color red="1" green="1" blue="1" alpha="1"'));
    for (final fragment in removedPaletteFragments) {
      expect(
        storyboard.toLowerCase(),
        isNot(contains(fragment)),
        reason: 'LaunchScreen.storyboard 不得使用舊 palette：$fragment',
      );
    }
  });

  test('產品控制不因 Android 分流回 Material 語意', () {
    final source = File('lib/app/adaptive.dart').readAsStringSync();
    const removedBranches = [
      'showDatePicker(',
      '=> AlertDialog(',
      'showModalBottomSheet<T>(',
      'return TextField(',
      'ScaffoldMessenger.of(context)',
    ];

    for (final branch in removedBranches) {
      expect(
        source,
        isNot(contains(branch)),
        reason: '不得恢復 Android Material 產品分支：$branch',
      );
    }
    expect(source, isNot(contains('0xC7FFFBF5')));
    expect(source, isNot(contains('0xF2FFFBF5')));
    expect(source, isNot(contains('0xFFFFFBF5')));
    expect(source, contains('CalendarDatePicker('));
    expect(source, isNot(contains('CupertinoDatePickerMode.date')));
  });

  test('功能頁共用 HIG notice、confirm 與 alert，不自行建立 Material 分支', () {
    final violations = <String>[];
    const materialAlertAllowlist = {
      // 帳號永久刪除含重新驗證輸入欄，不能降級成一般確認提示。
      'lib/features/account/account_screen.dart': 1,
    };
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in const [
        'ScaffoldMessenger.of(',
        'showAdaptiveDialog<',
      ]) {
        if (source.contains(pattern)) {
          violations.add('${entity.path}: $pattern');
        }
      }
      final normalizedPath = entity.path.replaceAll(r'\', '/');
      final materialAlerts = RegExp(
        r'\bAlertDialog\s*\(',
      ).allMatches(source).length;
      final allowed = materialAlertAllowlist[normalizedPath] ?? 0;
      if (materialAlerts != allowed) {
        violations.add(
          '$normalizedPath: Material AlertDialog $materialAlerts 個，允許 $allowed 個',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('外觀只跟隨系統，Account 不保留第五分頁時代的獨立契約', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final accountSource = File(
      'lib/features/account/account_screen.dart',
    ).readAsStringSync();
    final accountSheetSource = File(
      'lib/features/account/account_sheet.dart',
    ).readAsStringSync();
    final sessionsSource = File(
      'lib/features/account/account_sessions_screen.dart',
    ).readAsStringSync();
    final repositorySource = File(
      'lib/api/trip_repository.dart',
    ).readAsStringSync();
    final userSource = File('lib/models/user.dart').readAsStringSync();

    expect(mainSource, contains('themeMode: ThemeMode.system'));
    expect(mainSource, contains('highContrastTheme:'));
    expect(mainSource, contains('highContrastDarkTheme:'));

    for (final source in [
      mainSource,
      accountSource,
      accountSheetSource,
      sessionsSource,
    ]) {
      expect(source, isNot(contains('themeModeProvider')));
      expect(source, isNot(contains('AppearanceScreen')));
    }
    expect(accountSource, isNot(contains('accountStatsProvider')));
    expect(accountSource, isNot(contains('_ProfileHero')));
    expect(accountSource, isNot(contains('_StatsRow')));
    expect(accountSource, isNot(contains('embedded')));
    expect(repositorySource, isNot(contains('fetchStats')));
    expect(userSource, isNot(contains('AccountStats')));

    expect(
      File(
        'lib/features/account/settings/theme_mode_controller.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/account/settings/appearance_screen.dart').existsSync(),
      isFalse,
    );
  });

  test('無 production consumer 的舊元件與測試不可回復', () {
    const removedFiles = [
      'lib/features/trip_detail/widgets/day_pills.dart',
      'lib/features/trip_detail/widgets/hotel_card.dart',
      'lib/ui/tp_glass_expansion_section.dart',
      'test/features/trip_detail/widgets/day_pills_test.dart',
      'test/features/trip_detail/widgets/hotel_card_test.dart',
    ];

    for (final path in removedFiles) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });

  test('標題列不使用 Large Title，非搜尋 root 不出現頁面搜尋控制', () {
    final largeTitleViolations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in const [
        'CupertinoSliverNavigationBar',
        'SliverAppBar.large',
        'largeTitle:',
        'largeTitleTextStyle',
      ]) {
        if (source.contains(pattern)) {
          largeTitleViolations.add('${entity.path}: $pattern');
        }
      }
    }
    expect(
      largeTitleViolations,
      isEmpty,
      reason: largeTitleViolations.join('\n'),
    );

    const noPageSearchFiles = [
      'lib/features/map/global_map_screen.dart',
      'lib/features/trip_detail/trip_map_screen.dart',
      'lib/features/trip_detail/trip_timeline_screen.dart',
      'lib/features/chat/chat_screen.dart',
      'lib/features/account/account_screen.dart',
      'lib/features/account/account_sessions_screen.dart',
      'lib/features/account/account_sheet.dart',
    ];
    for (final path in noPageSearchFiles) {
      final source = File(path).readAsStringSync();
      for (final pattern in const [
        'AppSearchField(',
        'CupertinoSearchTextField(',
        'SearchAnchor(',
        'SearchBar(',
      ]) {
        expect(
          source,
          isNot(contains(pattern)),
          reason: '$path 不得加入頁面搜尋控制：$pattern',
        );
      }
    }
  });

  test('永久刪除只能揭露動作後點擊，不允許 full swipe 直接執行', () {
    final source = File('lib/ui/swipe_to_delete.dart').readAsStringSync();
    expect(source, contains('autoClose: false'));
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final candidate = entity.readAsStringSync();
      for (final pattern in [
        RegExp(r'\bDismissible\s*\('),
        RegExp(r'\bDismissiblePane\b'),
      ]) {
        if (pattern.hasMatch(candidate)) {
          violations.add('${entity.path}: ${pattern.pattern}');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('時間選擇跟隨系統 12／24 小時偏好，不強制 24 小時', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in const [
        'use24hFormat: true',
        'alwaysUse24HourFormat: true',
        "DateFormat('HH:mm')",
        'DateFormat("HH:mm")',
      ]) {
        if (source.contains(pattern)) {
          violations.add('${entity.path}: $pattern');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    expect(
      File('lib/app/adaptive.dart').readAsStringSync(),
      contains('MediaQuery.alwaysUse24HourFormatOf(context)'),
    );
  });

  test('收藏永久刪除不保留 restore runtime、release workflow 或工具', () {
    final violations = <String>[];
    for (final root in const ['lib', '.github/workflows']) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final source = entity.readAsStringSync();
        for (final pattern in const [
          'restoreFavorite',
          'FAVORITE_RESTORE_ENABLED',
          'favorite_restore_contract',
        ]) {
          if (source.contains(pattern)) {
            violations.add('${entity.path}: $pattern');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    expect(
      File('tool/verify_favorite_restore_contract.sh').existsSync(),
      isFalse,
    );
    expect(
      File(
        'test/workflows/favorite_restore_contract_script_test.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('Router 固定四個 root branches，舊 Account／Appearance 路徑回 Account root', () {
    final source = File('lib/app/router.dart').readAsStringSync();
    expect(
      RegExp(r'StatefulShellBranch\s*\(').allMatches(source),
      hasLength(4),
    );
    for (final path in const [
      "path: '/chat'",
      "path: '/trips'",
      "path: '/map'",
      "path: '/favorites'",
      "path: '/account'",
      "path: '/account/appearance'",
      "path: '/settings/appearance'",
    ]) {
      expect(source, contains(path), reason: path);
    }
    expect(
      RegExp(
        r"path: '/(?:account/appearance|settings/appearance)'[\s\S]{0,120}"
        r"accountSheetAlias\(state, 'root'\)",
      ).allMatches(source),
      hasLength(2),
    );
  });
}
