import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/dpop/dpop_proof.dart';
import 'package:tripline/api/dpop/proof_key.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/models/trip_request.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.script);

  /// 第 n 次連線回第 n 個（超過用最後一個）。每次都建新的 body，串流只能讀一次。
  final List<ResponseBody Function()> script;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final i = (requests.length - 1).clamp(0, script.length - 1);
    return script[i]();
  }

  @override
  void close({bool force = false}) {}
}

class _Source implements BearerTokenSource, DpopKeyProvider {
  _Source(this.key);
  final ProofKey key;
  String token = 'tok';
  bool refreshOk = false;

  @override
  Future<String?> accessToken() async => token;
  @override
  Future<bool> refresh() async {
    if (refreshOk) token = 'tok-refreshed';
    return refreshOk;
  }

  @override
  Future<ProofKey?> proofKey() async => key;
}

ResponseBody Function() _sse(String body) =>
    () => ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );

ResponseBody _unauthorized() => ResponseBody.fromString(
  jsonEncode({
    'error': {'code': 'AUTH_REQUIRED', 'message': 'x'},
  }),
  401,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

String _frame(String id, String status) =>
    'id: $id\ndata: {"status":"$status","updatedAt":"2026-07-09T01:00:00Z"}\n\n';

String _reconnect(String reason) =>
    'event: reconnect\ndata: {"reason":"$reason"}\n\n';

Map<String, dynamic> _claims(String jwt) =>
    jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1]))),
        )
        as Map<String, dynamic>;

void main() {
  late SoftwareProofKey key;
  late _Source source;

  RequestsRepository repo(_Adapter adapter) => RequestsRepository(
    client: ApiClient(
      dio: Dio()..httpClientAdapter = adapter,
      origin: 'https://api.example',
      bearerSource: source,
    ),
  );

  setUp(() {
    key = SoftwareProofKey.generate();
    source = _Source(key);
  });

  test('直連帶 DPoP：htm=GET、htu 含 request id、ath 對應 access token', () async {
    final adapter = _Adapter([_sse(_frame('1', 'completed'))]);

    await repo(adapter).watchRequestEvents(7).toList();

    final req = adapter.requests.single;
    expect(req.headers['Authorization'], 'DPoP tok');
    final claims = _claims(req.headers['DPoP'] as String);
    expect(claims['htm'], 'GET');
    expect(claims['htu'], 'https://api.example/api/requests/7/events');
    expect(claims['ath'], dpopAccessTokenHash('tok'));
    expect(req.headers.containsKey('Last-Event-ID'), isFalse);
  });

  for (final reason in ['token_expired', 'grant_revoked', 'max_duration']) {
    test('收到 reconnect($reason)：不把它當事件，帶 Last-Event-ID 與新 proof 重連', () async {
      final adapter = _Adapter([
        _sse('${_frame('5', 'processing')}${_reconnect(reason)}'),
        _sse(_frame('6', 'completed')),
      ]);

      final events = await repo(adapter).watchRequestEvents(7).toList();

      expect(events.map((e) => e.status), [
        RequestStatus.processing,
        RequestStatus.completed,
      ]);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[1].headers['Last-Event-ID'], '5');
      expect(
        _claims(adapter.requests[1].headers['DPoP'] as String)['jti'],
        isNot(_claims(adapter.requests[0].headers['DPoP'] as String)['jti']),
      );
    });
  }

  test('重連時用「目前」的 access token 重簽（ath 對應新 token）', () async {
    final adapter = _Adapter([
      _sse(_reconnect('token_expired')),
      _sse(_frame('1', 'completed')),
    ]);
    // 第一次連線結束後 token 被換新（模擬 refresh 完成）。
    final stream = repo(adapter).watchRequestEvents(7);
    final done = stream.toList();
    source.token = 'tok2';
    await done;

    final second = adapter.requests[1].headers['DPoP'] as String;
    expect(
      _claims(second)['ath'],
      anyOf(dpopAccessTokenHash('tok'), dpopAccessTokenHash('tok2')),
    );
    expect(adapter.requests[1].headers['Authorization'], startsWith('DPoP '));
  });

  test(
    '重連時 401 → refresh → 再連：仍帶 Last-Event-ID，proof 的 ath 對應新 token',
    () async {
      source.refreshOk = true;
      final adapter = _Adapter([
        _sse('${_frame('5', 'processing')}${_reconnect('token_expired')}'),
        _unauthorized,
        _sse(_frame('6', 'completed')),
      ]);

      final events = await repo(adapter).watchRequestEvents(7).toList();

      expect(events, hasLength(2));
      expect(adapter.requests, hasLength(3));
      final last = adapter.requests[2];
      expect(last.headers['Last-Event-ID'], '5');
      expect(last.headers['Authorization'], 'DPoP tok-refreshed');
      expect(
        _claims(last.headers['DPoP'] as String)['ath'],
        dpopAccessTokenHash('tok-refreshed'),
      );
    },
  );

  test('重連被拒（401）：把錯誤往上丟，不無限重連', () async {
    final adapter = _Adapter([
      _sse(_reconnect('grant_revoked')),
      _unauthorized,
    ]);

    await expectLater(
      repo(adapter).watchRequestEvents(7).toList(),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
  });

  test('一直收到 reconnect 卻沒有任何新事件：最多重連 3 次後丟錯', () async {
    final adapter = _Adapter([_sse(_reconnect('max_duration'))]);

    await expectLater(
      repo(adapter).watchRequestEvents(7).toList(),
      throwsA(isA<StateError>()),
    );
    expect(adapter.requests, hasLength(4));
  });

  test('有新事件就重置計數：長時間的串流可以重連很多次', () async {
    final adapter = _Adapter([
      for (var i = 1; i <= 6; i++)
        _sse('${_frame('$i', 'processing')}${_reconnect('max_duration')}'),
      _sse(_frame('7', 'completed')),
    ]);

    final events = await repo(adapter).watchRequestEvents(7).toList();

    expect(events, hasLength(7));
    expect(adapter.requests, hasLength(7));
  });

  test('沒有 reconnect 的正常結尾：不重連', () async {
    final adapter = _Adapter([_sse(_frame('1', 'completed'))]);

    await repo(adapter).watchRequestEvents(7).toList();

    expect(adapter.requests, hasLength(1));
  });
}
