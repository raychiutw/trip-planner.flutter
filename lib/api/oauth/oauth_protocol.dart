/// 與 api（trip-planner-api）約定的 OAuth 協定字串，Flutter 端的單一出處。
/// 授權網址參數名、值，以及 callback 帶回來的參數都在這裡；
/// 其他檔案與測試一律引用，不再各自寫字面值。
library;

abstract final class OAuthProtocol {
  // 授權網址參數名
  static const biometricHintParam = 'biometric_hint';

  /// 授權網址帶給 web 的明暗（`light`／`dark`）。
  static const themeParam = 'theme';

  /// callback 帶回來的參數名：web 登入頁按了生物辨識鈕（ADR-0018／0019）。
  /// 只出現在 callback，授權網址不帶。
  static const biometricIntentParam = 'biometric_intent';

  // biometric_hint 的值：web 登入頁據此顯示按鈕名稱
  static const hintFaceId = 'faceid';
  static const hintTouchId = 'touchid';
  static const hintGeneric = 'generic';

  /// biometric_intent 的值：請在手機上開啟生物辨識登入。
  static const intentEnable = 'enable';
}
