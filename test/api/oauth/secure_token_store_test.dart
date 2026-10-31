import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _FakeVault implements SecretVault {
  final data = <String, String>{};
  final writes = <(String, TokenProtection)>[];
  final reads = <(String, TokenProtection)>[];

  /// 模擬：裝置沒設密碼、或生物辨識被取消／特徵變動。
  bool failWrites = false;
  PlatformException? readError;

  @override
  Future<String?> read(
    String key, {
    required TokenProtection protection,
  }) async {
    reads.add((key, protection));
    final error = readError;
    if (error != null && protection == TokenProtection.biometric) throw error;
    return data[key];
  }

  @override
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  }) async {
    writes.add((key, protection));
    if (failWrites) throw PlatformException(code: 'no-passcode');
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async => data.remove(key);
}

OAuthTokens _tok({String refresh = 'RT'}) => OAuthTokens(
  accessToken: 'SECRET_ACCESS',
  refreshToken: refresh,
  idToken: 'ID',
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

void main() {
  late _FakeVault vault;
  late SecureOAuthTokenStore store;

  setUp(() {
    vault = _FakeVault();
    store = SecureOAuthTokenStore(vault: vault);
  });

  test('落地內容完全不含 access token', () async {
    await store.write(_tok());

    expect(vault.data.values.join(), isNot(contains('SECRET_ACCESS')));
    expect(vault.data['tripline_oauth_refresh'], 'RT');
  });

  test('預設用裝置密碼等級保護 refresh token', () async {
    await store.write(_tok());

    expect(
      vault.writes.where((w) => w.$1 == 'tripline_oauth_refresh').single.$2,
      TokenProtection.passcode,
    );
  });

  test('裝置沒設密碼（寫入失敗）：不落地，這次程式生命週期內仍可用', () async {
    vault.failWrites = true;
    await store.write(_tok());

    expect(vault.data, isEmpty);
    expect((await store.read())!.refreshToken, 'RT');

    // 重開 app（新的 store）就沒有登入了。
    expect(await SecureOAuthTokenStore(vault: vault).read(), isNull);
  });

  test('改成生物辨識保護：refresh token 以 biometric 等級重存', () async {
    await store.write(_tok());
    await store.setProtection(TokenProtection.biometric);

    expect(
      vault.writes.where((w) => w.$1 == 'tripline_oauth_refresh').last.$2,
      TokenProtection.biometric,
    );
    expect(store.protection, TokenProtection.biometric);
    // 重開 app 後會依落地的等級讀取。
    final restarted = SecureOAuthTokenStore(vault: vault);
    expect((await restarted.read())!.refreshToken, 'RT');
    expect(restarted.protection, TokenProtection.biometric);
    expect(
      vault.reads.where((r) => r.$1 == 'tripline_oauth_refresh').last.$2,
      TokenProtection.biometric,
    );
  });

  test('受保護的項目沒通過生物辨識：丟出鎖定例外而不是當成登出', () async {
    await store.write(_tok());
    await store.setProtection(TokenProtection.biometric);
    vault.readError = PlatformException(code: 'auth-failed');

    await expectLater(
      SecureOAuthTokenStore(vault: vault).read(),
      throwsA(isA<TokenStoreLockedException>()),
    );
    expect(vault.data, isNotEmpty); // 憑證沒被清掉，下次解鎖還在
  });

  test('生物特徵變動使項目失效：清掉並回到未登入，要求重新登入', () async {
    await store.write(_tok());
    await store.setProtection(TokenProtection.biometric);
    vault.readError = PlatformException(code: 'KeyPermanentlyInvalidated');

    expect(await SecureOAuthTokenStore(vault: vault).read(), isNull);
    expect(vault.data, isEmpty);
  });

  test('已讀過一次後不再碰 Keychain（生物辨識只在冷啟動出現）', () async {
    await store.write(_tok());
    await store.setProtection(TokenProtection.biometric);
    final restarted = SecureOAuthTokenStore(vault: vault);
    await restarted.read();
    final readsAfterFirst = vault.reads.length;

    await restarted.write(_tok(refresh: 'RT2')); // 輪替
    await restarted.read();

    expect(vault.reads.length, readsAfterFirst);
    expect(jsonDecode(vault.data['tripline_oauth_tokens']!), isA<Map>());
    expect(vault.data['tripline_oauth_refresh'], 'RT2');
  });

  test('clear：全部刪除並回到預設保護等級', () async {
    await store.write(_tok());
    await store.setProtection(TokenProtection.biometric);

    await store.clear();

    expect(vault.data, isEmpty);
    expect(store.protection, TokenProtection.passcode);
    expect(await store.read(), isNull);
  });
}
