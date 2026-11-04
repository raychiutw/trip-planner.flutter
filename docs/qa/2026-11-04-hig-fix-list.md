# HIG 比對後的修改清單（#531）

日期：2026-11-04。來源：[App 逐張檢查報告](2026-11-04-hig-screenshot-review-app.md)（102 個場景全看）與 web 逐張檢查報告（trip-planner repo 的 `docs/qa/2026-11-04-hig-web-screenshot-review.md`，27 個場景桌機與手機寬全看）。

這份清單只列「要改什麼」，每項都帶位置、建議改法與怎麼驗證。**還沒有動任何程式碼**；排序是我的建議，開票與否由你決定。

證據強度：**程式碼**＝對照過原始碼；**像素**＝量過；**看圖**＝只有目視，改之前建議先在真機或模擬器再確認一次。

## 一、證據修正（S1～S3 已完成並重拍）

三項都是測試端的改動，不影響 App 行為。已修、重拍並換入 `2026-11-04-hig-screenshots/`，各自用 mutation 驗過 proof 會轉紅。

| # | 場景 | 問題 | 建議修改 | 驗證 |
|---|---|---|---|---|
| S1 ✅ | `auth-reset-password-expired` | stub 丟 `expired`，畫面只認 `RESET_TOKEN_INVALID`／`MISSING`，顯示的是「暫時無法處理」，不是過期提示（程式碼，`account_flow_screens.dart:541-546`） | 場景 stub 改丟畫面認得的 code | 重拍後畫面出現過期提示文字；`hig_scene_guidelines_test` 仍綠 |
| S2 ✅ | `trip-map-route-failed` | 與 `trip-map` 位元組完全相同（SHA-1），沒有失敗畫面 | **根因**：fixture 每天只有一個有座標的停留點，`_routePairsForTab` 湊不出相鄰兩點，`fetchRoute` 從未被呼叫，失敗 stub 形同虛設。修法：場景給第 1 天補第二個有座標的停留點，proof 確認 `trip-map-route-error` | 重拍後 SHA-1 不同，且畫面看得到失敗提示 |
| S3 ✅ | `ax-favorites-2x` | 沒有 `act` 餵收藏資料流（對照 `favorites` 場景），只拍到載入骨架（程式碼加看圖） | 補上與 `favorites` 相同的 `act` | 重拍後是 2x 的收藏清單 |

另有兩個場景受限，不是缺陷：`trip-map`、`ax-trip-map-2x`、`global-map` 的地圖是測試用純色 fixture，玻璃元件的對比（量得 2.07～2.74:1）**不能當對真實地圖的結論**，要真機看。web 的 `trip-map`、`map` 場景擋掉了 Google Maps，畫面是錯誤態，同理。

**mutation 證據**（commit `848d1387` 之前，把三處修正各自改回去：S1 code 改回 `expired`、S2 拿掉 `watchDays` stub、S3 拿掉 `act`，跑 `flutter test test/flows/hig_scene_a11y_collect_test.dart --dart-define=HIG_COLLECT=true --dart-define=HIG_ONLY=auth-reset-password-expired,trip-map-route-failed,ax-favorites-2x`）：

```
1 場景 auth-reset-password-expired 沒有渲染出預期畫面
2 場景 ax-favorites-2x 沒有渲染出預期畫面
2 場景 trip-map-route-failed 沒有渲染出預期畫面
02:01 +0 -6: Some tests failed.
```

三個場景 × 淺深共 6 項失敗；`auth-reset-password-expired` 只印出 1 行訊息（另一項失敗的訊息沒有被輸出，原因我沒追）。改回正確版本後同一指令 6 項全過。

## 二、App 要改的

**#544 處理結果**（分支 `fix/hig-app-544`，每項先紅燈再實作；✅＝已修，⚪＝查過不改，A3／A4 要先決定，沒動）：

