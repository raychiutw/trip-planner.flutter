/// 原生 passkey 建立能力（iOS ASAuthorization／Android Credential Manager）的窄介面。
///
/// 畫面只依賴 [PasskeyPlatform]，測試注入假的；真正的平台通道只在
/// [NativePasskeyPlatform]，這裡無法在單元測試驗證，要靠真機（見 ADR-0016）。
///
/// 平台前置：iOS 靠 entitlements 的 `webcredentials:trip-planner-dby.pages.dev`（已設）；
/// Android 要 assetlinks.json 補 passkey 用的關聯（web #1678，需要 owner），沒補前建立會失敗。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import 'passkey_assertion.dart';

sealed class PasskeyCreateOutcome {
  const PasskeyCreateOutcome();
}

/// [credential] 是 WebAuthn 的 PublicKeyCredential JSON（id、rawId、type、response），
/// 形狀與 `POST /account/passkeys/register/verify` 的 `credential` 相同。
class PasskeyCreated extends PasskeyCreateOutcome {
  const PasskeyCreated(this.credential);
  final Map<String, dynamic> credential;
}

/// 使用者在系統對話框按了取消。
class PasskeyCancelled extends PasskeyCreateOutcome {
  const PasskeyCancelled();
}

/// 這支裝置已經有同帳號的 passkey（excludeCredentials 命中）。
class PasskeyAlreadyOnDevice extends PasskeyCreateOutcome {
  const PasskeyAlreadyOnDevice();
}

/// 其他平台失敗：裝置不支援、沒設螢幕鎖定、網域關聯未通過、逾時……
class PasskeyCreateFailed extends PasskeyCreateOutcome {
  const PasskeyCreateFailed();
}

abstract interface class PasskeyPlatform {
  /// [options] 是 `register/options` 的回應原樣。不會丟例外，結果都在 [PasskeyCreateOutcome]。
  Future<PasskeyCreateOutcome> create(Map<String, dynamic> options);

  /// 平台是否支援 passkey（登入頁入口的前提；查詢失敗一律當不支援）。
  Future<bool> isSupported();

  /// 登入用的 assertion。[options] 是 `oauth/passkey/options` 的回應原樣
  /// （allowCredentials 為空 = 讓系統列出此網域的 passkey）。不會丟例外。
  Future<PasskeyAssertion> authenticate(Map<String, dynamic> options);
}

class NativePasskeyPlatform implements PasskeyPlatform {
  NativePasskeyPlatform([PasskeyAuthenticator? authenticator])
    : _authenticator = authenticator ?? PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  @override
  Future<PasskeyCreateOutcome> create(Map<String, dynamic> options) async {
    try {
      final response = await _authenticator.register(
        RegisterRequestType.fromJson(options),
      );
      return PasskeyCreated(response.toJson());
    } on PasskeyAuthCancelledException {
      return const PasskeyCancelled();
    } on ExcludeCredentialsCanNotBeRegisteredException {
      return const PasskeyAlreadyOnDevice();
    } on Exception {
      // 套件的 AuthenticatorException、PlatformException、選項格式錯誤一律視為失敗。
      return const PasskeyCreateFailed();
    }
  }

  @override
  Future<bool> isSupported() async {
    try {
      // 2.23.1 沒有替代 API（PasskeyAvailability 不存在），升版時再換。
      // ignore: deprecated_member_use
      return await _authenticator.canAuthenticate();
    } on Exception {
      return false; // 查詢失敗（含沒有平台通道）一律當不支援，入口就不顯示
    }
  }

  @override
  Future<PasskeyAssertion> authenticate(Map<String, dynamic> options) async {
    try {
      final response = await _authenticator.authenticate(
        AuthenticateRequestType.fromJson(
          options,
          // 登入頁主動按下的流程：要出系統面板，不是只在有現成憑證時靜默回應。
          preferImmediatelyAvailableCredentials: false,
        ),
      );
      return PasskeyAsserted(response.toJson());
    } on PasskeyAuthCancelledException {
      return const PasskeyAssertCancelled();
    } on Exception {
      // 沒有 passkey、網域未關聯、裝置不支援、選項格式錯誤等一律視為失敗。
      return const PasskeyAssertFailed();
    }
  }
}

final passkeyPlatformProvider = Provider<PasskeyPlatform>(
  (ref) => NativePasskeyPlatform(),
);
