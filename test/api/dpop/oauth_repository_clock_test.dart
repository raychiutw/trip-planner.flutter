import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/dpop/dpop_clock.dart';
import 'package:tripline/api/dpop/proof_key.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';

int _iat(RequestOptions o) =>
    (jsonDecode(
              utf8.decode(
                base64Url.decode(
                  base64Url.normalize(
                    (o.headers['DPoP'] as String).split('.')[1],
                  ),
                ),
              ),
            )
            as Map<String, dynamic>)['iat']
        as int;

void main() {
  late List<RequestOptions> sent;
  late Response<dynamic> Function(RequestOptions, int) answer;
  late DpopClock clock;
  late OAuthRepository repo;
  final key = SoftwareProofKey.generate();
  // 伺服器比手機快 10 分鐘。
  final serverNow = DateTime.now().toUtc().add(const Duration(minutes: 10));

  Response<dynamic> tooSkewed(RequestOptions o) => Response(
    requestOptions: o,
    statusCode: 400,
    data: {'error': 'invalid_dpop_proof'},
    headers: Headers.fromMap({
      'date': [HttpDate.format(serverNow)],
    }),
  );

  Response<dynamic> ok(RequestOptions o) => Response(
    requestOptions: o,
    statusCode: 200,
    data: {'access_token': 'AT', 'refresh_token': 'RT', 'token_type': 'DPoP'},
  );

  setUp(() {
    sent = [];
    clock = DpopClock();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          h.resolve(answer(o, sent.length));
        },
      ),
    );
    repo = OAuthRepository(
      dio: dio,
      origin: 'https://api.example',
      clock: clock,
    );
  });

  test('token 請求被回 invalid_dpop_proof：用 Date 校正後重簽重送一次', () async {
    answer = (o, n) => n == 1 ? tooSkewed(o) : ok(o);

    final tokens = await repo.refresh(
      refreshToken: 'RT',
      clientId: 'cid',
      proofKey: key,
    );

    expect(tokens.accessToken, 'AT');
    expect(sent, hasLength(2));
    final want = serverNow.millisecondsSinceEpoch ~/ 1000;
    expect(_iat(sent[1]) - want, inInclusiveRange(-5, 5));
    expect(want - _iat(sent[0]), greaterThan(500));
  });

  test('校正的偏移與 ApiClient 共用（同一個 DpopClock）', () async {
    answer = (o, n) => n == 1 ? tooSkewed(o) : ok(o);

    await repo.refresh(refreshToken: 'RT', clientId: 'cid', proofKey: key);

    final want = serverNow.millisecondsSinceEpoch ~/ 1000;
    expect(
      clock.now().millisecondsSinceEpoch ~/ 1000 - want,
      inInclusiveRange(-5, 5),
    );
  });

  test('校正後仍被拒：只重試一次，丟 ApiError', () async {
    answer = (o, _) => tooSkewed(o);

    await expectLater(
      repo.refresh(refreshToken: 'RT', clientId: 'cid', proofKey: key),
      throwsA(isA<ApiError>()),
    );
    expect(sent, hasLength(2));
  });

  test('沒有 proof（舊流程）遇到同樣的 400 不重試', () async {
    answer = (o, _) => tooSkewed(o);

    await expectLater(
      repo.refresh(refreshToken: 'RT', clientId: 'cid'),
      throwsA(isA<ApiError>()),
    );
    expect(sent, hasLength(1));
  });
}
