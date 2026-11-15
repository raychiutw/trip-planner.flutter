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

enum _Slot { a, b }

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

  /// 登出但保留憑證:丟掉記憶體中的明文,下一次 [read] 重新走受保護的讀取
  /// (受生物辨識保護時會再跳出驗證)。不刪任何落地資料。
  Future<void> lock();

  /// 「登出後保留」的帳號標示（顯示名稱或信箱，非機密）；null = 沒有保留。
  /// 與憑證放在同一個受保護儲存，[clear] 一併清掉，兩者同生同滅。
  Future<String?> readKeptAccount();
  Future<void> writeKeptAccount(String? label);
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
  // refresh token 輪流用兩個槽位：iOS 對既有的 biometric 項目改值（SecItemUpdate）
  // 疑似會再要求一次驗證（未經真機證實），所以輪替一律「寫進不存在的槽位＋刪舊槽位」。
  // 槽位 a 沿用舊版的單一 key，meta 沒有 refresh_slot 欄位＝舊資料＝槽位 a。
  static const _slotKeys = {
    _Slot.a: 'tripline_oauth_refresh',
    _Slot.b: 'tripline_oauth_refresh_b',
  };
  static const _keptKey = 'tripline_oauth_kept_account';

  final SecretVault _vault;
  TokenProtection _protection = TokenProtection.passcode;

  /// 目前有效的 refresh token 槽位（讀到 meta 或寫入成功後更新）。
  _Slot _slot = _Slot.a;

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

    _slot = meta['refresh_slot'] == 'b' ? _Slot.b : _Slot.a;

    final String? refresh;
    try {
      refresh = await _vault.read(_slotKeys[_slot]!, protection: _protection);
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
  ///
  /// 順序：(1) 刪目標槽位殘留 (2) 新 token 寫進目標槽位（項目不存在＝新增）
  /// (3) meta 指標改指目標 (4) 刪舊槽位。任何時刻磁碟上至少有一個可讀的槽位；
  /// (2)(3) 之間失敗，指標仍指舊槽位；(3)(4) 之間失敗，殘留的舊槽位下次 (1) 收拾。
  Future<bool> _persist(OAuthTokens persisted) async {
    final refresh = persisted.refreshToken;
    final rotates = refresh != null && refresh.isNotEmpty;
    // 沒有 refresh token 可寫時不換槽位，指標才不會指到空的槽位。
    final target = !rotates ? _slot : (_slot == _Slot.a ? _Slot.b : _Slot.a);
    final meta = {...persisted.toJson()}..remove('refresh_token');
    meta['protection'] = _protection.name;
    meta['refresh_slot'] = target.name;
    try {
      if (rotates) {
        await _vault.delete(_slotKeys[target]!);
        await _vault.write(
          _slotKeys[target]!,
          refresh,
          protection: _protection,
        );
      }
      await _vault.write(
        _metaKey,
        jsonEncode(meta),
        protection: TokenProtection.passcode,
      );
    } on Exception {
      // 裝置沒設密碼等,存不進去:只留記憶體,下次開 app 重新登入。
      // 只收拾這次寫到一半的目標槽位，舊槽位與 meta 原封不動。
      if (rotates) await _vault.delete(_slotKeys[target]!);
      return false;
    }
    final old = _slot;
    _slot = target;
    if (!rotates) return true;
    try {
      await _vault.delete(_slotKeys[old]!);
    } on Exception {
      // 舊槽位刪不掉：指標已指向新的，殘留的下次輪替會清。
    }
    return true;
  }

  @override
  Future<bool> setProtection(TokenProtection protection) async {
    final current = await read();
    if (current == null || protection == _protection) return true;
    final previous = _protection;
    // 新槽位以新等級新增、成功後才刪舊槽位；失敗時舊項目與 meta 都沒動，退回原等級即可。
    _protection = protection;
    if (await _persist(current)) return true;
    _protection = previous;
    return false;
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _protection = TokenProtection.passcode;
    await _vault.delete(_metaKey);
    for (final key in _slotKeys.values) {
      await _vault.delete(key);
    }
    await _vault.delete(_keptKey);
  }

  @override
  Future<void> lock() async {
    _cache = null;
    _reading = null;
  }

  @override
  Future<String?> readKeptAccount() async {
    final v = await _vault.read(_keptKey, protection: TokenProtection.passcode);
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> writeKeptAccount(String? label) => label == null || label.isEmpty
      ? _vault.delete(_keptKey)
      : _vault.write(_keptKey, label, protection: TokenProtection.passcode);

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
  String? _kept;

  @override
  TokenProtection get protection => _protection;

  bool _locked = false;

  /// 模擬 [lock] 之後的受保護讀取:true＝使用者通過生物辨識，false＝取消或失敗。
  bool unlockSucceeds = true;

  @override
  Future<OAuthTokens?> read() async {
    if (_locked) {
      if (!unlockSucceeds) throw const TokenStoreLockedException();
      _locked = false;
    }
    return _tokens;
  }

  @override
  Future<void> lock() async => _locked = true;

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
    _kept = null;
    _locked = false;
    _protection = TokenProtection.passcode;
  }

  @override
  Future<String?> readKeptAccount() async => _kept;

  @override
  Future<void> writeKeptAccount(String? label) async =>
      _kept = (label == null || label.isEmpty) ? null : label;
}
