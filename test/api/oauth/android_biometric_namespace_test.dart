// Android：biometric 項目放獨立 storageNamespace（否則 plugin 以第一次呼叫的選項
// 初始化同一個實例，biometric 設定被忽略，見 secure_vault_android_options_test）。
// 以假的平台通道＋真的 FlutterSecureVault／SecureOAuthTokenStore 驗證整條路徑。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/models/oauth_tokens.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _a = 'tripline_oauth_refresh';
const _b = 'tripline_oauth_refresh_b';

typedef _Call = ({String method, String ns, String key});

class _Backend {
  final items = <String, String>{}; // '$ns|$key'
  final calls = <_Call>[];
  final iosOptions = <Map<Object?, Object?>>[];
  PlatformException? bioError;
  int bioInits = 0;
  bool _bioReady = false;

  /// 模擬 app 重開：plugin 實例與驗證都要重來。
  void restartProcess() => _bioReady = false;

  Iterable<String> keysIn(String ns) => items.keys
      .where((k) => k.startsWith('$ns|'))
      .map((k) => k.substring(ns.length + 1));
  int get bioCalls => calls.where((c) => c.ns == 'biometric').length;
  String? at(String ns, String key) => items['$ns|$key'];
  void put(String ns, String key, String v) => items['$ns|$key'] = v;

