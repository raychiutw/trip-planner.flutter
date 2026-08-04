---
status: accepted
---

# 刪除一律不可復原,不提供 Undo、垃圾桶或 restore

Tripline 一度往相反方向走過。`docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md` 是一份完整的後端交付規格:`poi_favorites` 加 `deleted_at` 改軟刪除、新增 `POST /api/poi-favorites/:id/restore`、伺服器保留 10 分鐘復原期限、逾時回 `410 UNDO_EXPIRED`(該文件第 31~36、50~81 行)。那份規格的目的只有一個 —— 讓收藏的取消可以在 App 的 Undo 提示期間收回。

**現在的決定是:使用者資料的刪除一律永久。** 適用於行程、Day、停留點、筆記、分享連結與收藏,全部走「先具名確認 → 伺服器成功後才從畫面移除 → 失敗保留原資料並可重試」,沒有 Undo、沒有垃圾桶、沒有復原期限、沒有 restore 動線。這條線寫在 `design.md:214` 與 `design.md:234`,並由 `design.md:237` 明文覆蓋上面那份後端交付文件。程式碼側的收斂點是 `lib/app/irreversible_action.dart:87`(`confirmAndDelete`),行程項目、筆記、備選 POI 都掛在它下面。

需要為此開一份 ADR,是因為**收藏是全 App 唯一一處「後端有復原能力、App 卻刻意不用」的地方**。後端的 restore endpoint 與 `deleted_at` 欄位並沒有退休 —— 交付文件第 5 行寫的是「Flutter #88 已停止呼叫 restore endpoint,後端 endpoint 是否退休不在本次範圍」。也就是說,任何人翻到後端 API 或那份規格,都會看到一條 App 沒有接上的復原路徑,而 `lib/api/favorites_repository.dart:37` 只有 `deleteFavorite`,沒有對應的 `restoreFavorite`。沒有這份文件,那個落差看起來就是「Undo 漏做了」,而不是「Undo 被拿掉了」。

用詞上先釐清:取消收藏在語彙上是**移除**(解除可重建的關聯,POI 本身不動,之後可以重新收藏),但被移除的那一筆關聯 —— 連同它的 note 與原始收藏時間 —— 是**刪除**,永久且不可復原。重新收藏得到的是一筆新的關聯,不是原來那筆。本 ADR 談的是後者。

## Considered Options

**後端軟刪除 + server 端復原視窗(被拒的主要方案)** —— 也就是 `2026-07-18-poi-favorites-undo-restore-api.md` 那份規格。它的成本不在 App:需要 `ALTER TABLE poi_favorites ADD COLUMN deleted_at`(第 90 行),需要把「同一使用者 + 同一 POI」的唯一性換成 partial unique index `WHERE deleted_at IS NULL`(第 96~98 行),而且**所有直接查詢或 join `poi_favorites` 的 route 都要補上 active 條件**,規格自己註明「不能只改收藏清單 route」(第 101 行)。這是一次 **schema migration,而且發生在另一個 repository** —— 後端在 `trip-planner`,本專案是它的 client,「後端不動」是這個 repo 的前提。為了一個 Undo 按鈕去動共用後端的資料表結構,代價與收益不成比例。

而規格本身暴露了這個方案真正的問題:**server 的復原期限是 10 分鐘,App 的 Undo 按鈕只顯示 6 秒**(第 77 行)。差了一百倍,而規格對這個落差的解釋是「較長的 server window 用於網路重試,不新增最近刪除 UI」。換句話說,使用者能感知的復原期是 6 秒,但資料庫要為此多背 10 分鐘的 soft-deleted 狀態(實際保留下限是 24 小時,第 103 行),外加 restore 與重新 POST 的競速處理(第 82、149 行)、`poi_favorite.restored` audit event(第 120 行)、以及三個寫入路徑各自的快取失效(第 121 行)。6 秒的使用者價值,買了一套永久存在於 schema 與每一條查詢裡的雙態資料。

**Client 端 optimistic undo(不真的送 DELETE,6 秒後才送)** —— 不用改後端,聽起來便宜。但它與 `design.md:233` 直接衝突:伺服器成功後才從畫面移除資料。optimistic 的作法是先騙畫面、後送請求,一旦那 6 秒內 app 被切走、網路斷掉或程序被系統回收,使用者看到的「已刪除」與伺服器狀態就永久分岔,而且分岔的方向是**使用者以為刪掉了、其實沒有**。用一個新的不一致來源去換一個 6 秒的反悔窗口,不划算。

