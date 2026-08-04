---
status: accepted
---

# 離線佇列 flush 撞 409 STALE_ENTRY 時做三方 rebase,不丟棄離線編輯

停留點與筆記的更新帶 OCC token(`expectedVersion`)。離線期間的編輯進離線佇列,重連後重播;
只要這段時間有協作者改過同一筆,server 的 `version` 已經前進,重播的 PATCH 帶著舊
`expectedVersion` 打回 409 `STALE_ENTRY`。這是整套離線寫入裡唯一會造成資料遺失的缺口 ——
其他離線操作要嘛沒有 version(新增、刪除),要嘛根本是線上限定。

決定:flush 撞到 `STALE_ENTRY` 時,重抓 server 現況、與「離線寫入當下的值」(`base`)做三方比對,
沒有真衝突就換上新 `version` 自動重送,只有「同一個欄位離線與 server 都改了」才停下來問人
(`lib/api/api_client.dart:469`~`:497` 的分支、`:542` 的 `_tryRebase`)。為此
`QueuedMutation` 多帶一個 `base`(`lib/api/cache/cache_store.dart:41`),真衝突則寫進一個
獨立且持久化的衝突區(`lib/api/cache/cache_store.dart:154`~`:157`)等使用者二選一。

之所以做得起來,是因為後端 PATCH 是 diff-only:只送有改的欄位。離線沒碰的欄位不送就自然保留
server 的值,所以「合併」實際上退化成「只挑出使用者真的改過的欄位重送」
(`lib/api/cache/rebase_merge.dart:28` 的 `dirtyFields` + `lib/api/api_client.dart:685` 的
`_rebasedBody`),不需要真的把兩個版本組成一份新資料。

## Considered Options

**409 一律上報並丟棄(v1,做過再推翻)** —— 這不是紙上比較的選項,是實際跑過的行為。
`b471bcc`(PR-4 同步引擎)的 `flushQueue` 對任何 `ApiError` 都是 `conflicts.add(m)` +
`removeMutation(m.id)`,註解寫著「v1 不 rebase,列 PR-4b」。`2daa288` 補了一次:5xx 改成保留
佇列,因為「暫時性後端錯誤會永久遺失離線編輯」—— 但 409 仍然照丟。搭配的 UI 是
`dd7efc1` 的紅色狀態列「N 筆變更同步失敗(衝突)」加一顆「知道了」,按下去只是清掉一個記憶體
list。使用者看得到的只有一個數字:哪一筆、改了什麼、原本要改成什麼,全部不存在,而佇列裡那筆
早已被移除。**離線期間的編輯就這樣無聲消失**,而且是在使用者以為「已經存好了」之後。這一條線
被推翻的理由不是設計不夠漂亮,是它真的會吃掉資料。

**重抓 version 後無條件重送(last-write-wins)** —— 只把新的 `version` 換上去、原封不動重送整包,
不做任何比對。實作最短,而且確實不再丟失自己的編輯 —— 代價是改成默默覆蓋協作者的編輯:離線時
只改了標題,重送卻把描述、開始時間一併蓋回離線當下的舊值。以「不遺失資料」為目標的改動,結果
是換一個人的資料被吃掉,不算解決。這條路只保留為降級路徑:`base` 缺失時(舊佇列項升級、或入隊
當下該資源根本沒被快取過)`rebaseMerge` 回空 list(`lib/api/cache/rebase_merge.dart:10`),
退回 last-write-wins —— 有 `base` 才有三方,沒有就只剩兩方,這是資訊不足下的最後手段,不是預設。

**`rebaseMerge` 回傳合併後的結果** —— 直覺上三方 merge 應該吐出一份 merged body,現在它只回
`List<String> conflictFields`(`lib/api/cache/rebase_merge.dart:5`),看起來像個沒寫完的函式,
很容易被後人「順手補完」。**這是刻意的。** 通用 merge 沒有能力決定合併結果:同一次比對裡,
停留點的 `title` 是字串、`startTime` 是時間、筆記的 `fields` 可能是數字,每一種欄位「離線改了、
server 也改了」時該怎麼辦,是欄位語意的問題,不是比對演算法的問題。真正決定重送什麼的是呼叫端
`_rebasedBody`(`lib/api/api_client.dart:685`):它知道 body 是 snake_case、知道
`expectedVersion` 要換新值、知道沒被改過的欄位要整個不送好讓 server 的值留著。把這些搬進
`rebaseMerge` 只會讓一個能獨立測的純函式長出 API 形狀的知識。它的職責就是回答「哪些欄位不能
自動決定」,能自動決定的部分由呼叫端依語意處理。

**真衝突留在離線佇列裡等使用者處理** —— 不開衝突區,讓那筆 mutation 待在原地。但佇列的語意是
「插入序 = 重播序」(`lib/api/cache/cache_store.dart:149`),一筆等著人類回答的項目留在裡面,
每次 flush 都會再打一次必定 409 的 PATCH,而且卡住排在它後面的重播。等人的東西和等網路的東西
生命週期不同,混在同一條佇列會逼出一堆「跳過但不移除」的例外規則。分成兩個區之後,主佇列永遠
只裝「可以自動重試的東西」,flush 的迴圈維持單純。

**衝突清單放記憶體(v1 的 `syncConflictsProvider`)** —— v1 把上報的衝突放在記憶體 Notifier 裡。
關掉 app 就沒了,而對應的離線編輯早已離開佇列,等於換一種方式遺失。既然衝突現在是「等使用者回來
處理的待辦」,它的壽命就必須跨重啟,所以真相源改成持久化 store,provider 退化成讀它的
StreamProvider(`lib/features/offline/offline_sync.dart:25`),舊的記憶體版本連同「知道了」一起
移除 —— 兩者並存只會產生兩個互相不同步的衝突數字。

## Consequences

- **離線佇列與衝突區都是裝置上的持久化結構,換掉要做資料遷移。** 快取本身丟了只是重抓一次,
  但這兩個結構裡放的是「使用者已經做了、server 還不知道」的編輯 —— 沒有第二份。sembast → drift
  的搬遷因此只搬佇列與衝突區、不搬回應快取,並在失敗時保留舊檔等下次啟動重試
  (`lib/api/cache/cache_migration.dart:12`)。日後任何一次 schema 變動都要照這個規格處理。
- 舊佇列項沒有 `base` 欄位,讀回來是 `null`,行為降級成 last-write-wins。這是刻意讓升級不崩,
  代價是升級當下還在佇列裡的那幾筆拿不到三方保護。
- 衝突解決有兩顆鈕,但只有一顆會失敗:「保留你的」要重送(可能又離線、又撞 409,
  `lib/api/api_client.dart:977`),「用對方的」純本機移除(`:1007`)。UI 不能假設兩者對稱 ——
  重送沒成功就不准移除衝突記錄,否則會製造第二次遺失。
- rebase 要重抓的是整包(`/trips/:id/days?all=1` 或 `/trips/:id/notes`),且刻意不寫快取
  (`lib/api/api_client.dart:632`),避免用 server 真相蓋掉同一份快取上其他還沒同步的樂觀 patch。
  重抓在同一輪 flush 內以 cacheKey 去重,同一個行程的多筆衝突只打一次。
- server 回來的 row 沒有 `version` 時不重送,改當衝突上報(`lib/api/api_client.dart:569`)——
  帶著舊 `expectedVersion` 重送會永遠 409,變成 flush 每次都做一樣的事的 livelock。
