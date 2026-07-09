import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/api/share_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ShareRepository repo;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    repo = ShareRepository(
      client: ApiClient(sessionStore: InMemorySessionStore(), dio: dio),
    );
  });

  test('fetchShares：GET /trips/:id/shares → {shares}', () async {
    adapter.onGet(
      '/trips/okinawa/shares',
      (server) => server.reply(200, {
        'shares': [
          {'id': 1, 'label': '給爸媽', 'viewCount': 2, 'revokedAt': null},
        ],
      }),
    );
    final shares = await repo.fetchShares('okinawa');
    expect(shares.single.label, '給爸媽');
    expect(shares.single.isActive, isTrue);
  });

  test('createShare：POST → ShareLink(token/url)', () async {
    adapter.onPost(
      '/trips/okinawa/shares',
      (server) => server.reply(200, {
        'id': 7,
        'token': 'tok',
        'url': '/s/tok',
        'label': '給爸媽',
      }),
      data: {'label': '給爸媽'},
    );
    final link = await repo.createShare('okinawa', label: '給爸媽');
    expect(link.token, 'tok');
    expect(link.url, '/s/tok');
  });

  test('createShare：送出可見區段、期限與匿名設定', () async {
    adapter.onPost(
      '/trips/okinawa/shares',
      (server) => server.reply(200, {
        'id': 8,
        'token': 'tok2',
        'url': '/s/tok2',
        'label': '旅伴',
      }),
      data: {
        'label': '旅伴',
        'visibleSections': ['flights', 'emergency'],
        'expiresAt': 1800000000000,
        'anonymous': true,
      },
    );

    final link = await repo.createShare(
      'okinawa',
      label: '旅伴',
      visibleSections: ['flights', 'emergency'],
      expiresAt: 1800000000000,
      anonymous: true,
    );

    expect(link.id, 8);
    expect(link.token, 'tok2');
  });

  test('updateShare：PATCH {action:update,...patch}', () async {
    adapter.onPatch(
      '/trips/okinawa/shares/7',
      (server) => server.reply(200, {'ok': true, 'updated': true}),
      data: {
        'action': 'update',
        'label': '新名稱',
        'visibleSections': ['checklist'],
        'expiresAt': 1900000000000,
        'anonymous': false,
      },
    );

    await expectLater(
      repo.updateShare(
        'okinawa',
        7,
        label: '新名稱',
        visibleSections: ['checklist'],
        expiresAt: 1900000000000,
        anonymous: false,
      ),
      completes,
    );
  });

  test('updateShare：clearExpiresAt 送出 null', () async {
    adapter.onPatch(
      '/trips/okinawa/shares/7',
      (server) => server.reply(200, {'ok': true, 'updated': true}),
      data: {'action': 'update', 'expiresAt': null},
    );

    await expectLater(
      repo.updateShare('okinawa', 7, clearExpiresAt: true),
      completes,
    );
  });

  test('updateShare：expiresAt 與 clearExpiresAt 互斥', () {
    expect(
      () => repo.updateShare(
        'okinawa',
        7,
        expiresAt: 1900000000000,
        clearExpiresAt: true,
      ),
      throwsArgumentError,
    );
  });

  test('rotateShare：PATCH {action:rotate} → token/url', () async {
    adapter.onPatch(
      '/trips/okinawa/shares/7',
      (server) => server.reply(200, {
        'ok': true,
        'token': 'newtok',
        'url': '/s/newtok',
      }),
      data: {'action': 'rotate'},
    );

    final link = await repo.rotateShare('okinawa', 7);

    expect(link.token, 'newtok');
    expect(link.url, '/s/newtok');
  });

  test('revokeShare：PATCH {action:revoke}', () async {
    adapter.onPatch(
      '/trips/okinawa/shares/7',
      (server) => server.reply(200, {'ok': true, 'revoked': true}),
      data: {'action': 'revoke'},
    );
    await expectLater(repo.revokeShare('okinawa', 7), completes);
  });

  test('deleteShare：DELETE /trips/:id/shares/:shareId', () async {
    adapter.onDelete(
      '/trips/okinawa/shares/7',
      (server) => server.reply(200, {'ok': true, 'deleted': true}),
    );

    await expectLater(repo.deleteShare('okinawa', 7), completes);
  });
}
