import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #426 守門:CODING_STANDARDS 規定圖示走 `CupertinoIcons`、進度走 adaptive。
void main() {
  // 票內點名要收斂的檔案;其餘檔案的殘留由後續票處理。
  const migrated = [
    'lib/features/invite/invite_screen.dart',
    'lib/features/favorites/favorites_screen.dart',
    'lib/features/favorites/explore/poi_search_card.dart',
    'lib/features/map/map_location.dart',
    'lib/features/offline/offline_status_banner.dart',
    'lib/app/app_feedback.dart',
    'lib/features/trip_detail/widgets/travel_pill.dart',
    'lib/features/trip_detail/entry_poi_screen.dart',
    'lib/features/trip_detail/entry_add_route_screen.dart',
    'lib/features/trip_detail/trip_notes_screen.dart',
    'lib/features/trips/edit/edit_trip_screen.dart',
    'lib/features/trips/audit/trip_audit_screen.dart',
    'lib/features/trips/share/share_screen.dart',
    'lib/features/trips/health/trip_health_screen.dart',
    'lib/features/share/public_share_screen.dart',
    'lib/features/account/account_sessions_screen.dart',
  ];

  // 登記於 CODING_STANDARDS 的例外:Cupertino 沒有對應符號。
  final allowed = RegExp(
    r'Icons\.(link_off_outlined|directions_walk|directions_car|local_taxi|'
    r'directions_bus|train|tram|flight|directions_boat|directions_bike|route)\b',
  );

  test('已收斂的畫面不再使用 Material Icons（登記例外除外）', () {
    final violations = <String>[];
    for (final path in migrated) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].replaceAll(allowed, '');
        if (RegExp(r'(?<![A-Za-z])Icons\.').hasMatch(line)) {
          violations.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('CircularProgressIndicator 一律用 .adaptive()', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (RegExp(
        r'CircularProgressIndicator\(',
      ).hasMatch(entity.readAsStringSync())) {
        violations.add(entity.path);
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  // #426 第二輪:Material 控制項改走 Tp 元件(lib/ui/tp_*.dart)。
  String stripComments(String source) => source
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  List<String> libFilesMatching(RegExp pattern, {Set<String> skip = const {}}) {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (skip.contains(entity.path)) continue;
      if (pattern.hasMatch(stripComments(entity.readAsStringSync()))) {
        hits.add(entity.path);
      }
    }
    return hits;
  }

  test('全 lib 不再使用 Material Checkbox／Chip／SegmentedButton／Dropdown／線性進度', () {
    final hits = libFilesMatching(
      RegExp(
        r'(?<![A-Za-z])(Checkbox|FilterChip|ChoiceChip|ActionChip|'
        r'SegmentedButton|DropdownButton|DropdownButtonFormField|'
        r'DropdownMenuItem|LinearProgressIndicator)\b',
      ),
    );
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('衝突解決 sheet 與 TpStateView 不再用 Card／FilledButton', () {
    final hits = libFilesMatching(
      RegExp(r'(?<![A-Za-z])(Card|FilledButton)\('),
      skip: {
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              f.path != 'lib/features/offline/conflict_resolve_sheet.dart' &&
              f.path != 'lib/ui/tp_state_view.dart')
            f.path,
      },
    );
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('登入裝置／已連結應用／開發者應用三頁用 TpGroupedSurface,不自組 Card', () {
    for (final path in [
      'lib/features/account/account_sessions_screen.dart',
      'lib/features/account/connected_apps_screen.dart',
      'lib/features/account/developer_apps_screen.dart',
    ]) {
      final source = stripComments(File(path).readAsStringSync());
      expect(source, contains('TpGroupedSurface'), reason: path);
      expect(
        RegExp(r'(?<![A-Za-z])Card\(').hasMatch(source),
        isFalse,
        reason: '$path 仍有 Card(',
      );
    }
  });
}
