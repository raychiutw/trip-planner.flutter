import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/id_token.dart';

String _seg(Map<String, dynamic> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

String _jwt(Map<String, dynamic> claims) =>
    '${_seg({'alg': 'RS256'})}.${_seg(claims)}.sig';

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

void main() {
  final now = DateTime.utc(2026, 7, 16, 12);

  Map<String, dynamic> validClaims({
    Object? aud = 'tripline-mobile',
    int? exp,
  }) => {
    'iss': 'https://trip-planner-dby.pages.dev',
    'sub': 'u1',
    'aud': aud,
    'iat': _epoch(now.subtract(const Duration(minutes: 1))),
    'exp': exp ?? _epoch(now.add(const Duration(hours: 1))),
    'email': 'a@x.com',
    'email_verified': true,
    'name': 'Amy',
  };

  group('decodeIdTokenClaims（純解碼，不驗證）', () {
    test('解出 payload claims', () {
      final claims = decodeIdTokenClaims(_jwt(validClaims()));
      expect(claims['sub'], 'u1');
      expect(claims['email'], 'a@x.com');
      expect(claims['name'], 'Amy');
      expect(claims['email_verified'], true);
    });

    test('壞掉的 token → 空 map', () {
      expect(decodeIdTokenClaims('not-a-jwt'), isEmpty);
      expect(decodeIdTokenClaims(''), isEmpty);
    });
  });

  group('verifiedIdTokenClaims', () {
    test('合法 token → 回 claims', () {
      final claims = verifiedIdTokenClaims(
        _jwt(validClaims()),
        clientId: 'tripline-mobile',
        now: now,
      );
      expect(claims?['sub'], 'u1');
      expect(claims?['email'], 'a@x.com');
    });

    test('過期 → null（不得再當成已登入身分）', () {
      final claims = verifiedIdTokenClaims(
        _jwt(validClaims(exp: _epoch(now.subtract(const Duration(hours: 1))))),
        clientId: 'tripline-mobile',
        now: now,
      );
      expect(claims, isNull);
    });

    test('無 leeway 時 exp == now 即算過期（邊界為排他）', () {
      final claims = verifiedIdTokenClaims(
        _jwt(validClaims(exp: _epoch(now))),
        clientId: 'tripline-mobile',
        now: now,
        leeway: Duration.zero,
      );
      expect(claims, isNull);
    });

    test('缺 exp → null（無到期資訊的身分不可信）', () {
      final withoutExp = validClaims()..remove('exp');
      expect(
        verifiedIdTokenClaims(
          _jwt(withoutExp),
          clientId: 'tripline-mobile',
          now: now,
        ),
        isNull,
      );
    });

    test('aud 不是本 client → null（別人的 token 不能當我的身分）', () {
      final claims = verifiedIdTokenClaims(
        _jwt(validClaims(aud: 'someone-elses-client')),
        clientId: 'tripline-mobile',
        now: now,
      );
      expect(claims, isNull);
    });

    test('aud 為陣列且含本 client → 通過（OIDC 允許 aud 是陣列）', () {
      final claims = verifiedIdTokenClaims(
        _jwt(validClaims(aud: ['other', 'tripline-mobile'])),
        clientId: 'tripline-mobile',
        now: now,
      );
      expect(claims?['sub'], 'u1');
    });

    test('aud 為陣列但不含本 client → null', () {
      expect(
        verifiedIdTokenClaims(
          _jwt(validClaims(aud: ['other', 'another'])),
          clientId: 'tripline-mobile',
          now: now,
        ),
        isNull,
      );
    });

    test('缺 aud → null', () {
      final withoutAud = validClaims()..remove('aud');
      expect(
        verifiedIdTokenClaims(
          _jwt(withoutAud),
          clientId: 'tripline-mobile',
          now: now,
        ),
        isNull,
      );
    });

    test('缺 sub → null（沒有主體就不是身分）', () {
      final withoutSub = validClaims()..remove('sub');
      expect(
        verifiedIdTokenClaims(
          _jwt(withoutSub),
          clientId: 'tripline-mobile',
          now: now,
        ),
        isNull,
      );
    });

    test('壞掉的 token → null', () {
      expect(
        verifiedIdTokenClaims(
          'not-a-jwt',
          clientId: 'tripline-mobile',
          now: now,
        ),
        isNull,
      );
    });

    test('容忍小幅時鐘偏移（剛過期 30 秒內仍接受）', () {
      // 裝置時鐘與 server 有秒級落差是常態，卡太死會把合法 token 判死。
      final claims = verifiedIdTokenClaims(
        _jwt(
          validClaims(exp: _epoch(now.subtract(const Duration(seconds: 30)))),
        ),
        clientId: 'tripline-mobile',
        now: now,
        leeway: const Duration(minutes: 1),
      );
      expect(claims?['sub'], 'u1');
    });
  });
}
