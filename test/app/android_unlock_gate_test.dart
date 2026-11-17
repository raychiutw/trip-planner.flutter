import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/app/android_unlock_gate.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/models/oauth_tokens.dart';

import '../helpers/fake_biometric.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

OAuthTokens _tok(String refresh) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: refresh,
  idToken: 'ID',
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

/// Android：每次用保留的生物辨識憑證登入都要用生物特徵驗證。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('androidUnlockGate', () {
    late FakeBiometricAuthenticator bio;
    late List<String> events;
    late Future<void> Function() wait;

    setUp(() {
      events = [];
      bio = FakeBiometricAuthenticator()
        ..onAuthenticate = () => events.add('auth');
      wait = () async => events.add('wait');
    });

    test('通過 → true；只接受生物特徵，且先等前景', () async {
      expect(await androidUnlockGate(bio, waitForeground: wait), isTrue);
      expect(bio.biometricOnlyCalls, [true]);
      expect(events, ['wait', 'auth']);
    });

    test('被系統中斷一次：再等前景並重試，通過就 true', () async {
      bio.outcomes.add(BiometricOutcome.interrupted);
      expect(await androidUnlockGate(bio, waitForeground: wait), isTrue);
      expect(events, ['wait', 'auth', 'wait', 'auth']);
    });

    test('連續被中斷 → false', () async {
      bio.outcomes
        ..add(BiometricOutcome.interrupted)
        ..add(BiometricOutcome.interrupted);
      expect(await androidUnlockGate(bio, waitForeground: wait), isFalse);
      expect(bio.authenticateCalls, 2);
    });

    test('使用者取消 → false，不重試', () async {
      bio.outcomes.add(BiometricOutcome.cancelled);
      expect(await androidUnlockGate(bio, waitForeground: wait), isFalse);
      expect(bio.authenticateCalls, 1);
    });

    test('驗證失敗 → false，不重試', () async {
      bio.outcomes.add(BiometricOutcome.failed);
      expect(await androidUnlockGate(bio, waitForeground: wait), isFalse);
      expect(bio.authenticateCalls, 1);
    });
  });

  group('createProductionTokenStore（正式環境的組裝）', () {
    final items = <String, String>{};
    var bioInits = 0;
    var ready = false;

    setUp(() {
      items.clear();
      bioInits = 0;
      ready = false;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            final args = call.arguments as Map<Object?, Object?>;
            final options = Map<Object?, Object?>.from(args['options'] as Map);
            final key = args['key'] as String? ?? '';
            final ns = (options['storageNamespace'] as String?) ?? '';
            if (ns == 'biometric' && !ready) {
              ready = true;
              bioInits++;
            }
            switch (call.method) {
              case 'write':
                items['$ns|$key'] = args['value'] as String;
                return null;
              case 'read':
                return items['$ns|$key'];
              case 'containsKey':
                return items.containsKey('$ns|$key');
              case 'delete':
                items.remove('$ns|$key');
                return null;
            }
            return null;
          });
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('開啟後登出（保留憑證）再解鎖：把關被呼叫一次（且只接受生物特徵）', () async {
      final bio = FakeBiometricAuthenticator();
      final store = createProductionTokenStore(bio);
      await store.write(_tok('R1'));
      await store.setProtection(TokenProtection.biometric);
      await store.lock();
      expect(bio.authenticateCalls, 0, reason: '開啟的寫入由外掛自己處理');

      expect((await store.read())!.refreshToken, 'R1');
      expect(bioInits, 1, reason: '外掛只初始化（驗證）一次');
      expect(bio.authenticateCalls, 1, reason: '外掛不會再驗證，要靠 App 層把關');
      expect(bio.biometricOnlyCalls, [true]);
    });

    test('把關沒通過：回鎖定，不讀憑證', () async {
      final bio = FakeBiometricAuthenticator();
      final store = createProductionTokenStore(bio);
      await store.write(_tok('R1'));
      await store.setProtection(TokenProtection.biometric);
      await store.lock();
      bio.outcomes.add(BiometricOutcome.cancelled);

      await expectLater(
        store.read(),
        throwsA(isA<TokenStoreLockedException>()),
      );
    });
  });
}
