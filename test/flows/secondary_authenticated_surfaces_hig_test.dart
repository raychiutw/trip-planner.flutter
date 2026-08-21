import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

enum _HeaderContract {
  root,
  authenticatedDetail,
  modalForm,
  accountException,
  authException,
  publicException,
  inviteException,
}

const _screenManifest = <String, Map<String, _HeaderContract>>{
  'lib/features/account/account_screen.dart': {
    'AccountScreen': _HeaderContract.accountException,
  },
  'lib/features/account/account_sessions_screen.dart': {
    'AccountSessionsScreen': _HeaderContract.accountException,
  },
  'lib/features/account/connected_apps_screen.dart': {
    'ConnectedAppsScreen': _HeaderContract.accountException,
  },
  'lib/features/account/developer_apps_screen.dart': {
    'DeveloperAppsScreen': _HeaderContract.accountException,
    'DeveloperAppNewScreen': _HeaderContract.modalForm,
    'DeveloperAppEditScreen': _HeaderContract.modalForm,
  },
  'lib/features/account/settings/notifications_screen.dart': {
    'NotificationsScreen': _HeaderContract.accountException,
  },
  'lib/features/account/settings/appearance_screen.dart': {
    'AppearanceScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/account/settings/profile_edit_screen.dart': {
    'ProfileEditScreen': _HeaderContract.modalForm,
  },
  'lib/features/auth/account_flow_screens.dart': {
    'SignupScreen': _HeaderContract.authException,
    'EmailVerifyPendingScreen': _HeaderContract.authException,
    'ForgotPasswordScreen': _HeaderContract.authException,
    'ResetPasswordScreen': _HeaderContract.authException,
    'VerifyEmailScreen': _HeaderContract.authException,
  },
  'lib/features/auth/login_screen.dart': {
    'LoginScreen': _HeaderContract.authException,
  },
  'lib/features/auth/oauth_consent_screen.dart': {
    'OAuthConsentScreen': _HeaderContract.authException,
  },
  'lib/features/auth/welcome_screen.dart': {
    'WelcomeScreen': _HeaderContract.authException,
  },
  'lib/features/chat/chat_screen.dart': {'ChatScreen': _HeaderContract.root},
  'lib/features/favorites/add_to_trip/add_to_trip_screen.dart': {
    'AddToTripRouteScreen': _HeaderContract.modalForm,
    'AddToTripScreen': _HeaderContract.modalForm,
  },
  'lib/features/favorites/explore/explore_screen.dart': {
    'ExploreScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/favorites/favorites_screen.dart': {
    'FavoritesScreen': _HeaderContract.root,
  },
  'lib/features/invite/invite_screen.dart': {
    'InviteScreen': _HeaderContract.inviteException,
  },
  'lib/features/map/global_map_screen.dart': {
    'GlobalMapScreen': _HeaderContract.root,
  },
  'lib/features/share/public_share_screen.dart': {
    'PublicShareScreen': _HeaderContract.publicException,
  },
  'lib/features/trip_detail/entry_action_route_screen.dart': {
    'EntryActionRouteScreen': _HeaderContract.modalForm,
  },
  'lib/features/trip_detail/entry_add_route_screen.dart': {
    'EntryAddRouteScreen': _HeaderContract.modalForm,
  },
  'lib/features/trip_detail/entry_edit_route_screen.dart': {
    'EntryEditRouteScreen': _HeaderContract.modalForm,
  },
  'lib/features/trip_detail/entry_poi_screen.dart': {
    'EntryPoiScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/trip_detail/trip_map_screen.dart': {
    'TripMapScreen': _HeaderContract.root,
  },
  'lib/features/trip_detail/trip_notes_screen.dart': {
    'TripNotesScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/trip_detail/trip_print_screen.dart': {
    'TripPrintScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/trip_detail/trip_timeline_screen.dart': {
    'TripTimelineScreen': _HeaderContract.root,
  },
  'lib/features/trips/audit/trip_audit_screen.dart': {
    'TripAuditScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/trips/collab/collab_screen.dart': {
    'CollabScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/trips/create/create_trip_screen.dart': {
    'CreateTripScreen': _HeaderContract.modalForm,
  },
  'lib/features/trips/edit/edit_trip_screen.dart': {
    'EditTripScreen': _HeaderContract.modalForm,
  },
  'lib/features/trips/health/trip_health_screen.dart': {
    'TripHealthScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/trips/share/share_screen.dart': {
    'ShareScreen': _HeaderContract.authenticatedDetail,
  },
  'lib/features/trips/trips_list_screen.dart': {
    'TripsListScreen': _HeaderContract.root,
  },
};

const _secondaryAuthenticatedSurfaces = {
  'lib/features/trip_detail/trip_notes_screen.dart': 'trip-notes-content',
  'lib/features/trips/share/share_screen.dart': 'share-content',
  'lib/features/trips/collab/collab_screen.dart': 'collab-content',
  'lib/features/trips/health/trip_health_screen.dart': 'trip-health-content',
  'lib/features/trips/audit/trip_audit_screen.dart': 'trip-audit-content',
  'lib/features/trip_detail/trip_print_screen.dart': 'trip-print-content',
};

Set<String> _discoveredScreenFiles() => {
  for (final entity in Directory('lib').listSync(recursive: true))
    if (entity is File && entity.path.endsWith('_screen.dart'))
      entity.path.replaceAll(r'\', '/'),
  'lib/features/auth/account_flow_screens.dart',
};

Set<String> _declaredScreenConstructors(String path) {
  final source = File(path).readAsStringSync();
  return {
    for (final match in RegExp(
      r'class\s+([A-Z][A-Za-z0-9_]*Screen)\b',
    ).allMatches(source))
      match.group(1)!,
  };
}

Set<String> get _manifestConstructors => {
  for (final screens in _screenManifest.values) ...screens.keys,
};

Set<String> _routerScreenConstructors(String source) => {
  for (final match in RegExp(
    r'\b([A-Z][A-Za-z0-9_]*Screen)\s*\(',
  ).allMatches(source))
    match.group(1)!,
};

Set<String> _unclassifiedScreenFiles(Set<String> discovered) =>
    discovered.difference(_screenManifest.keys.toSet());

Set<String> _unclassifiedRouterConstructors(String routerSource) =>
    _routerScreenConstructors(routerSource).difference(_manifestConstructors);

void main() {
  test('所有 screen constructor 都必須明確分類 Header contract', () {
    final discovered = _discoveredScreenFiles();
    final unclassifiedFiles = _unclassifiedScreenFiles(discovered);
    final staleManifestFiles = _screenManifest.keys.toSet().difference(
      discovered,
    );
    expect(
      unclassifiedFiles,
      isEmpty,
      reason: '未分類 screen 檔案：\n${unclassifiedFiles.join('\n')}',
    );
    expect(
      staleManifestFiles,
      isEmpty,
      reason: 'manifest 指向不存在的 screen 檔案：\n${staleManifestFiles.join('\n')}',
    );

    for (final entry in _screenManifest.entries) {
      final declared = _declaredScreenConstructors(entry.key);
      final classified = entry.value.keys.toSet();
      expect(
        declared,
        classified,
        reason: '${entry.key} 的 constructor 必須逐一明列，禁止 directory 例外',
      );
    }

    final routerSource = File('lib/app/router.dart').readAsStringSync();
    final unclassifiedRoutes = _unclassifiedRouterConstructors(routerSource);
    expect(
      unclassifiedRoutes,
      isEmpty,
      reason: 'router 使用未分類 screen constructor：$unclassifiedRoutes',
    );
  });

  test('Header contract 分類逐檔驗證 root、authenticated detail 與 modal form', () {
    final violations = <String>[];
    for (final entry in _screenManifest.entries) {
      final source = File(entry.key).readAsStringSync();
      final contracts = entry.value.values.toSet();
      if (contracts.contains(_HeaderContract.root) &&
          !source.contains('TpRootScaffold(')) {
        violations.add('${entry.key}: root screen 必須使用 TpRootScaffold');
      }
      if (contracts.contains(_HeaderContract.authenticatedDetail) &&
          !RegExp(
            r'TpAppBar\([\s\S]{0,240}role:\s*TpAppBarRole\.detail',
          ).hasMatch(source)) {
        violations.add('${entry.key}: authenticated detail 缺少 detail TpAppBar');
      }
      if (contracts.contains(_HeaderContract.modalForm) &&
          !source.contains('TpAppBarRole.modalForm')) {
        violations.add('${entry.key}: modal/form 缺少 modalForm TpAppBar');
      }
      if (contracts.any(
            (contract) =>
                contract == _HeaderContract.root ||
                contract == _HeaderContract.authenticatedDetail ||
                contract == _HeaderContract.modalForm,
          ) &&
          (source.contains('SliverAppBar') || source.contains('largeTitle'))) {
        violations.add('${entry.key}: 不得使用 Large Title');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('manifest completeness probe 會攔截新增 standalone authenticated screen', () {
    const syntheticPath =
        'lib/features/trips/example_standalone_authenticated_screen.dart';
    final unclassifiedFiles = _unclassifiedScreenFiles({
      ..._discoveredScreenFiles(),
      syntheticPath,
    });
    expect(unclassifiedFiles, {syntheticPath});

    final routerSource = File('lib/app/router.dart').readAsStringSync();
    final syntheticRouter =
        '$routerSource\n'
        'GoRoute(builder: (_, __) => StandaloneAuthenticatedScreen());';
    expect(_unclassifiedRouterConstructors(syntheticRouter), {
      'StandaloneAuthenticatedScreen',
    });
  });

  test('次要 authenticated surfaces 固定使用 inline Header 與 regular-width 內容', () {
    final violations = <String>[];

    for (final entry in _secondaryAuthenticatedSurfaces.entries) {
      final source = File(entry.key).readAsStringSync();
      if (!RegExp(
        r'TpAppBar\([\s\S]{0,240}role:\s*TpAppBarRole\.detail',
      ).hasMatch(source)) {
        violations.add('${entry.key}: 缺少 detail TpAppBar');
      }
      if (source.contains('SliverAppBar') || source.contains('largeTitle')) {
        violations.add('${entry.key}: 不得使用 Large Title');
      }
      final hasBoundedContent =
          source.contains('AppAdaptiveContent(') &&
          source.contains('AppContentWidth.') &&
          source.contains("ValueKey('${entry.value}')");
      if (!hasBoundedContent) {
        violations.add('${entry.key}: 缺少可驗證的 regular-width 內容邊界');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('固定 bar 不自動附加 Account 入口，帳號入口只在浮動 header 與 shell 外路由明文提供', () {
    final appBar = File('lib/ui/tp_app_bar.dart').readAsStringSync();

    // 帳號入口是 root 層級的動作，固定 bar（detail / modal）不得自動附加。
    expect(appBar, isNot(contains('showsAccount')));
    expect(appBar, isNot(contains('const TpAccountAvatarButton()')));
    // 44pt 玻璃入口本身仍由共用元件擁有，供明文呼叫端使用。
    expect(appBar, contains("ValueKey('account-avatar-button')"));
    expect(appBar, contains('CupertinoIcons.person_crop_circle'));
    expect(appBar, contains('TpSpacing.tapMin'));
    // 內容 Header 的單一直接動作規則不隨帳號入口一起消失。
    expect(appBar, contains('pageActions.length <= 2'));
    expect(appBar, contains('action is TpMoreMenuButton'));

    // 6 個 root 畫面共用的浮動 header 仍固定提供帳號入口。
    expect(
      File('lib/ui/tp_root_scaffold.dart').readAsStringSync(),
      contains('const TpAccountAvatarButton()'),
    );

    // 共編設定與分享設定在 StatefulShellRoute 之外、沒有 root tab bar，
    // 帳號入口是它們唯一的路徑，必須明文保留 —— 且走自成一組的 accountEntry，
    // 不佔內容 Header 的動作額度。
    for (final path in const [
      'lib/features/trips/collab/collab_screen.dart',
      'lib/features/trips/share/share_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('accountEntry: TpAccountAvatarButton()'),
        reason: path,
      );
    }
  });

  test('次要畫面不回復 feature-owned wrapper、內容 Glass 或 40pt 動作', () {
    final notes = File(
      'lib/features/trip_detail/trip_notes_screen.dart',
    ).readAsStringSync();
    final share = File(
      'lib/features/trips/share/share_screen.dart',
    ).readAsStringSync();
    final collaboration = File(
      'lib/features/trips/collab/collab_screen.dart',
    ).readAsStringSync();

    expect(notes, isNot(contains('TpGlassExpansionSection')));
    expect(notes, isNot(contains('TpTones')));
    expect(share, isNot(contains('showDialog')));
    expect(share, isNot(contains('BoxConstraints.tightFor(width: 40')));
    expect(collaboration, isNot(contains('showAppConfirm(')));

    for (final path in const [
      'lib/features/trips/health/trip_health_screen.dart',
      'lib/features/trips/audit/trip_audit_screen.dart',
      'lib/features/trip_detail/trip_print_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('AppAdaptiveContent('), reason: path);
      expect(source, isNot(contains('_contentMaxWidth')), reason: path);
    }
  });
}
