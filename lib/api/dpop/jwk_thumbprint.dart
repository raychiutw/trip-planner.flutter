/// RFC 7638 JWK thumbprint（SHA-256、base64url 無 padding），即 `dpop_jkt`。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'proof_key.dart';

/// EC 公鑰的必要欄位依字母序（crv、kty、x、y）、無空白的 JSON 取雜湊。
String jwkThumbprint(ProofKey key) {
  final jwk = key.publicJwk;
  final canonical = jsonEncode({
    'crv': jwk['crv'],
    'kty': jwk['kty'],
    'x': jwk['x'],
    'y': jwk['y'],
  });
  return base64Url
      .encode(sha256.convert(utf8.encode(canonical)).bytes)
      .replaceAll('=', '');
}
