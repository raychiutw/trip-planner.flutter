import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/models/user.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> recordedRequests;
  late AccountRepository accountRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    recordedRequests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          recordedRequests.add(options);
          handler.next(options);
        },
      ),
    );
    final apiClient = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    accountRepository = AccountRepository(client: apiClient);
  });

  test('clonePublicTripShare：POST /share/:token/clone 回傳新 tripId', () async {
    dioAdapter.onPost(
      '/share/share-token/clone',
      (server) => server.reply(200, {'tripId': 'cloned-trip'}),
      data: <String, dynamic>{},
    );

    final tripId = await accountRepository.clonePublicTripShare('share-token');

    expect(tripId, 'cloned-trip');
  });

  test('updateProfile：PATCH /account/profile 回 UserInfo', () async {
    dioAdapter.onPatch(
      '/account/profile',
      (server) => server.reply(200, {
        'id': 'u1hex',
        'email': 'ray@example.com',
        'emailVerified': 1,
        'displayName': '新名字',
        'avatarUrl': null,
        'createdAt': '2026-01-01T00:00:00Z',
      }),
      data: {'displayName': '新名字'},
    );

    final updatedUser = await accountRepository.updateProfile(
      displayName: '新名字',
    );

    expect(updatedUser.displayName, '新名字');
  });

  test('fetchAccountSessions：GET /account/sessions 解析登入裝置', () async {
    dioAdapter.onGet(
      '/account/sessions',
      (server) => server.reply(200, {
        'current_sid': 'sid-current',
        'sessions': [
          {
            'sid': 'sid-current',
            'ua_summary': 'Chrome on Windows',
            'ip_hash_prefix': 'a1b2c3',
            'created_at': '2026-07-01T10:00:00Z',
            'last_seen_at': '2026-07-08T09:30:00Z',
            'is_current': true,
          },
          {
            'sid': 'sid-phone',
            'ua_summary': 'Safari on iPhone',
            'created_at': '2026-07-02T10:00:00Z',
            'last_seen_at': '2026-07-08T08:00:00Z',
            'is_current': false,
          },
        ],
      }),
    );

    final page = await accountRepository.fetchAccountSessions();

    expect(page, isA<AccountSessionsPage>());
    expect(page.currentSid, 'sid-current');
    expect(page.sessions, hasLength(2));
    expect(page.sessions.first.sid, 'sid-current');
    expect(page.sessions.first.uaSummary, 'Chrome on Windows');
    expect(page.sessions.first.ipHashPrefix, 'a1b2c3');
    expect(page.sessions.first.isCurrent, isTrue);
    expect(page.sessions.last.isCurrent, isFalse);
  });

  test('revokeAccountSession：DELETE /account/sessions/:sid', () async {
    dioAdapter.onDelete(
      '/account/sessions/sid-phone',
      (server) => server.reply(200, {'ok': true, 'revoked_sid': 'sid-phone'}),
    );

    await expectLater(
      accountRepository.revokeAccountSession('sid-phone'),
      completes,
    );
  });

  test(
    'updateAccountNotificationPreferences：PATCH /account/notifications',
    () async {
      dioAdapter.onPatch(
        '/account/notifications',
        (server) => server.reply(200, {
          'preferences': {
            'tripUpdates': true,
            'invitations': false,
            'system': false,
            'updatedAt': '2026-07-09T01:00:00Z',
          },
        }),
        data: {'invitations': false, 'system': false},
      );

      final prefs = await accountRepository
          .updateAccountNotificationPreferences(
            invitations: false,
            system: false,
          );

      expect(prefs.invitations, isFalse);
      expect(prefs.system, isFalse);
      expect(prefs.updatedAt, '2026-07-09T01:00:00Z');
    },
  );

  test('updateAccountNotificationPreferences：空 patch 不打 API', () async {
    await expectLater(
      accountRepository.updateAccountNotificationPreferences(),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('revokeConnectedApp：DELETE /account/connected-apps/:clientId', () async {
    dioAdapter.onDelete(
      '/account/connected-apps/tp_alpha',
      (server) =>
          server.reply(200, {'ok': true, 'revoked_client_id': 'tp_alpha'}),
    );

    await expectLater(
      accountRepository.revokeConnectedApp('tp_alpha'),
      completes,
    );
  });

  test('fetchDeveloperApps：GET /dev/apps 解析 developer apps wrapper', () async {
    dioAdapter.onGet(
      '/dev/apps',
      (server) => server.reply(200, {
        'apps': [
          {
            'client_id': 'tp_dev',
            'client_type': 'public',
            'app_name': 'Dev App',
            'app_description': null,
            'homepage_url': 'https://dev.example.com',
            'redirect_uris': ['https://dev.example.com/callback'],
            'allowed_scopes': ['openid', 'profile'],
            'status': 'pending_review',
            'created_at': '2026-07-08T10:00:00Z',
            'updated_at': '2026-07-08T10:00:00Z',
          },
        ],
      }),
    );

    final apps = await accountRepository.fetchDeveloperApps();

    expect(apps.single, isA<DeveloperApp>());
    expect(apps.single.clientId, 'tp_dev');
    expect(apps.single.statusLabel, '待審核');
  });

  test('fetchDeveloperApp：GET /dev/apps/:clientId 解析 app detail', () async {
    dioAdapter.onGet(
      '/dev/apps/tp_alpha',
      (server) => server.reply(200, {
        'client_id': 'tp_alpha',
        'client_type': 'public',
        'app_name': 'Alpha App',
        'app_logo_url': 'https://alpha.example.com/logo.png',
        'homepage_url': 'https://alpha.example.com',
        'redirect_uris': ['https://alpha.example.com/callback'],
        'allowed_scopes': ['openid', 'email'],
        'status': 'active',
        'created_at': '2026-07-09T01:00:00Z',
        'updated_at': '2026-07-09T02:00:00Z',
      }),
    );

    final app = await accountRepository.fetchDeveloperApp('tp_alpha');

    expect(app.clientId, 'tp_alpha');
    expect(app.appLogoUrl, 'https://alpha.example.com/logo.png');
    expect(app.redirectUris, ['https://alpha.example.com/callback']);
  });

  test('createDeveloperApp：POST /dev/apps 建立 OAuth app', () async {
    dioAdapter.onPost(
      '/dev/apps',
      (server) => server.reply(201, {
        'client_id': 'tp_new',
        'client_secret': null,
        'app_name': 'New App',
        'client_type': 'public',
        'status': 'pending_review',
        'redirect_uris': ['https://new.example.com/callback'],
        'allowed_scopes': ['openid', 'email'],
      }),
      data: {
        'app_name': 'New App',
        'client_type': 'public',
        'redirect_uris': ['https://new.example.com/callback'],
        'allowed_scopes': ['openid', 'email'],
        'app_description': null,
        'homepage_url': null,
      },
    );

    final created = await accountRepository.createDeveloperApp(
      appName: ' New App ',
      clientType: 'public',
      redirectUris: const ['https://new.example.com/callback'],
      allowedScopes: const ['openid', 'email'],
    );

    expect(created.clientId, 'tp_new');
    expect(created.clientSecret, isNull);
  });

  test(
    'updateDeveloperApp：PATCH /dev/apps/:clientId 支援清空 nullable 欄位',
    () async {
      dioAdapter.onPatch(
        '/dev/apps/tp_alpha',
        (server) => server.reply(200, {
          'client_id': 'tp_alpha',
          'client_type': 'public',
          'app_name': 'Alpha App 2',
          'app_description': null,
          'app_logo_url': null,
          'homepage_url': 'https://alpha.example.com',
          'redirect_uris': ['https://alpha.example.com/callback'],
          'allowed_scopes': ['openid', 'profile'],
          'status': 'active',
          'created_at': '2026-07-09T01:00:00Z',
          'updated_at': '2026-07-09T03:00:00Z',
        }),
        data: {
          'app_name': 'Alpha App 2',
          'app_description': null,
          'app_logo_url': null,
          'homepage_url': 'https://alpha.example.com',
          'redirect_uris': ['https://alpha.example.com/callback'],
          'allowed_scopes': ['openid', 'profile'],
        },
      );

      final app = await accountRepository.updateDeveloperApp(
        clientId: 'tp_alpha',
        appName: ' Alpha App 2 ',
        clearAppDescription: true,
        clearAppLogoUrl: true,
        homepageUrl: 'https://alpha.example.com',
        redirectUris: [' https://alpha.example.com/callback '],
        allowedScopes: ['openid', 'profile', 'ops:*'],
      );

      expect(app.appName, 'Alpha App 2');
      expect(app.appDescription, isNull);
      expect(app.allowedScopes, ['openid', 'profile']);
    },
  );

  test('updateDeveloperApp：空 patch 不打 API', () async {
    await expectLater(
      accountRepository.updateDeveloperApp(clientId: 'tp_alpha'),
      throwsA(isA<ArgumentError>()),
    );
  });
  test(
    'revokeOtherAccountSessions：DELETE /account/sessions 回 revoked 數量',
    () async {
      dioAdapter.onDelete(
        '/account/sessions',
        (server) => server.reply(200, {'ok': true, 'revoked': 2}),
      );

      final revoked = await accountRepository.revokeOtherAccountSessions();

      expect(revoked, 2);
    },
  );

  test(
    'fetchConnectedApps：GET /account/connected-apps 解析 apps wrapper',
    () async {
      dioAdapter.onGet(
        '/account/connected-apps',
        (server) => server.reply(200, {
          'apps': [
            {
              'client_id': 'tp_alpha',
              'app_name': 'Alpha App',
              'app_description': '同步工具',
              'homepage_url': 'https://alpha.example.com',
              'status': 'active',
              'scopes': ['openid', 'email'],
              'granted_at': 1783500000000,
            },
          ],
        }),
      );

      final apps = await accountRepository.fetchConnectedApps();

      expect(apps.single.clientId, 'tp_alpha');
      expect(apps.single.appName, 'Alpha App');
      expect(apps.single.scopes, ['openid', 'email']);
    },
  );

  test(
    'fetchAccountNotificationPreferences：GET /account/notifications',
    () async {
      dioAdapter.onGet(
        '/account/notifications',
        (server) => server.reply(200, {
          'preferences': {
            'tripUpdates': true,
            'invitations': false,
            'system': true,
            'updatedAt': '2026-07-09T00:00:00Z',
          },
        }),
      );

      final prefs = await accountRepository
          .fetchAccountNotificationPreferences();

      expect(prefs.tripUpdates, isTrue);
      expect(prefs.invitations, isFalse);
      expect(prefs.system, isTrue);
      expect(prefs.updatedAt, '2026-07-09T00:00:00Z');
    },
  );

  test(
    'suspendDeveloperApp：DELETE /dev/apps/:clientId 回 suspended id',
    () async {
      dioAdapter.onDelete(
        '/dev/apps/tp_alpha',
        (server) =>
            server.reply(200, {'ok': true, 'suspended_client_id': 'tp_alpha'}),
      );

      final clientId = await accountRepository.suspendDeveloperApp('tp_alpha');

      expect(clientId, 'tp_alpha');
    },
  );
}
