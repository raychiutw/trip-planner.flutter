---
status: accepted
---

# 手寫 fromJson，不引入 json_serializable 與 build_runner

後端是共用的 Cloudflare Pages Functions API，回應在 server 端已經過 `deepCamel()`，wire format 是 camelCase(`docs/CONTRACTS.md:11`)。也就是說 JSON key 與 Dart 欄位名幾乎 1:1 對應 —— codegen 最常見的價值(snake_case ↔ camelCase 對映、大量 `@JsonKey` 標註)在這個專案裡幾乎不存在。

決定:`lib/models/` 的所有 model 一律手寫 immutable class —— `const` 建構子 + named 參數 + `factory X.fromJson(Map<String, dynamic> json)`(`docs/CONTRACTS.md:15`)，**不對 model 的 JSON 解析引入 codegen**。目前是 29 個檔、3643 行、59 個 `fromJson` factory。

措辭要精準:**這不是「本 repo 不用 codegen」**。`build_runner: ^2.15.1` 與 `drift_dev: ^2.34.0` 確實在 dev_dependencies 裡(`pubspec.yaml:79-80`)，供快取層的 drift 使用 —— 全 repo 唯一的產生檔是 `lib/api/cache/drift_cache_store.g.dart`(1320 行，`part` 宣告在 `lib/api/cache/drift_cache_store.dart:16`)。drift 的 schema-to-DAO 是 codegen 真正划算的場合:產生的是型別安全的查詢 API，手寫等於重寫一個 ORM。**model 的 JSON 解析不是那個場合。**

## Considered Options

**json_serializable + build_runner(全面套用 model 層)** —— 它省下的樣板量，在 `deepCamel()` 之後只剩「欄位名重複一次」。換來的是:每次改 model 欄位都要記得跑 build_runner、29 個 `.g.dart` 進版控(或不進版控、改成建置時產生，那就是 CI 與新機器上手都多一步)、產生檔與手寫檔在 review diff 裡混在一起。而且本專案的 `fromJson` 有相當比例根本不是純欄位映射:`lib/models/entry.dart:31` 對 `distanceM` / `distance_m` 兩種 key 做 fallback(`deepCamel()` 的前提有例外)、`lib/models/entry.dart:136-139` 的 `title` 是 `displayTitle` → 正選 POI 名稱 → `（未選擇景點）` 三段 fallback 算出來的衍生欄位、`lib/models/entry.dart:151` 把 `entryPoisVersion` 一律 `.toString()`。這幾類都得靠 `@JsonKey(readValue:)` 或自訂 converter 逃生，逃生口一開，codegen 的「一致性保證」就只剩在最簡單的那些欄位上成立 —— 而那些欄位本來就不會出錯。

**「build_runner 反正已經為 drift 裝了，順手也給 model 用」** —— 邊際成本看起來是零，但這句話混淆了兩件事。drift 的產生檔只有一個、跟著 schema 改，改動頻率低;model 是這個 app 變動最頻繁的一層(後端加欄位、P1/P2 一路加 model)。把高頻變動的一層綁上 codegen，等於把「改一個欄位」從編輯一個檔變成編輯一個檔 + 跑一次產生器 + 確認產生檔一致。已裝的相依不是理由，使用頻率才是。

**混用:欄位多的 model 走 codegen，其餘手寫** —— 最差的一種。解析規則的檢查點會從一個變成兩個:review 時要先判斷這個檔屬於哪一套，才知道該不該檢查 `num` 轉型。單一規則集能靠紀律守住，兩套並行的規則集連紀律都無從施力。

## Consequences

**紀律成本，這是後人最可能想推翻本決策的理由。** 沒有 codegen 就沒有編譯期的一致性保證，每個新 model 都得手動遵守同一組解析規則(`docs/reference-models.md:11-18`):

- 數字一律 `(json['x'] as num?)?.toInt()` / `?.toDouble()` —— server 可能回 int 也可能回 double(`lib/models/entry.dart:30`、`:78-79`)
- bool flag 接受 0/1 或 bool:`json['x'] == true || json['x'] == 1`(`lib/models/entry.dart:33`)
- 日期時間一律存字串、不轉 `DateTime`，顯示層要用再 parse(`lib/models/entry.dart:118-120`)
- list 欄位缺漏回 `[]`(`lib/models/entry.dart:156`)
- `sortOrder` / `version` 缺漏回 `0`(`lib/models/entry.dart:143`、`:150`)

漏掉其中任何一條，**建置不會紅**。`json['rating'] as double` 在 server 回整數 `4` 的那天才會炸，而且炸在使用者手上，不是 CI 上。這是本決策付出的真實代價，明確接受。

風險靠兩件事壓住:規則集中在單一處文件化，並在 `CONTRIBUTING.md:36` 的「不可妥協的慣例」有指向(規則本文折進 `CONTRIBUTING.md` 是票 #248 的範圍，本 ADR 不重述);以及每個 model 都有對照後端實際輸出的 `fromJson` 測試(`docs/explanation-architecture.md:96-97`)。**測試是這裡唯一的執行機制** —— 沒有 codegen 幫忙時，「規則有測試覆蓋」不是加分項而是前提。

另外兩點:

- `models/` 維持純 Dart、不 import Flutter，解析測試跑在 VM、不開 widget binding。這與手寫無關，但 codegen 產生檔會多綁一層工具鏈，維持純淨較容易。
- 反向序列化沒有一起手寫。目前只有 4 個 model 檔有 `toJson`，因為多數 mutation 直接組 request map。若哪天需要對稱的 `toJson` 覆蓋所有 model，樣板量會翻倍，屆時值得重新評估本決策 —— 但那是新的事實，不是現在的。
