import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:tripline/api/dpop/dpop_proof.dart';
import 'package:tripline/api/dpop/proof_key.dart';

Uint8List _b64(String s) => base64Url.decode(base64Url.normalize(s));

Map<String, dynamic> _jsonPart(String jwt, int i) =>
    jsonDecode(utf8.decode(_b64(jwt.split('.')[i]))) as Map<String, dynamic>;

BigInt _int(Uint8List b) =>
    b.fold(BigInt.zero, (acc, v) => (acc << 8) | BigInt.from(v));

/// 用公鑰 jwk 驗 ES256（r‖s 64 bytes）簽章。
bool _verify(String jwt, Map<String, dynamic> jwk) {
  final parts = jwt.split('.');
  final sig = _b64(parts[2]);
  if (sig.length != 64) return false;
  final curve = ECCurve_secp256r1();
  final pub = ECPublicKey(
    curve.curve.createPoint(
      _int(_b64(jwk['x'] as String)),
      _int(_b64(jwk['y'] as String)),
    ),
    curve,
  );
  final verifier = ECDSASigner(SHA256Digest())
    ..init(false, PublicKeyParameter<ECPublicKey>(pub));
  return verifier.verifySignature(
    Uint8List.fromList(utf8.encode('${parts[0]}.${parts[1]}')),
    ECSignature(_int(sig.sublist(0, 32)), _int(sig.sublist(32))),
  );
}

void main() {
  final vectors =
      jsonDecode(File('test/fixtures/dpop_vectors.json').readAsStringSync())
          as Map<String, dynamic>;
  final publicJwk = (vectors['public_jwk'] as Map).cast<String, dynamic>();
  final privateJwk = (vectors['private_jwk'] as Map).cast<String, String>();
  final tokenVec = (vectors['token_request'] as Map).cast<String, dynamic>();
  final resVec = (vectors['resource_request'] as Map).cast<String, dynamic>();

  group('驗證端自己的正確性（用 api 端的測試向量）', () {
    test('測試向量的簽章能被本測試的驗證器驗過', () {
      expect(_verify(tokenVec['proof'] as String, publicJwk), isTrue);
      expect(_verify(resVec['proof'] as String, publicJwk), isTrue);
    });
  });

  group('ath', () {
    test('base64url(SHA-256(access token))，與向量一致', () {
      expect(
        dpopAccessTokenHash(resVec['access_token'] as String),
        resVec['ath'],
      );
    });
  });

  group('SoftwareProofKey', () {
    test('由向量的私鑰 jwk 還原後，公鑰 jwk 與向量相同且不含 d', () {
      final key = SoftwareProofKey.fromJwk(privateJwk);

      expect(key.publicJwk, {
        'kty': 'EC',
        'crv': 'P-256',
        'x': publicJwk['x'],
        'y': publicJwk['y'],
      });
      expect(key.publicJwk.containsKey('d'), isFalse);
      expect(key.kind, 'software');
    });

    test('產生的新金鑰是 P-256，簽章為 r‖s 64 bytes 且可被公鑰驗過', () async {
      final key = SoftwareProofKey.generate();
      final jwt = await buildDpopProof(
        key: key,
        method: 'POST',
        url: Uri.parse('https://api.example/api/oauth/token'),
      );

      expect(key.publicJwk['crv'], 'P-256');
      expect(_b64(jwt.split('.')[2]).length, 64);
      expect(_verify(jwt, key.publicJwk), isTrue);
    });

    test('toJwk 可往返還原（落地用）', () async {
      final key = SoftwareProofKey.generate();
      final again = SoftwareProofKey.fromJwk(key.toJwk());

      final jwt = await buildDpopProof(
        key: again,
        method: 'GET',
        url: Uri.parse('https://api.example/x'),
      );
      expect(_verify(jwt, key.publicJwk), isTrue);
    });
  });

  group('buildDpopProof 與向量格式一致', () {
    test('token 請求：header 與 claims 欄位、順序、值', () async {
      final key = SoftwareProofKey.fromJwk(privateJwk);

      final jwt = await buildDpopProof(
        key: key,
        method: 'POST',
        url: Uri.parse(tokenVec['htu'] as String),
        now: DateTime.fromMillisecondsSinceEpoch(
          1700000000 * 1000,
          isUtc: true,
        ),
        jti: 'vec-token-1',
      );

      final vecProof = tokenVec['proof'] as String;
      expect(jwt.split('.')[0], vecProof.split('.')[0]); // header 逐字相同
      expect(_jsonPart(jwt, 1), {
        'jti': 'vec-token-1',
        'htm': 'POST',
        'htu': tokenVec['htu'],
        'iat': 1700000000,
      });
      expect(
        (_jsonPart(jwt, 1)).keys.toList(),
        (_jsonPart(vecProof, 1)).keys.toList(),
      );
      expect(_verify(jwt, publicJwk), isTrue);
    });

    test('資源請求：帶 ath，且 htu 去掉 query 與 fragment', () async {
      final key = SoftwareProofKey.fromJwk(privateJwk);

      final jwt = await buildDpopProof(
        key: key,
        method: 'GET',
        url: Uri.parse('${resVec['htu']}?ticket=abc#frag'),
        accessToken: resVec['access_token'] as String,
        now: DateTime.fromMillisecondsSinceEpoch(
          1700000000 * 1000,
          isUtc: true,
        ),
        jti: 'vec-res-1',
      );

      final claims = _jsonPart(jwt, 1);
      expect(claims['htu'], resVec['htu']);
      expect(claims['ath'], resVec['ath']);
      expect(
        claims.keys.toList(),
        _jsonPart(resVec['proof'] as String, 1).keys.toList(),
      );
      expect(_verify(jwt, publicJwk), isTrue);
    });
  });

  group('jti 與 iat', () {
    test('沒指定時每個 proof 的 jti 都不同', () async {
      final key = SoftwareProofKey.generate();
      final url = Uri.parse('https://api.example/x');

      final a = await buildDpopProof(key: key, method: 'GET', url: url);
      final b = await buildDpopProof(key: key, method: 'GET', url: url);

      expect(_jsonPart(a, 1)['jti'], isNot(_jsonPart(b, 1)['jti']));
    });

    test('iat 是秒，預設取現在時間', () async {
      final key = SoftwareProofKey.generate();
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final jwt = await buildDpopProof(
        key: key,
        method: 'GET',
        url: Uri.parse('https://api.example/x'),
      );

      final iat = _jsonPart(jwt, 1)['iat'] as int;
      expect(iat, greaterThanOrEqualTo(before));
      expect(iat, lessThanOrEqualTo(before + 5));
    });

    test('沒有 accessToken 就不帶 ath', () async {
      final key = SoftwareProofKey.generate();

      final jwt = await buildDpopProof(
        key: key,
        method: 'POST',
        url: Uri.parse('https://api.example/x'),
      );

      expect(_jsonPart(jwt, 1).containsKey('ath'), isFalse);
    });
  });
}
