import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/oauth_tokens.dart';

void main() {
  test('fromTokenResponse：expiresAt = now + expires_in', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final t = OAuthTokens.fromTokenResponse(const {
      'access_token': 'at',
      'refresh_token': 'rt',
      'token_type': 'Bearer',
      'scope': 'openid profile',
      'expires_in': 3600,
    }, now: now);
    expect(t.accessToken, 'at');
    expect(t.refreshToken, 'rt');
    expect(t.scope, 'openid profile');
    expect(t.expiresAt, now.add(const Duration(seconds: 3600)));
  });

  test('isExpired：未過期 false / 已過期 true（含 skew）', () {
    final fresh = OAuthTokens(
        accessToken: 'a', expiresAt: DateTime.now().add(const Duration(hours: 1)));
    expect(fresh.isExpired(), isFalse);
    final old = OAuthTokens(
        accessToken: 'a', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
    expect(old.isExpired(), isTrue);
    // skew:30 秒後到期,skew 60s → 視為已過期
    final soon = OAuthTokens(
        accessToken: 'a', expiresAt: DateTime.now().add(const Duration(seconds: 30)));
    expect(soon.isExpired(skew: const Duration(seconds: 60)), isTrue);
  });

  test('toJson/fromJson round-trip', () {
    final t = OAuthTokens(
      accessToken: 'at',
      refreshToken: 'rt',
      scope: 'openid',
      expiresAt: DateTime.utc(2026, 6, 12, 10, 30),
    );
    final back = OAuthTokens.fromJson(t.toJson());
    expect(back.accessToken, 'at');
    expect(back.refreshToken, 'rt');
    expect(back.scope, 'openid');
    expect(back.expiresAt, t.expiresAt);
  });
}