  Future<Object?> handle(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>;
    final options = Map<Object?, Object?>.from(args['options'] as Map);
    final key = args['key'] as String? ?? '';
    final ns = (options['storageNamespace'] as String?) ?? '';
    calls.add((method: call.method, ns: ns, key: key));
    if (!options.containsKey('storageNamespace')) iosOptions.add(options);
    if (ns == 'biometric') {
      if (bioError != null) throw bioError!;
      if (!_bioReady) {
        _bioReady = true;
        bioInits++;
      }
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

String _meta({required String protection, String? slot, int? bioNs}) =>
    jsonEncode({
      ..._tok('x').toJson()..remove('refresh_token'),
      'protection': protection,
      'refresh_slot': ?slot,
      'bio_ns': ?bioNs,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Backend be;

  void useAndroid() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }

  SecureOAuthTokenStore storeFor(TargetPlatform p) =>
      SecureOAuthTokenStore(vault: FlutterSecureVault(platform: p));
  SecureOAuthTokenStore android() => storeFor(TargetPlatform.android);

  setUp(() {
    be = _Backend();
    useAndroid();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, be.handle);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('Android', () {
    test('passcode 使用者的完整流程：biometric namespace 呼叫 0 次', () async {
      final s = android();
      await s.write(_tok('R1'));
      await s.write(_tok('R2')); // refresh 輪替
      await s.setProtection(TokenProtection.passcode); // 已是 passcode
      be.put('', 'tripline_oauth_kept_account', 'ray'); // 舊版保留標記
      final r = android();
      expect((await r.read())!.refreshToken, 'R2');
      await r.clear();

      expect(be.bioCalls, 0);
      expect(be.items, isEmpty);
    });

    test('開啟 biometric：項目寫進獨立 namespace，meta 留在原實例並標記版本', () async {
      final s = android();
      await s.write(_tok('R1'));
      await s.setProtection(TokenProtection.biometric);
      await s.write(_tok('R2'));

      expect(be.keysIn('biometric'), hasLength(1));
      expect(be.at('biometric', be.keysIn('biometric').single), 'R2');
      expect(be.keysIn('').where((k) => k.startsWith(_a)), isEmpty);
      final meta = jsonDecode(be.at('', 'tripline_oauth_tokens')!) as Map;
      expect(meta['protection'], 'biometric');
      expect(meta['bio_ns'], 1);
      expect(be.bioInits, 1);

      be.restartProcess();
      final r = android();
      expect((await r.read())!.refreshToken, 'R2');
      expect(be.bioInits, 2); // 每個 process 一次初始化（驗證）
    });

    test('setProtection(passcode) 關閉：新 namespace 的項目刪乾淨', () async {
      final s = android();
      await s.write(_tok('R1'));
      await s.setProtection(TokenProtection.biometric);
      await s.setProtection(TokenProtection.passcode);

      expect(be.keysIn('biometric'), isEmpty);
      be.restartProcess();
      final r = android();
      expect((await r.read())!.refreshToken, 'R1');
      expect(r.protection, TokenProtection.passcode);
    });

    test('clear（biometric 使用者）：兩個實例都清乾淨', () async {
      final s = android();
      await s.write(_tok('R1'));
      await s.setProtection(TokenProtection.biometric);
      await s.write(_tok('R2'));
      be.put('', 'tripline_oauth_kept_account', 'ray'); // 舊版保留標記
      be.put('biometric', _a, 'stale'); // 殘留的另一個槽位

      await android().clear(); // 全新 store（沒 read 過）也要認得出 biometric

      expect(be.items, isEmpty);
    });

    group('遷移（舊版 biometric 項目放在 passcode 實例）', () {
      void seedLegacy({String slot = 'a'}) {
        be.put(
          '',
          'tripline_oauth_tokens',
          _meta(protection: 'biometric', slot: slot == 'a' ? null : 'b'),
        );
        be.put('', slot == 'a' ? _a : _b, 'OLD');
      }

      test('成功：搬進新 namespace、標記版本、刪舊項目；重入不重複遷移', () async {
        seedLegacy();
        final r = android();
        expect((await r.read())!.refreshToken, 'OLD');

        expect(be.keysIn('').where((k) => k.startsWith(_a)), isEmpty);
        expect(be.keysIn('biometric'), hasLength(1));
        expect(jsonDecode(be.at('', 'tripline_oauth_tokens')!)['bio_ns'], 1);
        expect(be.bioInits, 1);

        be.restartProcess();
        be.calls.clear();
        expect((await android().read())!.refreshToken, 'OLD');
        expect(
          be.calls.where((c) => c.ns == '' && c.key.startsWith(_a)),
          isEmpty,
          reason: '第二次不再用 passcode 實例碰 refresh 項目',
        );
        expect(be.calls.where((c) => c.method == 'write'), isEmpty);
      });

      test('舊項目在槽位 b 也能遷移', () async {
        seedLegacy(slot: 'b');
        expect((await android().read())!.refreshToken, 'OLD');
        expect(be.keysIn('').where((k) => k.startsWith(_a)), isEmpty);
      });

      test('舊項目讀不到：降級成重新登入（清憑證、回 null、不 throw）', () async {
        be.put('', 'tripline_oauth_tokens', _meta(protection: 'biometric'));

        expect(await android().read(), isNull);
        expect(be.items, isEmpty);
      });

      test('使用者取消驗證：回鎖定、保留舊項目，下次可再試', () async {
        seedLegacy();
        be.bioError = PlatformException(
          code: 'Exception encountered',
          message: 'Authentication canceled by user',
        );
        await expectLater(
          android().read(),
          throwsA(isA<TokenStoreLockedException>()),
        );
        expect(be.at('', _a), 'OLD');
        expect(be.at('', 'tripline_oauth_tokens'), isNotNull);

        be.bioError = null;
        expect((await android().read())!.refreshToken, 'OLD');
        expect(be.at('', _a), isNull);
      });

      test('金鑰已失效：清憑證、回未登入', () async {
        seedLegacy();
        be.bioError = PlatformException(
          code: 'Exception encountered',
          message: 'KeyPermanentlyInvalidated',
        );

        expect(await android().read(), isNull);
        expect(be.at('', 'tripline_oauth_tokens'), isNull);
        expect(be.at('', _a), isNull);
      });
    });
  });

  group('iOS 路徑不變', () {
    test('不遷移、不碰 storageNamespace；biometric 項目只用 biometric 選項讀', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      be.put('', 'tripline_oauth_tokens', _meta(protection: 'biometric'));
      be.put('', _a, 'OLD');

      final r = storeFor(TargetPlatform.iOS);
      expect((await r.read())!.refreshToken, 'OLD');
      await r.write(_tok('NEW')); // 輪替

      expect(be.calls.where((c) => c.ns == 'biometric'), isEmpty);
      expect(
        be.iosOptions.every((o) => !o.containsKey('storageNamespace')),
        isTrue,
      );
      // 沒有任何「用 passcode 選項讀 refresh 項目」的呼叫（iOS 那會跳驗證）。
      final passcodeParams = const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
      ).params;
      final refreshReads = be.calls
          .asMap()
          .entries
          .where((e) => e.value.method == 'read' && e.value.key.startsWith(_a))
          .map((e) => be.iosOptions[e.key]);
      expect(refreshReads, isNotEmpty);
      expect(refreshReads.any((o) => mapEquals(o, passcodeParams)), isFalse);
      // 沒有 bio_ns 標記。
      expect(
        jsonDecode(be.at('', 'tripline_oauth_tokens')!),
        isNot(contains('bio_ns')),
      );
    });
  });
}
