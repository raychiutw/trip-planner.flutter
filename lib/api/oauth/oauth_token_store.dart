/// 登入憑證的落地儲存(ADR-0014)。
///
/// 只存 refresh token 與身分資訊,**絕不存 access token**。refresh token 依保護等級
/// 放進 Keychain／Keystore:
/// - [TokenProtection.passcode]:要求裝置有設密碼(沒設就不落地,只活在這次程式生命
///   週期,下次開 app 重新登入)。
/// - [TokenProtection.biometric]:讀取時要通過目前登記的生物辨識;生物特徵集合變動後
///   項目失效,需重新登入。
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/oauth_tokens.dart';

enum TokenProtection { passcode, biometric }

/// 受保護的 refresh token 讀不出來(使用者取消或沒通過生物辨識)。
/// 登入畫面據此提供「解鎖」入口,而不是當成已登出。
class TokenStoreLockedException implements Exception {
  const TokenStoreLockedException();
  @override
  String toString() => 'TokenStoreLockedException';
}

abstract class OAuthTokenStore {
  /// 目前保護等級。
  TokenProtection get protection;

  /// null = 沒有登入。可能丟 [TokenStoreLockedException]。
  Future<OAuthTokens?> read();
  Future<void> write(OAuthTokens tokens);

  /// 改變 refresh token 的保護等級並以新等級重存。
  /// 回 false 代表新等級存不進去（例如裝置沒設密碼），保護等級維持原樣。
  Future<bool> setProtection(TokenProtection protection);
  Future<void> clear();
}

/// Keychain／Keystore 的最小介面(測試以假的替換)。
abstract interface class SecretVault {
  Future<String?> read(String key, {required TokenProtection protection});
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  });
  Future<void> delete(String key);
}

class FlutterSecureVault implements SecretVault {
  FlutterSecureVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _iosPasscode = IOSOptions(
    accessibility: KeychainAccessibility.passcode,
  );
  static const _iosBiometric = IOSOptions(
    accessibility: KeychainAccessibility.passcode,
    accessControlFlags: [AccessControlFlag.biometryCurrentSet],
  );
  static const _androidBiometric = AndroidOptions.biometric(
    enforceBiometrics: true,
    biometricType: AndroidBiometricType.strongBiometricOnly,
    biometricPromptTitle: '登入 Tripline',
  );

  IOSOptions _ios(TokenProtection p) =>
      p == TokenProtection.biometric ? _iosBiometric : _iosPasscode;

  AndroidOptions _android(TokenProtection p) => p == TokenProtection.biometric
      ? _androidBiometric
      : const AndroidOptions();

  @override
  Future<String?> read(String key, {required TokenProtection protection}) =>
      _storage.read(
        key: key,
        iOptions: _ios(protection),
        aOptions: _android(protection),
      );

  @override
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  }) => _storage.write(
    key: key,
    value: value,
    iOptions: _ios(protection),
    aOptions: _android(protection),
  );

  @override
  Future<void> delete(String key) async {
    for (final p in TokenProtection.values) {
      await _storage.delete(key: key, iOptions: _ios(p), aOptions: _android(p));
    }
  }
}

/// 正式環境。公開部分(身分、保護等級)與 refresh token 分開存:啟動時要先知道
/// 保護等級才知道怎麼讀,而讀 refresh token 才會觸發生物辨識。
class SecureOAuthTokenStore implements OAuthTokenStore {
  SecureOAuthTokenStore({SecretVault? vault})
    : _vault = vault ?? FlutterSecureVault();

  static const _metaKey = 'tripline_oauth_tokens';
  static const _refreshKey = 'tripline_oauth_refresh';

  final SecretVault _vault;
  TokenProtection _protection = TokenProtection.passcode;

  /// 讀到或寫入過的憑證留在記憶體:輪替 refresh token 與每次取用都不用再碰
  /// Keychain,生物辨識只在冷啟動讀取時出現。
  OAuthTokens? _cache;

