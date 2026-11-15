import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';

/// 認證一直在解析中：不讓 _onAuth 的登出分支介入，只測「憑證已驗證」事件的時序。
class _PendingAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() => Completer<UserInfo?>().future;
}

void main() {
  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_PendingAuth.new),
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(),
        ),
        appLockProvider.overrideWith(
          () => AppLockController(initialEnabled: true),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('(a) 事件在 App 鎖建立之前發出：建立後不鎖定，App 鎖設定照舊開啟', () {
    final c = make();
    c.read(credentialVerifiedProvider.notifier).emit();

    final s = c.read(appLockProvider);

    expect(s.enabled, isTrue);
    expect(s.locked, isFalse);
  });

  test('(b) 事件在 App 鎖建立之後發出：由 listen 解鎖', () {
    final c = make();
    expect(c.read(appLockProvider).locked, isTrue);

    c.read(credentialVerifiedProvider.notifier).emit();

    expect(c.read(appLockProvider).locked, isFalse);
    expect(c.read(appLockProvider).enabled, isTrue);
  });

  test('沒有事件：照舊以鎖定開始', () {
    expect(make().read(appLockProvider).locked, isTrue);
  });

  test('冷啟動、biometric、沒有憑證：不發事件，App 鎖維持鎖定', () async {
    final c = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(_BioEmptyStore()),
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(),
        ),
        appLockProvider.overrideWith(
          () => AppLockController(initialEnabled: true),
        ),
      ],
    );
    addTearDown(c.dispose);

    c.read(appLockProvider);
    await c.read(authStateProvider.future);

    expect(c.read(credentialVerifiedProvider), 0);
    expect(c.read(appLockProvider).locked, isTrue);
  });
}

class _BioEmptyStore extends InMemoryOAuthTokenStore {
  @override
  TokenProtection get protection => TokenProtection.biometric;
}
