import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/models/trip_request.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late RequestsRepository repo;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    repo = RequestsRepository(
      client: ApiClient(sessionStore: InMemorySessionStore(), dio: dio),
    );
  });

  test(
    'fetchRequests：GET /requests 解析 {items,hasMore} + query 帶 limit/sort',
    () async {
      dioAdapter.onGet(
        '/requests',
        (server) => server.reply(200, {
          'items': [
            {
              'id': 1,
              'tripId': 'okinawa',
              'message': 'hi',
              'status': 'completed',
              'reply': '哈囉',
            },
          ],
          'hasMore': true,
        }),
        queryParameters: {'tripId': 'okinawa', 'limit': '20', 'sort': 'desc'},
      );

      final page = await repo.fetchRequests(tripId: 'okinawa');
      expect(page.items.single.id, 1);
      expect(page.items.single.reply, '哈囉');
      expect(page.hasMore, isTrue);
    },
  );

  test('fetchRequests：cursor 帶 before/beforeId', () async {
    dioAdapter.onGet(
      '/requests',
      (server) => server.reply(200, {'items': [], 'hasMore': false}),
      queryParameters: {
        'tripId': 'okinawa',
        'limit': '20',
        'sort': 'desc',
        'before': '2026-06-01',
        'beforeId': '9',
      },
    );

    final page = await repo.fetchRequests(
      tripId: 'okinawa',
      before: '2026-06-01',
      beforeId: 9,
    );
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('sendRequest：POST /requests camelCase {tripId,message}', () async {
    dioAdapter.onPost(
      '/requests',
      (server) => server.reply(201, {
        'id': 7,
        'tripId': 'okinawa',
        'message': '改午餐',
        'status': 'open',
      }),
      data: {'tripId': 'okinawa', 'message': '改午餐'},
    );

    final r = await repo.sendRequest(tripId: 'okinawa', message: '改午餐');
    expect(r.id, 7);
    expect(r.status, RequestStatus.open);
  });

  test('fetchRequest：GET /requests/:id', () async {
    dioAdapter.onGet(
      '/requests/7',
      (server) => server.reply(200, {
        'id': 7,
        'tripId': 'okinawa',
        'message': '改午餐',
        'status': 'completed',
        'reply': '改好了',
      }),
    );

    final r = await repo.fetchRequest(7);
    expect(r.status, RequestStatus.completed);
    expect(r.reply, '改好了');
  });

  test('fetchRequest：401 → ApiError(401)', () async {
    dioAdapter.onGet(
      '/requests/7',
      (server) => server.reply(401, {
        'error': {'code': 'AUTH_REQUIRED', 'message': 'login'},
      }),
    );

    await expectLater(
      repo.fetchRequest(7),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
  });
}
