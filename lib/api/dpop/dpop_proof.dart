/// DPoP proof JWT（RFC 9449）的組裝。每個請求都要重新簽一份：jti 只能用一次。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'proof_key.dart';

/// `ath`：base64url（無 padding）的 SHA-256(access token)。
String dpopAccessTokenHash(String accessToken) =>
    _b64(Uint8List.fromList(sha256.convert(utf8.encode(accessToken)).bytes));

/// 組出並簽署 `dpop+jwt`。
///
/// - [url] 的 query 與 fragment 會被去掉（htu 只含 scheme、host、port、path）。
/// - 資源請求帶 [accessToken] 才會有 `ath`；token 端點不帶。
/// - [now]／[jti] 只給測試固定用；正式使用每次都是現在時間與隨機 jti。
Future<String> buildDpopProof({
  required ProofKey key,
  required String method,
  required Uri url,
  String? accessToken,
  DateTime? now,
  String? jti,
}) async {
  final header = {'typ': 'dpop+jwt', 'alg': 'ES256', 'jwk': key.publicJwk};
  final claims = {
    'jti': jti ?? _randomJti(),
    'htm': method.toUpperCase(),
    'htu': _htu(url),
    'iat': (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
    'ath': ?(accessToken == null ? null : dpopAccessTokenHash(accessToken)),
  };
  final signingInput =
      '${_b64(utf8.encode(jsonEncode(header)))}.${_b64(utf8.encode(jsonEncode(claims)))}';
  final signature = await key.sign(
    Uint8List.fromList(utf8.encode(signingInput)),
  );
  return '$signingInput.${_b64(signature)}';
}

String _htu(Uri url) => Uri(
  scheme: url.scheme,
  host: url.host,
  port: url.hasPort ? url.port : null,
  path: url.path,
).toString();

String _randomJti() {
  final rng = Random.secure();
  return _b64(List.generate(16, (_) => rng.nextInt(256)));
}

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
