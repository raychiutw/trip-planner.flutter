import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/models/oauth_tokens.dart';

void main() {
  test('InMemory：write → read round-trip + clear', () async {
    final store = InMemoryOAuthTokenStore();
    expect(await store.read(), isNull);

    final t = OAuthTokens(
      accessToken: 'AT',
      refreshToken: 'RT',
      expiresAt: DateTime.utc(2026, 6, 12, 10),
    );
    await store.write(t);
    final back = await store.read();
    // access token 不落地(ADR-0014):只剩 refresh token。
    expect(back!.accessToken, isEmpty);
    expect(back.refreshToken, 'RT');

    await store.clear();
    expect(await store.read(), isNull);
  });
}
