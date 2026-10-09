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
}
