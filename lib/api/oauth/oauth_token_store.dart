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

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/oauth_tokens.dart';

enum TokenProtection { passcode, biometric }

enum _Slot { a, b }

/// 受保護的 refresh token 讀不出來(使用者取消或沒通過生物辨識)。
/// 登入畫面據此提供「解鎖」入口,而不是當成已登出。
/// App 層的生物特徵把關沒通過（取消、失敗）。儲存層把它當成「還鎖著」處理，不清憑證。
/// 字串刻意不含 invalidated／itemnotfound，免得被誤判成憑證失效。
class BiometricGateDenied implements Exception {
  const BiometricGateDenied();
  @override
  String toString() => 'BiometricGateDenied';
}

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

  /// 與 [clear] 相同，但不碰存取時要驗證的區域（Android 的 biometric namespace：
  /// 外掛對它的任何呼叫都會先初始化 cipher 而跳出驗證），所以保證不跳驗證。
  /// 那裡的殘留沒有 meta 指向、讀不到，下次以生物辨識保護寫入時會先刪再寫。
  /// iOS Keychain 刪除不需驗證，與 [clear] 等效。給舊版保留憑證的啟動遷移用（ADR-0019）。
  Future<void> clearWithoutPrompt();

  /// 丟掉記憶體中的明文（等同重開 App）,下一次 [read] 重新走受保護的讀取
  /// (受生物辨識保護時會再跳出驗證)。不刪任何落地資料。
  Future<void> lock();

  /// 舊版（0.41.x）「登出但保留憑證」留下的標記是否還在。只讀不寫：新版不再保留，
  /// 啟動時看到就把憑證刪掉（ADR-0019）；標記由 [clear] 一併刪除。讀它不會跳出驗證。
  Future<bool> hasLegacyKeptMarker();

  /// 開啟生物辨識登入者主動登出、保留憑證的「登出保留」標記（ADR-0020）。冷啟動看到
  /// 就停在歡迎頁、不讀受保護憑證（不跳驗證），等使用者按「登入」才解鎖。
  /// 與舊版保留標記用不同的鍵，啟動遷移不會誤刪；讀它不會跳出驗證。由 [clear] 一併刪除。
  Future<bool> hasLogoutKeep();
  Future<void> setLogoutKeep(bool kept);

  /// 已存的憑證身分資訊（id_token 等，不含 refresh token）；沒有憑證回 null。
  /// 只讀不受保護的部分，不會跳出驗證（ADR-0020：web 登入完成時據此判斷是不是同一帳號）。
  Future<OAuthTokens?> peek();
}

/// Keychain／Keystore 的最小介面(測試以假的替換)。
abstract interface class SecretVault {
  Future<String?> read(String key, {required TokenProtection protection});
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  });

  /// 刪除項目。[protection] 指出項目放在哪一種保護等級（Android 的 biometric 項目在
  /// 獨立實例，刪除它會初始化該實例而可能跳驗證，所以不指定就只動 passcode 實例）；
  /// iOS 維持原狀，兩種等級各刪一次（Keychain 刪除不需驗證）。
  Future<void> delete(String key, {TokenProtection? protection});

  /// biometric 項目是否放在獨立的儲存實例（Android）；iOS 為 false。
  bool get biometricUsesOwnNamespace;
}

