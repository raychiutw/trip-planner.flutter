/// OAuth 2.1 PKCE(RFC 7636):code_verifier 與 S256 code_challenge。
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _unreserved =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

String _randomUnreserved(int length) {
  final rng = Random.secure();
  return List.generate(
    length,
    (_) => _unreserved[rng.nextInt(_unreserved.length)],
  ).join();
}

/// 產生 code_verifier:43 字,字元集 [A-Za-z0-9-._~](Random.secure)。
String generateCodeVerifier() => _randomUnreserved(43);

/// 產生 CSRF state(獨立於 verifier;同強度 CSPRNG)。
String generateState() => _randomUnreserved(43);

/// code_challenge = base64url(sha256(ASCII(verifier))),無 padding(method=S256)。
String codeChallengeS256(String verifier) {
  final digest = sha256.convert(ascii.encode(verifier));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