- ✅ A1 註冊鈕：未勾同意停用並顯示說明。✅ A2 加入行程錯誤態：圖示加「返回」。✅ A5 登入裝置頁：深色紅色 `#FF453A`→`#FF6961`（4.09→4.94）、OAuth 說明卡降一階底色。✅ A6 已連結 App：Chip 取目前主題底色、圖示對齊標題。✅ A7 健檢卡同寬（紅燈 720 vs 175）。✅ A9 公開分享頁大字級主按鈕獨立一列。⚪ **A10 已取消**：改走單一 tint（維持 Apple 的做法，預設分頁列選中標籤 4.39:1 記為已知例外，「提高對比」時才加深，見 #550）；#545 先前加的 `onPrimaryContainer` 特例已回退。✅ A11 補標籤：日期條、搜尋欄、收藏列。
- **紅燈證據**（各項在實作前實際看到的失敗輸出）：A1 `Expected: null / Actual: <Closure _submit>`（建立鈕原本可按）；A2 找不到錯誤圖示與「返回」；A5 對比 `4.090967…`（深色紅字）；A6 `chip.backgroundColor` 為 null；A7 `Expected 720.0 / Actual 175.0`；A9 `Expected ≥ 414.0 / Actual 350.0`；A10 對比 `4.389355…`（與工具掃描 4.39 一致）；A11 `labeledTapTargetGuideline` 回報確切節點（日期條 `Rect 0,0 177×48`、收藏列、探索頁 `Rect 16,128 → 784,188`）。
- **審查後的調整**：① A2 原本手刻圖示加文字，改為重用 `TpStateView`（票文要求重用既有錯誤態元件）。② A11 搜尋欄原本全域在 `AppSearchField` 加 label，審查指出可能讓其他畫面念兩遍；我用語意樹傾印確認：探索頁外層 `[tap]` 節點 label 為空，但在最小環境下 label 會與 hint 合併成「搜尋地點⏎搜尋地點」。改為選擇性參數 `semanticLabel`，只有探索頁傳。**仍需用真機 VoiceOver 確認探索頁搜尋欄的朗讀不重複**（外層節點「搜尋地點」加內層欄位 hint，是兩個元素，不是同一個念兩遍，但我沒用真正的 VoiceOver 驗過）。③ 淺色選中前景改用 `tintDeep` 後，App 內並存兩個棕色：一般前景仍是 `primary #8A6038`，分頁列與日期條選中字是較深的 `#6F4C2C`。這是為了對中性選取底達 4.5:1 的刻意差異，設計上要不要統一由你決定。④ 深色 `destructiveBackground`（錯誤面板底）仍是 `#FF453A` 的 20% alpha，沒有跟著換色，只換了文字用的 destructive；這是刻意的（底色飽和度不動），但錯誤面板文字對比靠的是文字色變亮。
- **A10 回退後的複掃**（同一支工具）：一般狀態未過 **52**＝分頁列 4.39:1 的 36 個場景（已知例外）加上範圍外的 16 項（對話框動作顏色、地圖 fixture）；標籤缺漏仍是 0。以「提高對比」重掃：未過 47，5 項改善、0 項變差，**分頁列那批仍是 4.39:1**，也就是目前的提高對比主題還沒有把 tint 加深，這正是 #550 要做的事。
- ⚪ **A8 不改**：`oauth-consent-invalid` 是路由解析失敗與深連結的終點，本來就沒有上一頁，已有明確出口「返回行程列表」；`InvalidLinkScreen` 是 `secondary_authenticated_surfaces_hig_test` 明確登記的 `publicException`。加返回鈕沒有可回的目標。
- **修正後複掃**（`flutter test test/flows/hig_scene_a11y_collect_test.dart --dart-define=HIG_COLLECT=true`，同一支工具）：未過次數 **66 → 16**；VoiceOver 標籤缺漏 **22 → 0**；分頁列 4.39:1 的 36 個場景 **→ 0**；`account-sessions` 三項全過。剩下 16 項全是「不在 #544 範圍」的兩類：確認對話框動作顏色（T2，`account-logout-confirm`、`account-connected-app-revoke-confirm`、`trip-delete-confirm`、`invite-wrong-account-pending`、`app-lock-enable-prompt`，另 `account-delete-dialog` 的「永久刪除」是停用態）與地圖 fixture（T4）。
- 修了 A10 之後，**`app-lock-enable-prompt` 的 4.37:1 沒有跟著消失**：它是 `CupertinoAlertDialog` 的動作按鈕，屬 T2，不是分頁列那個 token。

