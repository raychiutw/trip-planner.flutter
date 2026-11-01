/// DPoP 硬體金鑰（iOS Secure Enclave、Android Keystore）的 Dart 端（ADR-0015）。
///
/// 私鑰留在原生端的硬體裡、不匯出：Dart 只拿得到公鑰座標，簽章交給原生做。
/// 原生建立不出來（模擬器、沒有硬體的裝置，或任何失敗）一律回報
/// [ProofKeyUnsupportedException]，由 [FallbackProofKeyStore] 退回軟體金鑰，
/// 不能因為拿不到硬體金鑰就讓使用者登不進去。
library;

import 'package:flutter/services.dart';

import '../api/dpop/proof_key.dart';
import '../api/dpop/proof_key_store.dart';

class HardwareProofKeyStore implements ProofKeyStore {
  HardwareProofKeyStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('tripline/proof-key');

  final MethodChannel _channel;

  @override
  Future<ProofKey?> load() async {
    try {
      final point = await _channel.invokeMapMethod<String, String>('load');
      return point == null ? null : _HardwareProofKey(_channel, point);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null; // 金鑰失效等：當作沒有金鑰
    }
  }

  @override
  Future<ProofKey> create() async {
    try {
      final point = await _channel.invokeMapMethod<String, String>('create');
      if (point == null) throw const ProofKeyUnsupportedException();
      return _HardwareProofKey(_channel, point);
    } on MissingPluginException {
      throw const ProofKeyUnsupportedException();
    } on PlatformException {
      throw const ProofKeyUnsupportedException();
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _channel.invokeMethod<void>('delete');
    } on MissingPluginException {
      // 沒有原生實作就沒有東西可刪。
    } on PlatformException {
      // 刪不掉不能擋住登出；下次登入 create 會先清舊的。
    }
  }
}

class _HardwareProofKey implements ProofKey {
  _HardwareProofKey(this._channel, Map<String, String> point)
    : publicJwk = {
        'kty': 'EC',
        'crv': 'P-256',
        'x': point['x']!,
        'y': point['y']!,
      };

  final MethodChannel _channel;

  @override
  String get kind => 'hardware';

  @override
  final Map<String, String> publicJwk;

  @override
  Future<Uint8List> sign(Uint8List signingInput) async {
    final signature = await _channel.invokeMethod<Uint8List>('sign', {
      'data': signingInput,
    });
    if (signature == null || signature.length != 64) {
      throw PlatformException(code: 'bad_signature');
    }
    return signature;
  }
}
