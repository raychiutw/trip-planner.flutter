/// 手機與伺服器的時差（DPoP proof 的 `iat` 只容許 ±60 秒）。
///
/// 由 400 `invalid_dpop_proof` 回應的 `Date` 標頭校正，只放記憶體；token 端點
/// 與一般 API 請求共用同一個，免得其中一邊校正了另一邊還在用錯的時間。
library;

import 'dart:io' show HttpDate;

class DpopClock {
  Duration _offset = Duration.zero;

  /// 校正後的現在時間（簽 proof 用）。
  DateTime now() => DateTime.now().add(_offset);

  /// 用回應的 `Date` 標頭記下時差；回 true 表示已校正、可以重簽重送。
  /// 沒有 `Date` 或解析不了就無從校正，回 false。
  bool adoptServerDate(String? httpDate) {
    if (httpDate == null) return false;
    try {
      _offset = HttpDate.parse(httpDate).difference(DateTime.now());
      return true;
    } on Exception {
      return false;
    }
  }
}