| # | 場景 | 檢查表 | 問題 | 建議修改 | 強度 |
|---|---|---|---|---|---|
| A1 ✅ | `auth-signup` | F5 | 空表單、未勾同意時「建立」仍可按（`account_flow_screens.dart:145` 是 `primaryActionEnabled: !_submitting`） | 欄位未通過驗證或未勾同意時停用，與 web 對齊（web 已是停用外觀加就地說明） | 程式碼 |
| A2 ✅ | `add-to-trip-invalid-favorite`、`add-to-trip-missing-data` | G6、G7 | 有說明原因，但只有一行灰字，沒有圖示、重試或返回；底部分頁列仍顯示（`add_to_trip_screen.dart:76,90`） | 改用專案既有的錯誤態元件，附「返回」；分頁列的處理與 A4 一起決定 | 程式碼加看圖 |
| A3 | `trip-edit` | D10、G5 | 同一個有「取消」的表單，部分欄位按「儲存」才生效、日期與天數立即生效 | 統一成「全部按儲存才生效」，或拿掉「取消」改成即時儲存 | 看圖 |
| A4 | `entry-add`／`entry-edit`／`entry-copy`／`entry-move` | D12、D15 | modal 式表單下方仍顯示底部分頁列 | 改成真正的 modal 呈現（sheet 或全螢幕覆蓋，自然蓋住分頁列）。注意 D15 要求不要隱藏或停用 tab bar，所以不是在路由上單純關掉分頁列，要先決定這些表單屬於「分頁內的頁面」還是「modal」 | 看圖 |
| A5 ✅ | `account-sessions` | C1 | 「管理已連結應用」文字 4.36:1，低於 4.5:1；該卡疑似帶按下或焦點外框 | 調深文字色或換 token；確認外框是否為殘留焦點 | 像素加看圖 |
| A6 ✅ | `account-connected-apps` | C4、H2 | 深色下 scope 標籤沒有膠囊底；列內圖示與標題錯位 | 補深色底色 token；對齊圖示與標題基線 | 看圖 |
| A7 ✅ | `trip-health-findings` | 版面 | 第二張建議卡只有第一張一半寬 | 兩張卡同寬（檢查 Row／Expanded） | 看圖 |
| A8 ⚪ | `oauth-consent-invalid` | D3 | 沒有返回鈕或導覽列，只有頁內連結 | 補返回；或確認這頁只能由系統瀏覽器進入而不需要 | 看圖 |
| A9 ✅ | `ax-public-share-2x` | B2 | 「登入後複製行程」折成兩行並剩孤字「程」，與兩個圖示鈕擠同列（`public_share_screen.dart:247`） | 大字級時按鈕換到獨立一列 | 看圖 |
| A10 ⚪ | 有分頁列的 36 個淺色場景 | C1 | 選中分頁標籤（11pt）4.39:1，未達 4.5:1；`app-lock-enable-prompt` 的小字動作 4.37:1（T1） | 調深淺色的 accent 文字 token；改前先量新值 | 工具量測 |
| A11 ✅ | `trip-timeline`（Day 分頁條）、`favorites`（每列）、`explore`（一個全寬可點節點） | VoiceOver | 可點擊節點沒有語意標籤（T5～T7） | 先定位到 widget，再補 `Semantics(label:)`；補完把掃描結果由 66 次未過降下來 | 工具量測 |

| A12 | `collab-load-failed` | F5 | 「新增」鈕在 Email 為空時仍可按（`collab_screen.dart:300` 是 `onPressed: state.adding ? null : …`），與註冊頁修正前同一個問題 | 與 A1 同樣做法：欄位未填時停用 | 程式碼加獨立複核 |
| A13 | `explore-search-failed` | G6 | 錯誤訊息只有「搜尋失敗,請稍後再試」，沒說原因（`explore_controller.dart:182,189`） | 依錯誤類型給原因（斷線、被限流、伺服器錯誤） | 程式碼加獨立複核 |
| A14 | 全 App 字級 | B1 | 檢查表要求正文預設 17pt；App 的主題 `bodyLarge` 15、`bodyMedium` 13、`titleSmall` 13、`bodySmall` 12，比 iOS 的 body 17、footnote 13、caption 12 小一級。螢幕上的最小字級是 11pt（符合下限）。**要你決定**：這是 App 為了資訊密度做的刻意取捨，還是要拉回 17 | 決定後才動；有代價（版面全面換行、截圖全部重拍） | 程式碼（`app_theme.dart:259-329`） |
| A15 | 減少動態效果 | I | 兩處動畫沒有降級：分享頁建立連結後捲回頂端 250ms（`share_screen.dart:274`）、更多選單按壓縮放 150ms（`tp_more_menu.dart:760`）。其餘我查到的捲動與進度動畫都有 `disableAnimationsOf` 判斷 | 補 `disableAnimationsOf` 判斷，與 `chat_screen.dart` 的作法一致 | 程式碼（靜態稽核，未涵蓋全部動畫） |