  @override
  TokenProtection get protection => _protection;

  Future<OAuthTokens?>? _reading;

  /// 同時多處讀取共用一次 Keychain 存取，免得冷啟動連跳多次生物辨識。
  @override
  Future<OAuthTokens?> read() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _reading ??= _readFromVault().whenComplete(() => _reading = null);
  }

  Future<OAuthTokens?> _readFromVault() async {
    final rawMeta = await _vault.read(
      _metaKey,
      protection: TokenProtection.passcode,
    );
    if (rawMeta == null || rawMeta.isEmpty) return null;
    final Map<String, dynamic> meta;
    try {
      meta = jsonDecode(rawMeta) as Map<String, dynamic>;
    } on Exception {
      return null; // 壞掉的資料視為未登入
    }
    _protection = meta['protection'] == 'biometric'
        ? TokenProtection.biometric
        : TokenProtection.passcode;

    final String? refresh;
    try {
      refresh = await _vault.read(_refreshKey, protection: _protection);
    } on Exception catch (e) {
      if (_isInvalidated(e)) {
        // 生物特徵變動或項目失效:當作已登出,要求重新登入。
        await clear();
        return null;
      }
      throw const TokenStoreLockedException();
    }
    if (refresh == null || refresh.isEmpty) return null;
    return _cache = OAuthTokens.fromJson({...meta, 'refresh_token': refresh});
  }

  @override
  Future<void> write(OAuthTokens tokens) async {
    _cache = tokens.withoutAccessToken();
    await _persist(_cache!);
  }

  /// 落地；存不進去回 false（記憶體仍留著，下次開 app 重新登入）。
  Future<bool> _persist(OAuthTokens persisted) async {
    final meta = {...persisted.toJson()}..remove('refresh_token');
    meta['protection'] = _protection.name;
    try {
      await _vault.write(
        _metaKey,
        jsonEncode(meta),
        protection: TokenProtection.passcode,
      );
      final refresh = persisted.refreshToken;
      if (refresh != null && refresh.isNotEmpty) {
        await _vault.write(_refreshKey, refresh, protection: _protection);
      }
      return true;
    } on Exception {
      // 裝置沒設密碼等,存不進去:只留記憶體,下次開 app 重新登入。
      await _vault.delete(_metaKey);
      await _vault.delete(_refreshKey);
      return false;
    }
  }

  @override
  Future<bool> setProtection(TokenProtection protection) async {
    final current = await read();
    if (current == null || protection == _protection) return true;
    final previous = _protection;
    // 不同 access control 的同名項目不能原地改，先刪再寫。
    await _vault.delete(_refreshKey);
    _protection = protection;
    if (await _persist(current)) return true;
    // 新等級存不進去：退回原等級並盡力把憑證存回去，UI 不會顯示成已開啟。
    _protection = previous;
    await _persist(current);
    return false;
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _protection = TokenProtection.passcode;
    await _vault.delete(_metaKey);
    await _vault.delete(_refreshKey);
  }

  /// iOS errSecItemNotFound／Android KeyPermanentlyInvalidated 這類「項目已不可用」。
  static bool _isInvalidated(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('invalidated') ||
        text.contains('-25300') ||
        text.contains('itemnotfound');
  }
}

/// 測試用:純記憶體。與正式版一樣不保留 access token。
class InMemoryOAuthTokenStore implements OAuthTokenStore {
  OAuthTokens? _tokens;
  TokenProtection _protection = TokenProtection.passcode;

  @override
  TokenProtection get protection => _protection;

  @override
  Future<OAuthTokens?> read() async => _tokens;

  @override
  Future<void> write(OAuthTokens tokens) async =>
      _tokens = tokens.withoutAccessToken();

  @override
  Future<bool> setProtection(TokenProtection protection) async {
    _protection = protection;
    return true;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    _protection = TokenProtection.passcode;
  }
}
