// 「一次解鎖只跳一次系統驗證」的守門（假設模型，未經真機證實）：
// biometric 項目的 read 算一次提示；對「既有」biometric 項目的 write（SecItemUpdate）
// 也算一次提示；add（key 不存在）與 delete 不算。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _MockRepo extends Mock implements OAuthRepository {}

class PromptVault implements SecretVault {
  final data = <String, String>{};
  final level = <String, TokenProtection>{};
  int prompts = 0;

  /// 在第 n 次 write 呼叫（從 1 起算、自 [armFailure] 起）丟例外。
  int? _failAt;
  int _writeCalls = 0;
  void armFailure(int nth) {
    _failAt = nth;
    _writeCalls = 0;
  }

  @override
  Future<String?> read(
    String key, {
    required TokenProtection protection,
  }) async {
    if (protection == TokenProtection.biometric &&
        level[key] == TokenProtection.biometric) {
      prompts++;
    }
    return data[key];
  }

  @override
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  }) async {
    if (_failAt != null && ++_writeCalls == _failAt) {
      throw Exception('injected');
    }
    if (data.containsKey(key) && level[key] == TokenProtection.biometric) {
      prompts++; // SecItemUpdate 既有的 biometric 項目
    }
    // SecItemUpdate 只改值，不會改既有項目的 access control。
    level.putIfAbsent(key, () => protection);
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
    level.remove(key);
  }

  List<String> get refreshKeys =>
      data.keys.where((k) => k.startsWith('tripline_oauth_refresh')).toList();
}

OAuthTokens _tok({
  String refresh = 'RT',
  Duration ttl = const Duration(hours: 1),
}) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: refresh,
  idToken: 'ID',
  expiresAt: DateTime.now().add(ttl),
);