**與專案決策有張力，需要你決定要不要改規則，不建議直接改程式：** `account-home`、`account-home-security` 的生物辨識開關與外觀設定（F7、H1）；`app-lock-enable-prompt` 在 App 內詢問是否開 Face ID（F7）。這些都是已知的專案決定。

## 三、web 要改的

| # | 場景 | 檢查表 | 問題 | 建議修改 | 強度 |
|---|---|---|---|---|---|
| W1 | `account-sessions`、`account-connected-apps`、`developer-apps` | 版面 | 頁面上方小標被固定頁首壓住而被裁切或重疊，桌機與手機都有 | 頁面內容區加上頁首高度的 `scroll-margin`／padding-top | 看圖 |
| W2 | `trip-detail`（桌機） | E1 | 地圖面板錯誤態的「重試」是未套樣式的原生灰色按鈕 | 改用專案按鈕元件 | 看圖 |
| W3 | `trip-detail`（手機） | 版面 | 移動方式膠囊超出右緣被截斷 | 允許換行或改成可橫向捲動並露出邊緣提示 | 看圖 |
| W4 | `explore`（手機） | — | 篩選膠囊「Sight 1」與卡片類別「SIGHT」是未在地化的英文原值 | 類別 key 對照到中文標籤 | 看圖 |
| W5 | `trips-new`（手機） | B | 日期欄位「選擇日期」字級明顯大於同頁其他 placeholder | 與其他欄位的 placeholder 字級對齊 | 看圖 |
| W6 | `trip-detail` | WCAG 2.5.3 | 起訖時間 chip 的 `aria-label="編輯起訖時間"` 蓋掉可見時間文字（`EntryTimeChip.tsx:140`，9 個節點） | 讓 accessible name 以可見文字開頭，如「09:00–12:00，編輯起訖時間」 | axe 加程式碼 |
| W7 | `trips-new` | WCAG 2.5.3、ARIA | 日期欄的 `aria-label` 與可見文字不一致；`aria-required` 加在不允許的角色上 | 先讀 `TripDatePicker`，把 `required` 改用該角色允許的方式表達 | axe（元件內部未讀） |
| W8 | `trip-print` | C5 | 分區數量標籤 `#8a7a68`、11px，4.14:1（`tripPrintStyles.ts:66`） | 調深該色至 4.5:1 以上 | axe 加程式碼 |
| W9 | `trips-list-error` | G6、G7 | 行程清單載入失敗只有一行字，沒有重試（`TripsListPage` 錯誤態沒有任何重試動作） | 補「重試」，行為與 App 的錯誤態一致 | 看圖加程式碼 |
| W10 | `invite-invalid` | G6、G7 | 邀請連結無效（永久失效）卻只提供「重試載入」，也沒有回首頁或登入的出口 | 無效連結不給重試，改給「回首頁」或「登入」 | 看圖 |
| W11 | `signup-check-email`、`invite` | B7 | 320px 加 200% 文字時橫向捲動（scrollWidth 354、366 對 320）；尚未定位是哪個元素 | 先定位再修；用 `hig-a11y-collect` 的重排檢查驗證 | 量測（未定位） |

web 補掃（axe、320px 重排、200% 文字、鍵盤焦點）詳見 web 報告「補掃」一節：重排與放大沒有橫向捲動；`explore` 搜尋欄的焦點樣式待目視確認；`landing` 的 200% 文字檢查沒有生效。

