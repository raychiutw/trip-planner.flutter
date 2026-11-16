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

  test('冷啟動已驗證不上鎖；之後離開前景超過一分鐘回來照樣上鎖', () async {
    final c = make();
    c.read(credentialVerifiedProvider.notifier).emit();
    final lock = c.read(appLockProvider.notifier);
    final t0 = DateTime(2026, 11, 16, 9);

    // 冷啟動那次 onResumed（AppLockHost 第一幀後呼叫）不得因已驗證以外的原因上鎖。
    await lock.onResumed(t0);
    expect(c.read(appLockProvider).locked, isFalse);

    lock.onHidden(t0);
    await lock.onResumed(t0.add(appLockAfterBackground ~/ 2));
    expect(c.read(appLockProvider).locked, isFalse, reason: '不到一分鐘不鎖');

    lock.onHidden(t0);
    await lock.onResumed(
      t0.add(appLockAfterBackground + const Duration(seconds: 1)),
    );
    expect(c.read(appLockProvider).locked, isTrue);
    expect(c.read(appLockProvider).enabled, isTrue);
  });

  test('沒有事件：照舊以鎖定開始', () {
    expect(make().read(appLockProvider).locked, isTrue);
  });

  test('冷啟動、biometric、沒有憑證：不發事件，App 鎖不被事件解開（走登出分支關閉）', () async {
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

    expect(c.read(appLockProvider).locked, isTrue);
    await c.read(authStateProvider.future);

    expect(c.read(credentialVerifiedProvider), 0);
    // 沒有憑證 = 未登入：與重構前相同，由 _onAuth 登出分支關閉 App 鎖（不是被事件解開）。
    expect(c.read(appLockProvider).enabled, isFalse);
  });
}

class _BioEmptyStore extends InMemoryOAuthTokenStore {
  @override
  TokenProtection get protection => TokenProtection.biometric;
}
