/// 原生 passkey 簽署（assertion）能力的窄介面，只給重新驗證（step-up）用。
///
/// 與 [PasskeyPlatform] 分開是為了不跟同時進行的 #610（登出後 passkey 登入，
/// 也要 authenticate）改同一支檔；之後合併時可收斂成同一個介面。
/// 真正的平台通道只在 [NativePasskeyReauthPlatform]，單元測試無法驗證，要靠真機（ADR-0016）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

sealed class PasskeyAssertOutcome {
  const PasskeyAssertOutcome();
}

/// [credential] 是 WebAuthn 的 PublicKeyCredential JSON（id、rawId、type、response），
/// 形狀與 `POST /account/reauth/passkey` 的 `credential` 相同。
class PasskeyAsserted extends PasskeyAssertOutcome {
  const PasskeyAsserted(this.credential);
  final Map<String, dynamic> credential;
}

/// 使用者在系統對話框按了取消。
class PasskeyAssertCancelled extends PasskeyAssertOutcome {
  const PasskeyAssertCancelled();
}

/// 其他平台失敗：裝置上找不到這組 passkey、沒設螢幕鎖定、網域關聯未通過、逾時……
class PasskeyAssertFailed extends PasskeyAssertOutcome {
  const PasskeyAssertFailed();
}

abstract interface class PasskeyReauthPlatform {
  /// [options] 是 `reauth/options` 的回應原樣。不會丟例外，結果都在 [PasskeyAssertOutcome]。
  Future<PasskeyAssertOutcome> authenticate(Map<String, dynamic> options);
}

class NativePasskeyReauthPlatform implements PasskeyReauthPlatform {
  NativePasskeyReauthPlatform([PasskeyAuthenticator? authenticator])
    : _authenticator = authenticator ?? PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  @override
  Future<PasskeyAssertOutcome> authenticate(
    Map<String, dynamic> options,
  ) async {
    try {
      final response = await _authenticator.authenticate(
        // 本機沒有這組 passkey 時不要直接失敗，讓系統提供跨裝置（掃碼）選項。
        AuthenticateRequestType.fromJson(
          options,
          preferImmediatelyAvailableCredentials: false,
        ),
      );
      return PasskeyAsserted(response.toJson());
    } on PasskeyAuthCancelledException {
      return const PasskeyAssertCancelled();
    } on Exception {
      return const PasskeyAssertFailed();
    }
  }
}

final passkeyReauthPlatformProvider = Provider<PasskeyReauthPlatform>(
  (ref) => NativePasskeyReauthPlatform(),
);