class FlutterSecureVault implements SecretVault {
  FlutterSecureVault({
    FlutterSecureStorage? storage,
    TargetPlatform? platform,
    Future<bool> Function()? biometricGate,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _platform = platform ?? defaultTargetPlatform,
       _biometricGate = biometricGate;

  /// Android 的 biometric 實例已被外掛初始化的行程內旗標。外掛的生物辨識驗證只在
  /// 實例初始化時做一次，之後的讀取不會再驗證，所以這個旗標成立後的每次讀取都要先過
  /// [_biometricGate]（App 層的生物特徵驗證）。第一次（尚未初始化）由外掛自己驗證，
  /// 不把關，免得跳兩次。
  bool _biometricInstanceReady = false;

  /// 回 false＝使用者沒通過（取消、失敗）；由 App 層提供，api 層不依賴 Flutter。
  final Future<bool> Function()? _biometricGate;

  bool _gatedInstance(TokenProtection p) =>
      p == TokenProtection.biometric && biometricUsesOwnNamespace;

  final FlutterSecureStorage _storage;
  final TargetPlatform _platform;

  @override
  bool get biometricUsesOwnNamespace => _platform == TargetPlatform.android;

  static const _iosPasscode = IOSOptions(
    accessibility: KeychainAccessibility.passcode,
  );
  // 只接受生物辨識（ADR-0019）：passcode accessibility＝WhenPasscodeSetThisDeviceOnly
  // （僅限這台裝置），access control 只有 biometryCurrentSet（不能改用裝置密碼，生物
  // 特徵增減後項目失效）。不可加 `or`／devicePasscode 或改成 userPresence。
  static const _iosBiometric = IOSOptions(
    accessibility: KeychainAccessibility.passcode,
    accessControlFlags: [AccessControlFlag.biometryCurrentSet],
  );
  // flutter_secure_storage 以 storageNamespace／sharedPreferencesName 為 key 快取 plugin
  // 實例，cipher 以第一次呼叫的選項為準；不分開的話 biometric 設定會被 passcode 的第一次
  // 呼叫蓋掉（Android 上「生物辨識登入」就沒有綁生物辨識）。
  // strongBiometricOnly：金鑰只接受 BIOMETRIC_STRONG，外掛同時設
  // setInvalidatedByBiometricEnrollment(true)（新增或更改指紋即失效）；驗證視窗沒有裝置
  // 密碼選項，所以要給取消鈕。
  static const _androidBiometric = AndroidOptions.biometric(
    storageNamespace: 'biometric',
    enforceBiometrics: true,
    biometricType: AndroidBiometricType.strongBiometricOnly,
    biometricPromptTitle: '登入 Tripline',
    biometricPromptSubtitle: '使用生物辨識登入',
    biometricPromptNegativeButton: '取消',
  );

  IOSOptions _ios(TokenProtection p) =>
      p == TokenProtection.biometric ? _iosBiometric : _iosPasscode;

  AndroidOptions _android(TokenProtection p) => p == TokenProtection.biometric
      ? _androidBiometric
      : const AndroidOptions();

  @override
  Future<String?> read(
    String key, {
    required TokenProtection protection,
  }) async {
    if (_gatedInstance(protection) && _biometricInstanceReady) {
      final gate = _biometricGate;
      if (gate != null && !await gate()) throw const BiometricGateDenied();
    }
    final value = await _storage.read(
      key: key,
      iOptions: _ios(protection),
      aOptions: _android(protection),
    );
    if (_gatedInstance(protection)) _biometricInstanceReady = true;
    return value;
  }

  @override
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  }) async {
    await _storage.write(
      key: key,
      value: value,
      iOptions: _ios(protection),
      aOptions: _android(protection),
    );
    if (_gatedInstance(protection)) _biometricInstanceReady = true;
  }