**App 用 `POST /api/poi-favorites` 猜測式重建** —— 這是後端 restore 出現前的作法,也正是那份規格開宗明義要淘汰的(第 13 行:「不再由 App 用 `POST /api/poi-favorites` 猜測式重建」)。它做不到還原:新建的是另一個 favorite id,原本的 note 與 `favorited_at` 已經沒了,而且遇到 active duplicate 還會撞 `409 DATA_CONFLICT`(第 113 行)。一個會把使用者的備註默默丟掉的 Undo,比沒有 Undo 更糟 —— 它承諾了復原,交付的是重建。

**最近刪除 / 垃圾桶頁** —— 唯一能讓「復原」名副其實的方案,但它要求**每一種可刪除資源都實作軟刪除**,不只收藏,還有行程、Day、停留點、筆記、分享連結。規格自己把範圍劃在單筆收藏,並明講「本期不做通用回收桶」(第 16、103 行)。除了後端成本,它還要在 App 裡多一個一級目的地,而 root tab bar 只有聊天 / 行程 / 地圖 / 收藏四格,沒有第五格給一個使用者一年用不到一次的頁面。

**選定:一律永久刪除,把成本壓在刪除之前** —— 復原路徑的替代品是**具名確認**。`design.md:225` 要求確認畫面顯示對象名稱、影響與「無法復原」,`design.md:226` 要求安全選項是預設焦點、破壞性按鈕明寫「刪除」。實際文案都指名對象:`lib/features/trips/trips_list_screen.dart:684`(「這會刪除其中所有行程日與景點」)、`lib/features/trips/edit/edit_trip_screen.dart:199`(「這會刪除當天所有景點,並重新編號後續行程日」)、`lib/features/trip_detail/trip_timeline_screen.dart:1093`(「刪除『X』後,相關交通時間將重新計算」)、`lib/features/trip_detail/trip_notes_screen.dart:1006`、`lib/features/trips/share/share_screen.dart:191` 與 `:203`、`lib/features/trip_detail/entry_poi_screen.dart:259`。收藏的單筆與批次確認在 `lib/features/favorites/favorites_screen.dart:600` 與 `:530`。`design.md:219` 另外停用了 full swipe 直接執行 —— 右滑只揭露刪除按鈕,不會一滑到底就沒了。

## Consequences

- **後端的 restore endpoint 與 `deleted_at` 會繼續存在,這是已知且刻意的**。本專案不驅動它退休(交付文件第 5 行已把它劃在範圍外)。看到它的人請讀這份 ADR,不要把它當成「App 忘了接」。

- **確認對話框是唯一的防線,所以文案品質等於資料安全**。復原路徑存在時,含糊的文案只是體驗差;沒有復原路徑時,含糊的文案就是資料遺失。新增任何刪除入口都必須指名對象與連帶影響,不能只寫「確定要刪除嗎?」。

- **批次刪除沒有交易性,部分失敗就是部分永久刪除**。`lib/features/favorites/favorites_screen.dart:542`~`:559` 是 N 個獨立的 `DELETE` 併發送出,成功的那些已經不可逆。目前的處理是把失敗的 id 留在選取狀態並提供重試(`:567`~`:572`),而不是回滾 —— 因為回滾正是這份 ADR 拒絕掉的能力。

- **失敗必須保留資料,這是不可復原的對偶要求**。`lib/app/irreversible_action.dart:76`~`:80` 在動作失敗時顯示可重試的錯誤而不動畫面資料,`confirmAndDelete` 的失敗文案是「刪除失敗,原資料已保留」(`:103`)。刪除不可逆的前提是「沒成功就什麼都沒發生」;任何讓刪除半途而廢又改動本地狀態的路徑,都會製造無從復原的破損。

- **用詞目前有一處混用待收**:`lib/features/favorites/favorites_screen.dart:600` 的訊息是「將從收藏移除『X』。刪除後無法復原。」,同一句同時用了移除與刪除。依上面的區分,這句其實是對的(移除關聯 / 刪除那筆資料),但讀起來像口誤,值得改寫成單一動詞。
