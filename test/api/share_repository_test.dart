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

  test('revokeShare：PATCH {action:revoke}', () async {
    adapter.onPatch(
      '/trips/okinawa/shares/7',
      (server) => server.reply(200, {'ok': true, 'revoked': true}),
      data: {'action': 'revoke'},
    );
    await expectLater(repo.revokeShare('okinawa', 7), completes);
  });
}
