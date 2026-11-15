/// 與 api（trip-planner-api）約定的 OAuth 協定字串，Flutter 端的單一出處。
/// 授權網址參數名、值，以及 callback 帶回來的 `error` 值都在這裡；
/// 其他檔案與測試一律引用，不再各自寫字面值。
library;

abstract final class OAuthProtocol {
  // 授權網址參數名
  static const biometricHintParam = 'biometric_hint';
  static const promptParam = 'prompt';
  static const biometricIntentParam = 'biometric_intent';
  static const expectedAccountParam = 'expected_account';

  /// `prompt` 的值：要求使用者重新輸入密碼（重新驗證用）。
  static const promptLogin = 'login';

  // biometric_hint 的值：web 登入頁據此顯示按鈕名稱
  static const hintFaceId = 'faceid';
  static const hintTouchId = 'touchid';
  static const hintGeneric = 'generic';

  // biometric_intent 的值（發起時帶出去、callback 帶回來）
  static const intentEnable = 'enable';
  static const intentDisable = 'disable';

  // callback 的 error 值
  static const errorReauthAccountMismatch = 'reauth_account_mismatch';
  static const errorAccessDenied = 'access_denied';
}
