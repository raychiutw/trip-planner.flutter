---
status: accepted
---

# 離線快取存原始 wire JSON,快取層設在 ApiClient 而非 model 或 repository

Tripline 的殺手情境是「人在國外、弱網或離線,要看自己的行程」,所以離線能力的價值排序是先讀後寫
(見已歸檔的離線快取設計 spec 第 7~12 行)。要做離線就得把資料落地,問題只有
一個:**落地的是什麼形狀的東西,在哪一層攔截。**

決定:快取存的是**後端回來的原始 wire JSON**(`Object?` —— 可能是 Map、List、純量),攔截點在
`ApiClient`。`_send()` 是所有 request 的單一入口(`lib/api/api_client.dart:755`),GET 成功後在該處
write-through(`api_client.dart:840-855`)、連線層失敗時在該處回退快取(`api_client.dart:777-789`)。
持久層對 model 完全無感:drift 的回應表只有 `key` / `data` / `cachedAt` 三欄,`data` 是 JSON 文字
(`lib/api/cache/drift_cache_store.dart:35-52`)。

理由是省下一整層序列化的維護。`lib/models/` 目前 29 個檔、59 個 `fromJson`,而有 `toJson` 的只有 4 個
—— `DestinationInput`、`TripErrorReport`、`OAuthTokens`、`TripDocEntry`,全部是**送出去**的 payload
或密鑰儲存,沒有一個是為了快取存在。這個不對稱是刻意的:wire JSON 進來就是 client 手上最原始、最完整
的真相,parse 成 typed 物件是**呈現**用的,不是**儲存**用的。

## Considered Options

**替所有 model 補 `toJson`,在 repository 層快取 typed 物件** —— 直覺上「快取 model」比「快取 JSON」
型別安全,但代價是每個 model 都要維護雙向序列化:59 個 `fromJson` 要配 59 個 `toJson`,而且兩邊必須
永遠對稱,寫漏一個欄位不會編譯失敗,只會在離線時安靜地掉資料。要避免手寫就得引入 `json_serializable`
+ `build_runner`,但本專案明確決定手寫 `fromJson`、不引入 codegen —— server 端 `deepCamel()` 已把回應
轉成 camelCase,欄位 1:1 對應,codegen 換來的只有建置複雜度
(見 [ADR-0013](0013-hand-written-fromjson-no-codegen.md))。為了快取而推翻那個決定,是讓
次要需求去改寫主要架構。spec 當時量到的是「41 個 model 中 39 個沒有 `toJson`」
(該 spec 第 31 行),數字隨版本變動,結論不變。

**在各 repository 方法內自行讀寫快取** —— 攔截點會從 1 個變成幾十個。`TripRepository` 光是走
SWR 的讀就有 7 處(`lib/api/trip_repository.dart:111`、`222`、`257`、`332`、`743`、`785`,加
`favorites_repository.dart:26`),寫入另有 5 處。更關鍵的是,離線判定、429 retry、Bearer refresh、
204 處理本來就集中在 `_send()`;快取一旦下放到 repository,「什麼算離線」這個判斷就得在每個
呼叫點重複一次,而它其實只有一個正確答案(`api_client.dart:1026-1036`:連線層錯誤才算離線,
HTTP 4xx/5xx 是 server 有回應,不算)。

**靠 riverpod provider 既有的記憶體快取** —— `StreamProvider.family` 本來就會快取,從 timeline 切到
map 不會重打 API(`lib/features/trip_detail/trip_providers.dart:10-11`),看起來已經有一層快取了。但它活在 process
記憶體裡,app 一關就沒了,而離線寫的目標明確要求「編輯立即反映於 UI 且**重啟後仍在**」
(該 spec 第 18 行)。provider 快取解決的是同一次啟動內的重複請求,不是離線。

## Consequences

- **樂觀 patcher 必須用 wire 的形狀思考,型別系統幫不上忙。** patcher 的簽章是
  `(Object? cached, Map args) → Object?`(`lib/api/cache/optimistic_patchers.dart:8-9`),它要自己知道
  `GET /trips/:id/days?all=1` 是 day 的 List、每個 day 有 `timeline`
  (`optimistic_patchers.dart:60-80`),notes 則是「段名 → row List」的 Map
  (`optimistic_patchers.dart:164-180`)。寫錯不會編譯失敗,只會在測試裡爆 —— 所以 patcher 一律寫成
  純函式,每個 opType 各自單測。
- **request body 是 snake_case,快取是 camelCase,patcher 卡在中間要自己轉。** notes 的 `fields`
  直接來自 caller 送給後端的 body(`trip_repository.dart:377`),但要塞進快取就得先過
  `snakeToCamel`(`optimistic_patchers.dart:207-219`)。OCC 三方 merge 的 base / theirs 同樣是從
  wire JSON 抽欄位再對齊(`lib/api/cache/rebase_merge.dart:41-76`、`api_client.dart:665-671`)。
  這層轉換是「存 wire JSON」的直接帳單。
- **離線新增的資料要自己捏一個像 wire 的 row。** `_buildOptimisticEntry` 得補齊 `master`、
  `alternates`、`version`、`sortOrder` 等欄位(`optimistic_patchers.dart:118-146`),因為下游的
  `TimelineEntry.fromJson` 會照 wire 的期待去讀。model 若新增必填欄位,patcher 要跟著補 ——
  這是 typed 快取方案本來可以靠編譯器抓到、而我們換成靠測試抓的部分。
- **後端加欄位不需要快取 migration。** 持久層沒有 per-model schema,新欄位只是 JSON 文字裡多一個
  key;反過來,舊快取缺新欄位時由 `fromJson` 的缺漏預設吸收(list → `[]`、`version` → `0`,見
  `CODING_STANDARDS.md` 〈Model 與 fromJson 解析規則〉)。sembast → drift 的搬遷也因此只需要搬佇列與衝突區,回應快取直接丟掉
  重抓(`lib/api/cache/cache_migration.dart:12-13`)。
- **「快取內容 = wire JSON」是整個離線層的前提,不只是實作細節。** `getStream` 的 stale → fresh 兩段式
  發射(`api_client.dart:192-253`)、`sendMutation` 的離線佇列(`api_client.dart:265-335`)、
  `flushQueue` 的 409 rebase(`api_client.dart:422-522`)全部建在它上面 —— 核心不變式「任一 cache key
  的值 = server 真相 + 所有尚未 flush 的樂觀 patch」之所以能成立,正是因為 patch 的輸入與輸出跟 server
  回應是同一種形狀,可以反覆疊套而不需要來回 parse。要換成 typed 快取,這三塊都得重寫。
- **本 ADR 目前是離線層唯一的常駐紀錄。** `docs/` 沒有離線章節,只有 `README.md:18` 與 `:36`
  各一行提到離線快取;設計 spec 是一次性的交付文件,已隨舊工作流文件一併歸檔。改動離線層的人會
  先讀到這裡。