void main() {
  late PromptVault vault;
  late _MockRepo repo;
  var n = 0;

  Future<SecureOAuthTokenStore> biometricInstall() async {
    final s = SecureOAuthTokenStore(vault: vault);
    await s.write(_tok());
    await s.setProtection(TokenProtection.biometric);
    return s;
  }

  StoredBearerTokenSource sourceOf(SecureOAuthTokenStore s) =>
      StoredBearerTokenSource(store: s, repository: repo, clientId: 'cid');

  setUp(() {
    vault = PromptVault();
    repo = _MockRepo();
    n = 0;
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer(
      (_) async => _tok(refresh: 'RT${++n}', ttl: const Duration(seconds: -1)),
    );
  });

  test('(a) 冷啟動 biometric 解鎖＋第一次 refresh：只有 1 次提示', () async {
    await biometricInstall();
    vault.prompts = 0;

    final s = SecureOAuthTokenStore(vault: vault);
    await sourceOf(s).accessToken();

    expect(vault.prompts, 1);
  });

  test('(b) 登出後保留→unlock＋verify：只有 1 次提示', () async {
    final s = await biometricInstall();
    final src = sourceOf(s);
    await src.seal();
    vault.prompts = 0;

    await s.read(); // 解鎖（唯一一次受保護的讀）
    src.unseal();
    await src.verify(); // 第一個請求 refresh 並輪替

    expect(vault.prompts, 1);
  });

  test('(c) 解鎖後再過期 refresh 3 次：額外 0 次提示，token 仍輪替', () async {
    await biometricInstall();
    vault.prompts = 0;
    final s = SecureOAuthTokenStore(vault: vault);
    final src = sourceOf(s);
    await src.accessToken();
    final afterUnlock = vault.prompts;

    for (var i = 0; i < 3; i++) {
      await src.accessToken();
    }

    expect(vault.prompts, afterUnlock);
    expect(n, 4);
    expect(
      (await SecureOAuthTokenStore(vault: vault).read())!.refreshToken,
      'RT4',
    );
    expect(vault.refreshKeys, hasLength(1), reason: '輪替後不殘留舊槽位');
  });

  group('槽位輪替', () {
    Map<String, dynamic> meta() =>
        jsonDecode(vault.data['tripline_oauth_tokens']!)
            as Map<String, dynamic>;

    test('向下相容：舊的單一 key（meta 沒有槽位）可讀，第一次輪替遷移並刪掉舊 key', () async {
      vault.data['tripline_oauth_tokens'] = jsonEncode({
        ..._tok().toJson()..remove('refresh_token'),
        'protection': 'biometric',
      });
      vault.data['tripline_oauth_refresh'] = 'OLD';
      vault.level['tripline_oauth_refresh'] = TokenProtection.biometric;

      final s = SecureOAuthTokenStore(vault: vault);
      expect((await s.read())!.refreshToken, 'OLD');
      await s.write(_tok(refresh: 'NEW'));

      expect(vault.refreshKeys, ['tripline_oauth_refresh_b']);
      expect(vault.data['tripline_oauth_refresh_b'], 'NEW');
      expect(
        (await SecureOAuthTokenStore(vault: vault).read())!.refreshToken,
        'NEW',
      );
    });

    test('輪替不留舊槽位，指標指向有效槽位', () async {
      final s = await biometricInstall();
      await s.write(_tok(refresh: 'R2'));
      await s.write(_tok(refresh: 'R3'));

      expect(vault.refreshKeys, hasLength(1));
      expect(vault.data[vault.refreshKeys.single], 'R3');
      expect(meta()['refresh_slot'], isNotNull);
    });

    test('步驟(2)與(3)之間失敗：舊槽位仍可讀', () async {
      final s = await biometricInstall();
      await s.write(_tok(refresh: 'R2'));
      // 第 1 次 write＝新槽位的 refresh；第 2 次＝meta 指標。
      vault.armFailure(2);
      await s.write(_tok(refresh: 'R3'));

      expect(
        (await SecureOAuthTokenStore(vault: vault).read())!.refreshToken,
        'R2',
      );
    });

    test('步驟(3)與(4)之間失敗：兩槽位都在、指標指新的，下次輪替收拾殘留', () async {
      final s = await biometricInstall();
      await s.write(_tok(refresh: 'R2'));
      final failing = _FailingDeleteVault(vault);
      final s2 = SecureOAuthTokenStore(vault: failing);
      await s2.read();
      failing.failNextRefreshDelete = true;
      await s2.write(_tok(refresh: 'R3'));

      expect(vault.refreshKeys, hasLength(2));
      expect(
        (await SecureOAuthTokenStore(vault: vault).read())!.refreshToken,
        'R3',
      );

      final s4 = SecureOAuthTokenStore(vault: vault);
      await s4.read();
      await s4.write(_tok(refresh: 'R4'));
      final s3 = SecureOAuthTokenStore(vault: vault);
      expect((await s3.read())!.refreshToken, 'R4');
      expect(vault.refreshKeys, hasLength(1));
    });

    // (d3) 冷啟動遇保留標記、沒先 read 就 adopt：_protection／_slot 都是預設值。
    for (final seeded in ['a', 'b', null]) {
      test('未 read 就 adopt（既有 biometric 憑證在槽位 ${seeded ?? '無'}）：只剩一個槽位、'
          '與 meta 等級一致、無 biometric 殘留', () async {
        if (seeded != null) {
          final key = seeded == 'a'
              ? 'tripline_oauth_refresh'
              : 'tripline_oauth_refresh_b';
          vault.data['tripline_oauth_tokens'] = jsonEncode({
            ..._tok().toJson()..remove('refresh_token'),
            'protection': 'biometric',
            'refresh_slot': seeded,
          });
          vault.data[key] = 'OLD';
          vault.level[key] = TokenProtection.biometric;
        }

        await SecureOAuthTokenStore(vault: vault).write(_tok(refresh: 'NEW'));

        expect(vault.refreshKeys, hasLength(1));
        final key = vault.refreshKeys.single;
        expect(vault.data[key], 'NEW');
        expect(meta()['protection'], 'passcode');
        expect(vault.level[key], TokenProtection.passcode);
        expect(vault.level.values, isNot(contains(TokenProtection.biometric)));
        final r = SecureOAuthTokenStore(vault: vault);
        expect((await r.read())!.refreshToken, 'NEW');
      });
    }

    test('clear 清光（含兩槽位與舊 key）', () async {
      final s = await biometricInstall();
      await s.write(_tok(refresh: 'R2'));
      vault.data['tripline_oauth_refresh'] = 'LEGACY';
      vault.data['tripline_oauth_refresh_b'] = 'B';

      await s.clear();

      expect(vault.data, isEmpty);
    });

    test('setProtection 可用且不留殘留', () async {
      final s = await biometricInstall();
      await s.write(_tok(refresh: 'R2'));
      expect(await s.setProtection(TokenProtection.passcode), isTrue);

      expect(vault.refreshKeys, hasLength(1));
      final r = SecureOAuthTokenStore(vault: vault);
      expect((await r.read())!.refreshToken, 'R2');
      expect(r.protection, TokenProtection.passcode);
      expect(vault.level[vault.refreshKeys.single], TokenProtection.passcode);
    });
  });
}

/// 轉發給真正的 vault，但可讓下一次刪除 refresh 槽位失敗（模擬步驟 3 與 4 之間中斷）。
class _FailingDeleteVault implements SecretVault {
  _FailingDeleteVault(this._inner);
  final PromptVault _inner;
  bool failNextRefreshDelete = false;

  @override
  Future<String?> read(String key, {required TokenProtection protection}) =>
      _inner.read(key, protection: protection);
  @override
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  }) => _inner.write(key, value, protection: protection);
  @override
  Future<void> delete(String key) async {
    if (failNextRefreshDelete && key.startsWith('tripline_oauth_refresh')) {
      // 第一個刪除（步驟 1，清目標槽位的殘留）放行；之後的（步驟 4）失敗。
      failNextRefreshDelete = false;
      _armed = true;
    } else if (_armed && key.startsWith('tripline_oauth_refresh')) {
      _armed = false;
      throw Exception('injected delete');
    }
    return _inner.delete(key);
  }

  bool _armed = false;
}
