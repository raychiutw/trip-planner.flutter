import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/dpop/dpop_proof.dart';
import 'package:tripline/api/dpop/proof_key.dart';

class _Source implements BearerTokenSource, DpopKeyProvider {
  _Source(this.token, {this.key, this.refreshTo});
  String token;
  ProofKey? key;
  String? refreshTo;

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<bool> refresh() async {
    final next = refreshTo;
    if (next == null) return false;
    token = next;
    return true;
  }

  @override
  Future<ProofKey?> proofKey() async => key;
}

Map<String, dynamic> _claims(String jwt) =>
    jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1]))),
        )
        as Map<String, dynamic>;

void main() {
  late List<RequestOptions> sent;
  late Response<dynamic> Function(RequestOptions, int call) answer;
  late SoftwareProofKey key;

  ApiClient client(_Source source) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          h.resolve(answer(o, sent.length));
        },
      ),
    );
    return ApiClient(
      dio: dio,
      origin: 'https://api.example',
      bearerSource: source,
    );
  }

  Response<dynamic> ok(RequestOptions o) =>
      Response(requestOptions: o, statusCode: 200, data: {'ok': true});

  Response<dynamic> invalidProof(RequestOptions o, {String? date}) => Response(
    requestOptions: o,
    statusCode: 400,
    data: {'error': 'invalid_dpop_proof'},
    headers: Headers.fromMap({
      if (date != null) 'date': [date],
    }),
  );

  setUp(() {
    sent = [];
    answer = (o, _) => ok(o);
    key = SoftwareProofKey.generate();
  });

  String proofOf(int i) => sent[i].headers['DPoP'] as String;

  test('有金鑰：Authorization: DPoP 加 proof（htm、htu 忽略 query、ath）', () async {
    final c = client(_Source('tok', key: key));

    await c.get('/trips', query: {'a': '1'});

    expect(sent.single.headers['Authorization'], 'DPoP tok');
    final claims = _claims(proofOf(0));
    expect(claims['htm'], 'GET');
    expect(claims['htu'], 'https://api.example/api/trips');
    expect(claims['ath'], dpopAccessTokenHash('tok'));
  });

  test('沒有金鑰：維持 Bearer，不帶 DPoP header', () async {
    final c = client(_Source('tok'));

    await c.get('/trips');

    expect(sent.single.headers['Authorization'], 'Bearer tok');
    expect(sent.single.headers.containsKey('DPoP'), isFalse);
  });

  test('每個請求的 jti 都不同', () async {
    final c = client(_Source('tok', key: key));

    await c.get('/a');
    await c.get('/a');

    expect(_claims(proofOf(0))['jti'], isNot(_claims(proofOf(1))['jti']));
  });

  test('POST 的 htm 是 POST', () async {
    final c = client(_Source('tok', key: key));

    await c.post('/x', body: const {});

    expect(_claims(proofOf(0))['htm'], 'POST');
  });

  test('401 → refresh 後重送：新 proof 的 ath 對應新 token、jti 也是新的', () async {
    answer = (o, n) => n == 1
        ? Response(
            requestOptions: o,
            statusCode: 401,
            data: {
              'error': {'code': 'AUTH', 'message': 'x'},
            },
          )
        : ok(o);
    final c = client(_Source('old', key: key, refreshTo: 'new'));

    await c.get('/trips');

    expect(sent.length, 2);
    expect(sent[1].headers['Authorization'], 'DPoP new');
    expect(_claims(proofOf(1))['ath'], dpopAccessTokenHash('new'));
    expect(_claims(proofOf(1))['jti'], isNot(_claims(proofOf(0))['jti']));
  });

  group('時鐘校正', () {
    // 伺服器比手機快 10 分鐘。
    final serverNow = DateTime.now().toUtc().add(const Duration(minutes: 10));
    String httpDate(DateTime t) => HttpDate.format(t);

    test('400 invalid_dpop_proof → 用 Date 校正後重送一次，之後的請求沿用偏移', () async {
      answer = (o, n) =>
          n == 1 ? invalidProof(o, date: httpDate(serverNow)) : ok(o);
      final c = client(_Source('tok', key: key));

      await c.get('/a');
      await c.get('/b');

      expect(sent.length, 3);
      final skew = serverNow.millisecondsSinceEpoch ~/ 1000;
      for (final i in [1, 2]) {
        expect(
          (_claims(proofOf(i))['iat'] as int) - skew,
          inInclusiveRange(-5, 5),
        );
      }
      // 第一次（未校正）的 iat 是手機時間，差約 600 秒。
      expect(skew - (_claims(proofOf(0))['iat'] as int), greaterThan(500));
    });

    test('校正後仍被拒：只重試一次，丟 ApiError', () async {
      answer = (o, _) => invalidProof(o, date: httpDate(serverNow));
      final c = client(_Source('tok', key: key));

      await expectLater(
        c.get('/a'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'invalid_dpop_proof'),
        ),
      );
      expect(sent.length, 2);
    });

    test('沒有 Date 標頭（無從校正）→ 不重試', () async {
      answer = (o, _) => invalidProof(o);
      final c = client(_Source('tok', key: key));

      await expectLater(c.get('/a'), throwsA(isA<ApiError>()));
      expect(sent.length, 1);
    });

    test('Bearer 模式遇到同樣的 400 不做校正重試', () async {
      answer = (o, _) => invalidProof(o, date: httpDate(serverNow));
      final c = client(_Source('tok'));

      await expectLater(c.get('/a'), throwsA(isA<ApiError>()));
      expect(sent.length, 1);
    });
  });
}
