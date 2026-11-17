// Android：flutter_secure_storage 的生物辨識驗證只在儲存實例初始化時做一次，
// 同一個行程內之後的讀取不會再驗證，所以「開啟 → 登出（保留憑證） → 用指紋登入」
// 第二次讀取會直接成功。以假的平台通道模擬外掛（bioInits = 外掛自己跳驗證的次數），
// 驗證 vault 的把關：同一行程第二次以後的讀取先過 App 層的生物特徵把關。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/models/oauth_tokens.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _Backend {
  final items = <String, String>{};
  final bioReads = <String>[];
  PlatformException? bioError;
  int bioInits = 0;
  bool _bioReady = false;

  void restartProcess() => _bioReady = false;

  Future<Object?> handle(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>;
    final options = Map<Object?, Object?>.from(args['options'] as Map);
    final key = args['key'] as String? ?? '';
    final ns = (options['storageNamespace'] as String?) ?? '';
    if (ns == 'biometric') {
      if (bioError != null) throw bioError!;
      if (!_bioReady) {
        _bioReady = true;
        bioInits++;
      }
      if (call.method == 'read') bioReads.add(key);
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
  }
}

OAuthTokens _tok(String refresh) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: refresh,
  idToken: 'ID',
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Backend be;
  late int gateCalls;
  late bool gateAllows;

  FlutterSecureVault vaultFor(TargetPlatform p) => FlutterSecureVault(
    platform: p,
    biometricGate: () async {
      gateCalls++;
      return gateAllows;
    },
  );

  SecureOAuthTokenStore storeWith(FlutterSecureVault v) =>
      SecureOAuthTokenStore(vault: v);

  /// 開啟生物辨識登入（寫入會初始化外掛實例），之後丟掉記憶體快取＝登出（保留憑證）。
  Future<SecureOAuthTokenStore> enabledAndLocked(FlutterSecureVault v) async {
    final s = storeWith(v);
    await s.write(_tok('R1'));
    await s.setProtection(TokenProtection.biometric);
    await s.lock();
    return s;
  }

  setUp(() {
    be = _Backend();
    gateCalls = 0;
    gateAllows = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, be.handle);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('同一行程：開啟後登出（保留憑證）再解鎖，讀取前一定過一次把關', () async {
    final s = await enabledAndLocked(vaultFor(TargetPlatform.android));
    expect(be.bioInits, 1, reason: '開啟時外掛初始化一次');
    expect(gateCalls, 0, reason: '開啟的寫入不需要把關');

    expect((await s.read())!.refreshToken, 'R1');
    expect(gateCalls, 1, reason: '外掛不會再驗證，所以要靠 App 層把關');
  });

  test('同一行程連續兩次解鎖：每次都把關', () async {
    final s = await enabledAndLocked(vaultFor(TargetPlatform.android));
    await s.read();
    await s.lock();
    await s.read();
    expect(gateCalls, 2);
  });

  test('冷啟動第一次讀取：外掛自己跳驗證，不再把關（不能變兩次提示）', () async {
    await enabledAndLocked(vaultFor(TargetPlatform.android));
    be.restartProcess();
    final fresh = storeWith(vaultFor(TargetPlatform.android));
    final inits = be.bioInits;
    gateCalls = 0;

    expect((await fresh.read())!.refreshToken, 'R1');
    expect(be.bioInits, inits + 1, reason: '外掛初始化＝它自己的一次驗證');
    expect(gateCalls, 0);
  });

  test('把關不通過：不讀憑證、回鎖定，憑證沒被清掉', () async {
    final s = await enabledAndLocked(vaultFor(TargetPlatform.android));
    gateAllows = false;
    final readsBefore = be.bioReads.length;

    await expectLater(s.read(), throwsA(isA<TokenStoreLockedException>()));
    expect(be.bioReads.length, readsBefore, reason: '沒過把關就不碰受保護的項目');

    gateAllows = true;
    expect((await s.read())!.refreshToken, 'R1', reason: '再試一次可以解鎖');
  });

  test('passcode 使用者：永遠不呼叫把關', () async {
    final v = vaultFor(TargetPlatform.android);
    final s = storeWith(v);
    await s.write(_tok('R1'));
    await s.lock();
    await s.read();
    await s.lock();
    await s.read();
    expect(gateCalls, 0);
  });

  test('iOS：永遠不呼叫把關（Keychain 每次讀取都會驗證）', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final s = await enabledAndLocked(vaultFor(TargetPlatform.iOS));
    await s.read();
    await s.lock();
    await s.read();
    expect(gateCalls, 0);
  });

  test('外掛第一次存取就失敗（實例沒初始化成功）：下一次讀取不把關', () async {
    final s = await enabledAndLocked(vaultFor(TargetPlatform.android));
    be.restartProcess();
    final fresh = storeWith(vaultFor(TargetPlatform.android));
    gateCalls = 0;
    be.bioError = PlatformException(code: 'AuthError', message: 'canceled');
    await expectLater(fresh.read(), throwsA(isA<TokenStoreLockedException>()));

    be.bioError = null;
    await fresh.lock();
    await fresh.read();
    expect(gateCalls, 0, reason: '外掛實例還沒初始化，這次由外掛自己驗證');
    expect(s, isNotNull);
  });

  test('冷啟動讀過後 refresh 輪替多次：不把關、外掛不再驗證，新憑證仍在生物辨識實例', () async {
    final v0 = vaultFor(TargetPlatform.android);
    final s0 = storeWith(v0);
    await s0.write(_tok('R1'));
    await s0.setProtection(TokenProtection.biometric);

    be.restartProcess(); // 冷啟動
    final s = storeWith(vaultFor(TargetPlatform.android));
    be.bioInits = 0;
    gateCalls = 0;
    await s.read(); // 外掛自己驗證一次
    await s.write(_tok('R2'));
    await s.write(_tok('R3'));

    expect(be.bioInits, 1, reason: '只有冷啟動那次驗證');
    expect(gateCalls, 0, reason: '寫入不把關');
    expect(s.protection, TokenProtection.biometric);
    final refreshItems = be.items.entries.where(
      (e) => e.key.contains('tripline_oauth_refresh'),
    );
    expect(refreshItems.map((e) => e.key.split('|').first), ['biometric']);
    expect(refreshItems.single.value, 'R3');
  });

  test('biometric 項目寫入成功也算初始化過：下一次讀取要把關', () async {
    final v = vaultFor(TargetPlatform.android);
    await v.write('k', 'v', protection: TokenProtection.biometric);
    expect(gateCalls, 0, reason: '寫入本身不把關');
    await v.read('k', protection: TokenProtection.biometric);
    expect(gateCalls, 1);
  });

  test('biometric 項目刪除成功也算初始化過：下一次讀取要把關', () async {
    final v = vaultFor(TargetPlatform.android);
    await v.delete('k', protection: TokenProtection.biometric);
    gateCalls = 0;
    await v.read('k', protection: TokenProtection.biometric);
    expect(gateCalls, 1);
  });
}
