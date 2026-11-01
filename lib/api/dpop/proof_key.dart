/// DPoP（RFC 9449）用的簽章金鑰：ES256（P-256）。
///
/// 上層只依賴 [ProofKey]：硬體實作（Secure Enclave／Android Keystore）與這裡的
/// 軟體實作都實作它，proof 格式相同，伺服器分辨不出（見 ADR-0015）。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

abstract interface class ProofKey {
  /// `hardware` 或 `software`，只供統計與除錯。
  String get kind;

  /// 公鑰 JWK，欄位順序固定為 kty、crv、x、y；**不含** 私鑰欄位。
  Map<String, String> get publicJwk;

  /// ES256 簽章：回傳 r‖s 共 64 bytes（不是 DER）。
  Future<Uint8List> sign(Uint8List signingInput);
}

/// 純 Dart 的後備金鑰。私鑰可匯出，只在拿不到硬體金鑰時使用。
class SoftwareProofKey implements ProofKey {
  SoftwareProofKey._(this._d, this._x, this._y);

  factory SoftwareProofKey.generate() {
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(ECKeyGeneratorParameters(_curve), _secureRandom()),
      );
    final pair = generator.generateKeyPair();
    final priv = pair.privateKey;
    final pub = pair.publicKey;
    return SoftwareProofKey._(
      priv.d!,
      pub.Q!.x!.toBigInteger()!,
      pub.Q!.y!.toBigInteger()!,
    );
  }

  /// 還原落地的私鑰 JWK（含 d）。
  factory SoftwareProofKey.fromJwk(Map<String, String> jwk) =>
      SoftwareProofKey._(
        _decode(jwk['d']!),
        _decode(jwk['x']!),
        _decode(jwk['y']!),
      );

  static final ECDomainParameters _curve = ECCurve_secp256r1();

  final BigInt _d;
  final BigInt _x;
  final BigInt _y;

  @override
  String get kind => 'software';

  @override
  Map<String, String> get publicJwk => {
    'kty': 'EC',
    'crv': 'P-256',
    'x': _encode(_x),
    'y': _encode(_y),
  };

  /// 私鑰 JWK（含 d），只給落地存取用，不可送給任何伺服器。
  Map<String, String> toJwk() => {...publicJwk, 'd': _encode(_d)};

  @override
  Future<Uint8List> sign(Uint8List signingInput) async {
    final signer = ECDSASigner(SHA256Digest())
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(_d, _curve)),
          _secureRandom(),
        ),
      );
    final sig = signer.generateSignature(signingInput) as ECSignature;
    return Uint8List.fromList([..._bytes32(sig.r), ..._bytes32(sig.s)]);
  }

  static SecureRandom _secureRandom() {
    final seeder = Random.secure();
    return FortunaRandom()..seed(
      KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => seeder.nextInt(256))),
      ),
    );
  }

  static Uint8List _bytes32(BigInt v) {
    final out = Uint8List(32);
    var rest = v;
    for (var i = 31; i >= 0; i--) {
      out[i] = (rest & BigInt.from(0xff)).toInt();
      rest >>= 8;
    }
    return out;
  }

  static String _encode(BigInt v) =>
      base64Url.encode(_bytes32(v)).replaceAll('=', '');

  static BigInt _decode(String s) => base64Url
      .decode(base64Url.normalize(s))
      .fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));
}
