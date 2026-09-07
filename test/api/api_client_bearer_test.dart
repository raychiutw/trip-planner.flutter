import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/session_store.dart';

class _FakeSource implements BearerTokenSource {
  _FakeSource(this._token, {this.refreshResult = false});
  String? _token;
  bool refreshResult;
  int refreshCalls = 0;

  @override
  Future<String?> accessToken() async => _token;

  @override
  Future<bool> refresh() async {
    refreshCalls++;
    if (refreshResult) {
      _token = 'new';
      return true;
    }
    return false;
  }
}

void main() {
  test('Bearer 模式：送 Authorization,不送 Cookie/Origin', () async {
    final dio = Dio();
    late Map<String, dynamic> captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          captured = o.headers;
          h.resolve(
            Response(requestOptions: o, statusCode: 200, data: {'ok': true}),
          );
        },
      ),
    );
    final client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      bearerSource: _FakeSource('tok'),
    );

    await client.post('/x', body: const {});
    expect(captured['Authorization'], 'Bearer tok');
    expect(captured.containsKey('Origin'), isFalse);
    expect(captured.containsKey('Cookie'), isFalse);
  });

  test('Bearer 401 → refresh 成功 → 帶新 token 重試一次 → 200', () async {
    final dio = Dio();
    var calls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls++;
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: calls == 1 ? 401 : 200,
              data: calls == 1
                  ? {
                      'error': {'code': 'AUTH', 'message': 'x'},
                    }
                  : {'ok': true},
            ),
          );
        },
      ),
    );
    final source = _FakeSource('old', refreshResult: true);
    final client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      bearerSource: source,
    );

    final r = await client.get('/x');
    expect(source.refreshCalls, 1);
    expect(calls, 2);
    expect(r, {'ok': true});
  });

  test('Bearer 401 → refresh 失敗 → 丟 ApiError(401),不重試', () async {
    final dio = Dio();
    var calls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls++;
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 401,
              data: {
                'error': {'code': 'AUTH', 'message': 'x'},
              },
            ),
          );
        },
      ),
    );
    final source = _FakeSource('old', refreshResult: false);
    final client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      bearerSource: source,
    );

    await expectLater(
      client.get('/x'),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
    expect(source.refreshCalls, 1);
    expect(calls, 1); // refresh 失敗 → 不重試
  });

  test(
    '無 bearerSource → cookie 模式（mutation 帶 Origin,不帶 Authorization）',
    () async {
      final dio = Dio();
      late Map<String, dynamic> captured;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            captured = o.headers;
            h.resolve(
              Response(requestOptions: o, statusCode: 200, data: {'ok': true}),
            );
          },
        ),
      );
      final store = InMemorySessionStore();
      await store.write('sess');
      final client = ApiClient(sessionStore: store, dio: dio);

      await client.post('/x', body: const {});
      expect(captured['Cookie'], 'tripline_session=sess');
      expect(captured['Origin'], isNotNull);
      expect(captured.containsKey('Authorization'), isFalse);
    },
  );

  test('Bearer 401 → refresh 成功 → POST 也重送一次(不分 method)', () async {
    final dio = Dio();
    var calls = 0;
    final auths = <String?>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls++;
          auths.add(o.headers['Authorization'] as String?);
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: calls == 1 ? 401 : 200,
              data: calls == 1
                  ? {
                      'error': {'code': 'AUTH', 'message': 'x'},
                    }
                  : {'ok': true},
            ),
          );
        },
      ),
    );
    final source = _FakeSource('old', refreshResult: true);
    final client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      bearerSource: source,
    );

    expect(await client.post('/x', body: const {}), {'ok': true});
    expect(calls, 2);
    expect(source.refreshCalls, 1);
    expect(auths, ['Bearer old', 'Bearer new']);
  });

  test('refresh 成功但重送仍 401 → 不再 refresh,丟 ApiError(401)', () async {
    final dio = Dio();
    var calls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls++;
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 401,
              data: {
                'error': {'code': 'AUTH', 'message': 'x'},
              },
            ),
          );
        },
      ),
    );
    final source = _FakeSource('old', refreshResult: true);
    final client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      bearerSource: source,
    );

    await expectLater(
      client.get('/x'),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
    expect(calls, 2);
    expect(source.refreshCalls, 1);
  });

  test('登入 / 註冊的 raw POST 遇 401 不 refresh 也不重送:密碼錯不該把 OAuth 登出', () async {
    final dio = Dio();
    var calls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls++;
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 401,
              data: {
                'error': {'code': 'LOGIN_INVALID', 'message': 'x'},
              },
            ),
          );
        },
      ),
    );
    final source = _FakeSource('old', refreshResult: true);
    final client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      bearerSource: source,
    );

    await expectLater(
      client.postForResponse('/auth/login', body: const {}),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
    expect(calls, 1);
    expect(source.refreshCalls, 0);
  });
}
