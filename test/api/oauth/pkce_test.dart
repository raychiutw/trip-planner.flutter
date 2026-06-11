import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/pkce.dart';

void main() {
  test('codeChallengeS256：RFC 7636 §4 測試向量', () {
    expect(
      codeChallengeS256('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('generateCodeVerifier：43 字 + 未保留字元集', () {
    expect(generateCodeVerifier(), matches(RegExp(r'^[A-Za-z0-9\-._~]{43}$')));
  });

  test('每次 verifier 不同(隨機)', () {
    expect(generateCodeVerifier(), isNot(generateCodeVerifier()));
  });
}
