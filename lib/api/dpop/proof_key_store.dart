/// DPoP 金鑰的取得與保存（ADR-0015）。金鑰和登入憑證同生同滅：
/// 每次登入 [create] 新的一把，登出、refresh 被拒、生物辨識失效時 [delete]。
library;

import 'dart:convert';

import '../oauth/oauth_token_store.dart' show SecretVault, TokenProtection;
import 'proof_key.dart';

/// 這個環境拿不到硬體金鑰（模擬器、沒有 Secure Enclave／Keystore 的裝置）。
class ProofKeyUnsupportedException implements Exception {
  const ProofKeyUnsupportedException();
  @override
  String toString() => 'ProofKeyUnsupportedException';
}

abstract interface class ProofKeyStore {
  /// 這次登入使用的金鑰；沒有回 null。
  Future<ProofKey?> load();

  /// 產生新金鑰（先清掉舊的）。硬體實作在不支援的環境丟
  /// [ProofKeyUnsupportedException]。
  Future<ProofKey> create();

  Future<void> delete();
}

/// 測試與未組裝時的預設：只活在記憶體。
class InMemoryProofKeyStore implements ProofKeyStore {
  ProofKey? _key;

  @override
  Future<ProofKey?> load() async => _key;

  @override
  Future<ProofKey> create() async => _key = SoftwareProofKey.generate();

  @override
  Future<void> delete() async => _key = null;
}

/// 軟體後備金鑰：私鑰 JWK 存 Keychain／Keystore（可匯出，ADR-0015）。
/// 裝置沒設密碼存不進去時只留記憶體，與登入憑證一致（下次開 app 重新登入）。
class SoftwareProofKeyStore implements ProofKeyStore {
  SoftwareProofKeyStore({required SecretVault vault}) : _vault = vault;

  static const _key = 'tripline_dpop_key';

  final SecretVault _vault;
  SoftwareProofKey? _cache;

  @override
  Future<ProofKey?> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _vault.read(_key, protection: TokenProtection.passcode);
    if (raw == null || raw.isEmpty) return null;
    try {
      final jwk = (jsonDecode(raw) as Map).cast<String, String>();
      return _cache = SoftwareProofKey.fromJwk(jwk);
    } on Exception {
      return null; // 壞掉的資料視為沒有金鑰
    }
  }

  @override
  Future<ProofKey> create() async {
    await delete();
    final key = SoftwareProofKey.generate();
    _cache = key;
    try {
      await _vault.write(
        _key,
        jsonEncode(key.toJwk()),
        protection: TokenProtection.passcode,
      );
    } on Exception {
      // 存不進去：只留記憶體。
    }
    return key;
  }

  @override
  Future<void> delete() async {
    _cache = null;
    await _vault.delete(_key);
  }
}

/// 硬體優先，拿不到才退軟體。proof 格式相同，上層不分辨。
class FallbackProofKeyStore implements ProofKeyStore {
  FallbackProofKeyStore({required this.hardware, required this.software});

  final ProofKeyStore hardware;
  final ProofKeyStore software;

  @override
  Future<ProofKey?> load() async =>
      await hardware.load() ?? await software.load();

  @override
  Future<ProofKey> create() async {
    await delete();
    try {
      return await hardware.create();
    } on ProofKeyUnsupportedException {
      return software.create();
    }
  }

  @override
  Future<void> delete() async {
    await hardware.delete();
    await software.delete();
  }
}