需要設計確認、不一定要改：`trip-print` 淺深兩色相同（列印預覽固定淺色）；`login`、`signup`、`forgot-password` 的桌機右側宣傳面板與外觀反相；`login` 手機寬卡片內外各有一個 Tripline 標誌。

## 三之三、補掃：文字對比與 VoiceOver 標籤（工具量測）

用 Flutter 內建的 `textContrastGuideline` 與 `labeledTapTargetGuideline` 掃 100 個場景（`components`、`ax-components-2x` 是元件示範頁，沒掃）× 淺深，共 200 次；66 次有項目未過。指令：`flutter test test/flows/hig_scene_a11y_collect_test.dart --dart-define=HIG_COLLECT=true`（只印 `HIGA11Y` 行，不是守門；沒帶旗標會 skip）。

**限制：**對比由工具以渲染後像素取樣，半透明玻璃、對話框 blur 底、停用狀態的取樣不可靠；下表只收「對照截圖後仍成立」的項目。本輪沒有再另外手量，數值是工具輸出。

| # | 範圍 | 結果 | 判讀 |
|---|---|---|---|
| T1 | 底部分頁列「選中」的標籤（11pt），淺色，36 個場景（`trips-list`、`trip-timeline`、`favorites`、`explore`、`chat`、`entry-*`、`trip-health-*`、`trip-audit-*` 等） | 4.39:1，未達 4.5:1 | 同一個 accent 色小字，一處 token 就能修；深色沒有這個問題。`app-lock-enable-prompt` 的「稍後再說」「開啟」也是 4.37:1，同一類 |
| T2 | 確認對話框的紅色或強調動作，淺色（`account-logout-confirm`「登出」3.00、`account-connected-app-revoke-confirm`「撤銷」3.14、`trip-delete-confirm`「刪除行程」3.39）；深色約 4.3～4.4 | 低於 4.5:1 | 這是 CupertinoAlertDialog 加 systemRed，與 iOS 原生同量級，屬於「與原生一致 vs 達到 WCAG」的張力，需你決定，不建議直接改 |
| T3 | `account-sessions`：「管理已連結應用」3.62:1（淺色，15pt）、「登出此帳號」4.09:1（深色）；`account-sessions-load-failed` 深色「無法載入登入裝置」3.95:1（13pt） | 低於 4.5:1 | 與先前手量的 4.36:1 同方向（取樣位置不同，數字不同，結論一樣：未達標）。已併入 A5 |
| T4 | 地圖頁底部分頁列未選中標籤（`trip-map`、`global-map*`、`ax-trip-map-2x`，3.18～3.31，`global-map-empty`／`load-failed` 2.23～2.43） | 低於 4.5:1 | 背景是測試地圖 fixture，**不能下結論**，要真機 |
| T5 | `trip-timeline`、`trip-map*`、`global-map`、`ax-*` 對應場景的「Day 分頁條」（`Rect 12,80 → 381,128`，可左右捲動與點擊） | 整條節點沒有語意標籤 | VoiceOver 會讀不出這條控制項；要找到對應 widget 補 `Semantics(label:)`（程式碼還沒查，只有節點座標） |
| T6 | `favorites`：每一列（有「移除」自訂動作與長按）沒有語意標籤 | 缺標籤 | 同上，VoiceOver 讀不出列的名稱；與 HIG 長按選單規則（選項要在主介面也看得到）一併檢查 |
| T7 | `explore`、`explore-empty-results`、`explore-search-failed`（含 `ax-explore-2x`）：一個全寬可點節點（`Rect 16,128 → 377,188`）沒有標籤 | 缺標籤 | 同上，還沒對到是哪個 widget |

**排除的誤報：**`account-delete-dialog`「永久刪除」1.89／2.00:1，截圖顯示它是密碼欄為空時的停用狀態（WCAG 對停用元件不要求對比），不算缺陷。

建議處理：T1（一處 token）與 T5～T7（補標籤）已列為上面的 A10、A11；T2 列為張力；T4 等真機。

## 三之二、證據連結與一手來源

截圖在 [`2026-11-04-hig-screenshots/`](2026-11-04-hig-screenshots/)（`light/`、`dark/` 各一張，檔名＝場景名稱加 `.png`）。條目對應的一手來源都在[檢查表](../research/2026-11-04-hig-screen-checklist.md)的「一手來源 URL」欄；下表只列本清單用到的條目。

