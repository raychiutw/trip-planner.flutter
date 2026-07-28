/// 錯誤訊息呈現的共用判斷式。
///
/// 全 app 的錯誤訊息走同一條三層 fallback:
/// **server 回繁中就直接用 → 否則查 code 對照表 → 再不然通用訊息**。
/// 第一層的判斷式（「這串字是不是已經是給人看的在地化文案」）原本在登入、帳號流程、
/// 異動紀錄、行程健檢四個畫面各抄了一份,抽到這裡共用。
library;

/// CJK 統一表意文字區(U+4E00–U+9FFF);pattern 只編譯一次。
final _cjkPattern = RegExp(r'[一-鿿]');

/// `value` 是否含中日韓文字。
///
/// 後端對已知情境會直接回繁中 message,而且往往比 client 的 code 對照表更精準
/// （帶上具體欄位、數量或秒數）。因此**只要是繁中就優先採用**,對照表與通用訊息
/// 都只是後端沒給人話時的備援 —— 這是三層 fallback 的第一層。
bool hasCjk(String value) => _cjkPattern.hasMatch(value);
