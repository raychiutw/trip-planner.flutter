import '../api/oauth/oauth_token_store.dart';
import 'app_lock.dart';
import 'biometric_login.dart';

/// Android：用保留的生物辨識憑證登入時的生物特徵把關。
///
/// flutter_secure_storage 的生物辨識驗證只在儲存實例初始化時做一次，同一行程內之後的
/// 讀取不會再驗證，所以第二次以後讀取前要由這裡驗證（只接受生物特徵，不接受裝置密碼）。
/// 回 false＝使用者沒通過（取消或失敗），呼叫端維持鎖定。
Future<bool> androidUnlockGate(
  BiometricAuthenticator auth, {
  Future<void> Function() waitForeground = waitUntilForeground,
}) async {
  Future<BiometricOutcome> attempt() =>
      auth.authenticate(reason: '登入 Tripline', biometricOnly: true);

  await waitForeground();
  var outcome = await attempt();
  // 從別的畫面回來的當下可能被系統中斷：等前景再試一次。
  if (outcome == BiometricOutcome.interrupted) {
    await waitForeground();
    outcome = await attempt();
  }
  return outcome == BiometricOutcome.success;
}

/// 正式環境的憑證儲存：接上 Android 的生物特徵把關（iOS 的 Keychain 每次讀取都會驗證，
/// 把關只對 Android 的 biometric 實例生效）。抽成函式讓這段組裝有測試。
SecureOAuthTokenStore createProductionTokenStore(BiometricAuthenticator auth) =>
    SecureOAuthTokenStore(
      vault: FlutterSecureVault(biometricGate: () => androidUnlockGate(auth)),
    );