| 項目 | 截圖 | 引用條目與一手來源 |
|---|---|---|
| S1 ✅ | `auth-reset-password-expired` | 無（場景缺陷，與 HIG 無關） |
| S2 ✅ | `trip-map-route-failed`、`trip-map` | 無（場景缺陷） |
| S3 ✅ | `ax-favorites-2x` | 無（場景缺陷） |
| A1 | `auth-signup` | F5：HIG/entering-data |
| A2 | `add-to-trip-invalid-favorite`、`add-to-trip-missing-data` | G6、G7：HIG/feedback；「缺下一步動作」**無一手來源**，是專案內的可用性判斷 |
| A3 | `trip-edit` | D10：HIG/sheets；G5：HIG/feedback |
| A4 | `entry-add`、`entry-edit`、`entry-copy`、`entry-move` | D12：HIG/modality；D15：HIG/tab-bars |
| A5 | `account-sessions` | C1：HIG/accessibility |
| A6 | `account-connected-apps` | C4：HIG/color；H2：HIG/dark-mode |
| A7 | `trip-health-findings` | 無（版面問題，無對應 HIG 條目） |
| A8 | `oauth-consent-invalid` | D3：HIG/toolbars |
| A9 | `ax-public-share-2x` | B2：HIG/accessibility |
| A10 | 36 個有分頁列的淺色場景（例：`trips-list`、`chat`） | C1：HIG/accessibility |
| A11 | `trip-timeline`、`favorites`、`explore` | 無一手來源條目（檢查表沒有 VoiceOver 標籤專條；以 Flutter 的 `labeledTapTargetGuideline` 為依據） |
| W1～W8 | web 報告各場景 | web 條目依 WCAG 2.2／APG，HIG 數值套到 web 是專案自訂標準；見 web 報告 |

## 清單覆蓋率

App 路由與彈出層對照見[畫面清單](../research/2026-11-04-hig-app-screen-inventory.md)。**本報告只涵蓋「有 mock 場景」的 102 個畫面**；清單裡仍標「缺口」的彈出層（date／time picker、`showAppConfirm`、`showAppDestructiveConfirm`、`showAppAlert`、`showAppFormSheet`、`showAppNotice` 等）沒有取證，不能因為本報告而視為通過。

## 四、看過但判定沒問題的（避免重複討論）

- 大字級（B2）：能判讀的 `ax-*` 場景都沒有截斷。分段控制元件在大字級改垂直堆疊，是 `tp_segmented_control.dart:106` 的刻意設計；選中態堆疊後只靠底色。導覽列標題膠囊在 2x、3x 沒有跟著放大，我沒判斷這算不算違規。
- 深色模式：淺深兩色在可判讀的場景都有對應的 token，除了 A6。
- 就地錯誤與停用鍵：`share-custom-expiry-missing` 符合預期（錯誤「請選擇到期日」＋建立鈕停用）。

## 五、沒涵蓋的

- 沒量字級（B1）。對比：App 已用內建工具掃過（見三之三），web 沒有量。
- VoiceOver 只做了「可點擊元素有沒有標籤」的靜態檢查，沒有真的用 VoiceOver 走過；Increase Contrast、Reduce Motion 沒檢查。
- web：axe、320px 重排、200% 文字、鍵盤焦點已用工具掃過（有限制，見 web 報告），沒有 dialog 行為檢查；只跑 chromium，webkit 瀏覽器未安裝所以沒跑。
- 彈出層（sheet、dialog、picker）大多沒有場景，見 `docs/research/2026-11-04-hig-app-screen-inventory.md` 的缺口摘要。
- 「符合」與「未見明顯問題」是我目視的結論，沒有第二人複核。

## 建議順序

1. ~~S1～S3（場景修好並重拍）~~ 已完成。
2. A1、A2、A4（行為性缺陷，有程式碼證據）、T1、T5～T7（工具量測，有確切節點）。
3. A5～A9、W1～W5（視覺類，先在模擬器或瀏覽器再確認一次再改）。
4. A3 與張力項目要先做決定。
