/// 錯誤訊息呈現的共用判斷式。
///
/// 全 app 的錯誤訊息走同一條三層 fallback:
/// **server 回繁中就直接用 → 否則查 code 對照表 → 再不然通用訊息**。
/// 第一層的判斷式（「這串字是不是已經是給人看的在地化文案」）原本在登入、帳號流程、
/// 異動紀錄、行程健檢四個畫面各抄了一份,抽到這裡共用。
library;

import '../api/api_error.dart';

/// CJK 統一表意文字區(U+4E00–U+9FFF);pattern 只編譯一次。
final _cjkPattern = RegExp(r'[一-鿿]');

/// `value` 是否含中日韓文字。
///
/// 後端對已知情境會直接回繁中 message,而且往往比 client 的 code 對照表更精準
/// （帶上具體欄位、數量或秒數）。因此**只要是繁中就優先採用**,對照表與通用訊息
/// 都只是後端沒給人話時的備援 —— 這是三層 fallback 的第一層。
bool hasCjk(String value) => _cjkPattern.hasMatch(value);

/// 把任何錯誤轉成可直接給使用者看的繁中訊息。
///
/// 順序:`byCode` 對照表 → 後端已給的繁中 `message` → 依 HTTP status 的通用訊息
/// → `fallback`。**絕不回傳 `ApiError.detail`**:那是除錯用的後端原文,可能含
/// SQL、欄位名或內部路徑。
String userFacingApiError(
  Object error, {
  required String fallback,
  Map<String, String> byCode = const {},
}) {
  if (error is! ApiError) return fallback;
  final mapped = byCode[error.code];
  if (mapped != null) return mapped;
  if (hasCjk(error.message)) return error.message;
  return switch (error.status) {
    401 => '登入已過期，請重新登入',
    403 => '你沒有權限執行這個操作',
    404 => '找不到相關資料，可能已被移除',
    429 => '操作太頻繁，請稍後再試',
    >= 500 && < 600 => '伺服器暫時無法處理，請稍後再試',
    _ => fallback,
  };
}
