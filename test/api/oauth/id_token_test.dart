import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/id_token.dart';

String _seg(Map<String, dynamic> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

void main() {
  test('decodeIdTokenClaims：解出 payload claims', () {
    final jwt = '${_seg({'alg': 'RS256'})}.'
        '${_seg({'sub': 'u1', 'email': 'a@x.com', 'name': 'Amy', 'email_verified': true})}.sig';
    final claims = decodeIdTokenClaims(jwt);
    expect(claims['sub'], 'u1');
    expect(claims['email'], 'a@x.com');
    expect(claims['name'], 'Amy');
    expect(claims['email_verified'], true);
  });

  test('壞掉的 token → 空 map', () {
    expect(decodeIdTokenClaims('not-a-jwt'), isEmpty);
    expect(decodeIdTokenClaims(''), isEmpty);
  });
}