  @override
  Future<void> delete(String key, {TokenProtection? protection}) async {
    // Android 的 biometric 實例一碰就會初始化（可能跳驗證），不指定就只動 passcode 實例。
    final targets = biometricUsesOwnNamespace
        ? [protection ?? TokenProtection.passcode]
        : TokenProtection.values;
    for (final p in targets) {
      await _storage.delete(key: key, iOptions: _ios(p), aOptions: _android(p));
      if (_gatedInstance(p)) _biometricInstanceReady = true;
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

  /// 舊版「登出後保留」的帳號標記；新版只讀不寫，[clear] 會刪掉。
  static const _keptKey = 'tripline_oauth_kept_account';

  /// 新版「登出保留」標記（ADR-0020）；刻意與 [_keptKey] 不同鍵，啟動遷移才分得開。
  static const _logoutKeepKey = 'tripline_oauth_logout_keep';

  final SecretVault _vault;
  TokenProtection _protection = TokenProtection.passcode;

  /// 磁碟上 refresh token 項目實際所在的保護等級（setProtection 期間與 [_protection] 不同）。
  TokenProtection _storedProtection = TokenProtection.passcode;

  /// meta 的 bio_ns 版本標記：Android 的 biometric 項目已放在獨立 namespace。
  static const _bioNs = 1;

  /// 目前有效的 refresh token 槽位（讀到 meta 或寫入成功後更新）。
  _Slot _slot = _Slot.a;

  /// 每次 clear 加一。寫入跨多次 vault 呼叫，期間若被 clear（登出）就要收回剛寫的
  /// 項目，不能讓已登出的憑證被寫回（ADR-0019）。
  int _clearEpoch = 0;

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

    _storedProtection = _protection;
    _slot = meta['refresh_slot'] == 'b' ? _Slot.b : _Slot.a;
    if (_protection == TokenProtection.biometric &&
        _vault.biometricUsesOwnNamespace &&
        meta['bio_ns'] != _bioNs) {
      return _migrateToBiometricNamespace(meta);
    }

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

  /// Android 舊版把 biometric 項目放在 passcode 實例（沒有真的綁生物辨識）：用 passcode
  /// 選項讀出（不驗證）→ 以 biometric 選項寫進新 namespace 的另一個槽位（此時才第一次
  /// 驗證）→ 更新 meta 標記 → 刪舊項目。任何一步失敗都不丟例外讓 app 當掉：
  /// 取消驗證回鎖定（舊項目保留，下次再試），其餘退化成重新登入。
  Future<OAuthTokens?> _migrateToBiometricNamespace(
    Map<String, dynamic> meta,
  ) async {
    final oldKey = _slotKeys[_slot]!;
    final String? refresh;
    try {
      refresh = await _vault.read(oldKey, protection: TokenProtection.passcode);
    } on Exception {
      await clear();
      return null;
    }
    if (refresh == null || refresh.isEmpty) {
      await clear();
      return null;
    }
    final target = _slot == _Slot.a ? _Slot.b : _Slot.a;
    try {
      await _vault.write(
        _slotKeys[target]!,
        refresh,
        protection: TokenProtection.biometric,
      );
    } on Exception catch (e) {
      if (_isInvalidated(e)) {
        await clear();
        return null;
      }
      throw const TokenStoreLockedException(); // 取消或暫時失敗：舊項目還在
    }
    try {
      await _vault.write(
        _metaKey,
        jsonEncode({...meta, 'refresh_slot': target.name, 'bio_ns': _bioNs}),
        protection: TokenProtection.passcode,
      );
    } on Exception {
      await clear();
      return null;
    }
    _slot = target;
    try {
      await _vault.delete(oldKey, protection: TokenProtection.passcode);
    } on Exception {
      // 舊項目刪不掉：meta 已指向新槽位，下次輪替的清理會處理。
    }
    return _cache = OAuthTokens.fromJson({...meta, 'refresh_token': refresh});
  }

  @override
  Future<void> write(OAuthTokens tokens) async {
    // 這次程式生命週期還沒讀過憑證（例如生物辨識取消後改用 web 登入，ADR-0020）：
    // 先從 meta 取得保護等級與槽位，舊的 refresh token 才會被刪到、保護等級不會被改掉。
    if (_cache == null) await _loadMeta();
    _cache = tokens.withoutAccessToken();
    await _persist(_cache!);
  }

  /// 只讀 meta（裝置密碼等級，不跳驗證）同步保護等級與目前槽位；沒有或壞掉就不動。
  Future<void> _loadMeta() async {
    final Map<String, dynamic> meta;
    try {
      final raw = await _vault.read(
        _metaKey,
        protection: TokenProtection.passcode,
      );
      if (raw == null || raw.isEmpty) return;
      meta = jsonDecode(raw) as Map<String, dynamic>;
    } on Exception {
      return;
    }
    _protection = meta['protection'] == 'biometric'
        ? TokenProtection.biometric
        : TokenProtection.passcode;
    _storedProtection = _protection;
    _slot = meta['refresh_slot'] == 'b' ? _Slot.b : _Slot.a;
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
    if (_protection == TokenProtection.biometric &&
        _vault.biometricUsesOwnNamespace) {
      meta['bio_ns'] = _bioNs;
    }
    final epoch = _clearEpoch;
    final targetProtection = _protection;
    try {
      if (rotates) {
        await _vault.delete(_slotKeys[target]!, protection: _protection);
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
      if (rotates) {
        await _vault.delete(_slotKeys[target]!, protection: _protection);
      }
      return false;
    }
    if (epoch != _clearEpoch) {
      // 寫入期間被 clear（登出）：收回這次寫下的項目，clear 的結果為準。
      await _vault.delete(_metaKey, protection: TokenProtection.passcode);
      if (rotates) {
        await _vault.delete(_slotKeys[target]!, protection: targetProtection);
      }
      return false;
    }
    final old = _slot;
    final oldProtection = _storedProtection;
    _slot = target;
    _storedProtection = _protection;
    if (!rotates) return true;
    try {
      await _vault.delete(_slotKeys[old]!, protection: oldProtection);
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
    // Android 的 biometric 實例一碰就可能跳驗證：只有確定用到它才清（含全新 store 靠 meta 判斷）。
    final touchBiometric =
        _vault.biometricUsesOwnNamespace &&
        (_protection == TokenProtection.biometric ||
            _storedProtection == TokenProtection.biometric ||
            await _metaSaysBiometric());
    await _clear(touchBiometric: touchBiometric);
  }

  @override
  Future<void> clearWithoutPrompt() => _clear(touchBiometric: false);

  Future<void> _clear({required bool touchBiometric}) async {
    _clearEpoch++;
    _cache = null;
    _protection = TokenProtection.passcode;
    _storedProtection = TokenProtection.passcode;
    await _vault.delete(_metaKey, protection: TokenProtection.passcode);
    for (final key in _slotKeys.values) {
      await _vault.delete(key, protection: TokenProtection.passcode);
    }
    await _vault.delete(_keptKey, protection: TokenProtection.passcode);
    await _vault.delete(_logoutKeepKey, protection: TokenProtection.passcode);
    if (!touchBiometric) return;
    for (final key in _slotKeys.values) {
      try {
        await _vault.delete(key, protection: TokenProtection.biometric);
      } on Exception {
        // 取消驗證或金鑰已失效：憑證已登出，盡力而為。
      }
    }
  }

  Future<bool> _metaSaysBiometric() async {
    try {
      final raw = await _vault.read(
        _metaKey,
        protection: TokenProtection.passcode,
      );
      if (raw == null || raw.isEmpty) return false;
      return (jsonDecode(raw) as Map<String, dynamic>)['protection'] ==
          'biometric';
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> lock() async {
    _cache = null;
    _reading = null;
  }

  @override
  Future<bool> hasLegacyKeptMarker() async {
    final v = await _vault.read(_keptKey, protection: TokenProtection.passcode);
    return v != null && v.isNotEmpty;
  }

  @override
  Future<OAuthTokens?> peek() async {
    final raw = await _vault.read(
      _metaKey,
      protection: TokenProtection.passcode,
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      final meta = jsonDecode(raw) as Map<String, dynamic>;
      return OAuthTokens.fromJson({...meta}..remove('refresh_token'));
    } on Exception {
      return null; // 壞掉的資料視為沒有憑證
    }
  }

  @override
  Future<bool> hasLogoutKeep() async =>
      await _vault.read(_logoutKeepKey, protection: TokenProtection.passcode) ==
      '1';

  @override
  Future<void> setLogoutKeep(bool kept) => kept
      ? _vault.write(_logoutKeepKey, '1', protection: TokenProtection.passcode)
      : _vault.delete(_logoutKeepKey, protection: TokenProtection.passcode);

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

  /// 模擬舊版留下的「登出後保留」標記（[clear] 會清掉）。
  bool legacyKeptMarker = false;

  bool _logoutKeep = false;

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

  /// 與正式版一樣：剛寫入的憑證留在記憶體，之後讀取不必再驗證。
  @override
  Future<void> write(OAuthTokens tokens) async {
    _tokens = tokens.withoutAccessToken();
    _locked = false;
  }

  @override
  Future<OAuthTokens?> peek() async {
    final tokens = _tokens;
    return tokens == null
        ? null
        : OAuthTokens.fromJson({...tokens.toJson()}..remove('refresh_token'));
  }

  @override
  Future<bool> setProtection(TokenProtection protection) async {
    _protection = protection;
    return true;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    legacyKeptMarker = false;
    _logoutKeep = false;
    _locked = false;
    _protection = TokenProtection.passcode;
  }

  @override
  Future<void> clearWithoutPrompt() => clear();

  @override
  Future<bool> hasLegacyKeptMarker() async => legacyKeptMarker;

  @override
  Future<bool> hasLogoutKeep() async => _logoutKeep;

  @override
  Future<void> setLogoutKeep(bool kept) async => _logoutKeep = kept;
}
