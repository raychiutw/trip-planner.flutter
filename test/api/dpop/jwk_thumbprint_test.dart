import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/dpop/jwk_thumbprint.dart';
import 'package:tripline/api/dpop/proof_key.dart';

class _Key implements ProofKey {
  @override
  String get kind => 'software';
  @override
  Map<String, String> get publicJwk => {
    'kty': 'EC',
    'crv': 'P-256',
    'x': 'XX',
    'y': 'YY',
  };
  @override
  Future<Uint8List> sign(Uint8List signingInput) async => Uint8List(64);
}

void main() {
  test('RFC 7638：EC 公鑰以字母序的必要欄位 JSON 取 SHA-256，base64url 無 padding', () {
    // 規格定義的正規化字串（crv、kty、x、y 依字母序、無空白）。
    const canonical = '{"crv":"P-256","kty":"EC","x":"XX","y":"YY"}';
    final expected = base64Url
        .encode(sha256.convert(utf8.encode(canonical)).bytes)
        .replaceAll('=', '');

    expect(jwkThumbprint(_Key()), expected);
    expect(expected.length, 43);
  });
}
