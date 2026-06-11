/// OAuth 2.1 PKCE(RFC 7636):code_verifier 與 S256 code_challenge。
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _unreserved =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// 產生 code_verifier:43 字,字元集 [A-Za-z0-9-._~](Random.secure)。
String generateCodeVerifier() {
  final rng = Random.secure();
  return List.generate(
    43,
    (_) => _unreserved[rng.nextInt(_unreserved.length)],
  ).join();
}

/// code_challenge = base64url(sha256(ASCII(verifier))),無 padding(method=S256)。
String codeChallengeS256(String verifier) {
  final digest = sha256.convert(ascii.encode(verifier));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
