# App 截圖逐張檢查報告（#531／#537 素材）

檢查日期：2026-11-04。對象：[`2026-11-04-hig-screenshots/`](2026-11-04-hig-screenshots/) 的 102 個場景（淺色、深色各一張，iPhone 17 模擬器）。依據：[HIG 檢查表](../research/2026-11-04-hig-screen-checklist.md)。

## 怎麼檢查的

把每個場景的淺色與深色拼成一張並排圖，由我逐張目視，對照檢查表的條目（D 導覽與 sheet、E 按鈕、F 輸入、G alert 與錯誤、H 深色模式等）。能自動算的只算了兩類：

- 對比：對少數可疑文字取前景與背景像素，用 WCAG 公式算比值（見各條說明）。
- 兩張圖是否相同：用 SHA-1。

觸控目標另有 `test/flows/hig_scene_guidelines_test.dart` 守門，本報告不重複。

## 結果總覽

| 結論 | 場景數 |
|---|---|
| 符合 | 33 |
| 未見明顯問題 | 47 |
| 疑慮 | 13 |
| 張力（與檢查表建議衝突，但屬已知專案決策） | 3 |
| 場景無效（截圖沒有證明想證明的畫面） | 3 |
| 無法判讀 | 3 |
| 未看 | 0 |

102 個場景全部看過（第一輪看 72 個，第二輪補看 30 個，含 20 個 `ax-*` 大字級場景）。B2（放大 200%）逐張看過：能判讀的 `ax-*` 場景沒有截斷（`ax-favorites-2x`、`ax-trip-map-2x` 除外，見發現 12 與逐場景），分段控制元件在大字級改垂直堆疊是刻意設計。「未見明顯問題」只代表目視沒看到，沒有量字級，也沒有逐一量對比。

## 需要處理的發現

| # | 場景 | 條目 | 發現 | 證據強度 |
|---|---|---|---|---|
| 1 | `auth-signup` | F5 | 空表單、未勾同意時「建立」仍可按 | 看圖加程式碼（`account_flow_screens.dart:145`） |
| 2 | `auth-reset-password-expired` | — | 場景 stub 用錯 error code，畫面顯示的不是過期提示 | 看圖加程式碼（`:541-546`） |
| 3 | `trip-map-route-failed` | — | 與 `trip-map` 位元組相同，沒有失敗畫面 | SHA-1 相同 |
| 4 | `trip-edit` | D10、G5 | 同一個有「取消」的表單，部分欄位按「儲存」才生效、日期與天數立即生效 | 看圖（畫面文字） |
| 5 | `entry-add`／`entry-edit`／`entry-copy`／`entry-move` | D12 | modal 式表單下方仍顯示底部分頁列 | 看圖 |
| 6 | `account-sessions` | C1 | 「管理已連結應用」4.36:1，低於 4.5:1；且該卡疑似帶按下／焦點外框 | 像素量測加看圖 |
| 7 | `account-connected-apps` | C4、H2 | 深色下 scope 標籤沒有膠囊底；列內圖示與標題錯位 | 看圖 |
| 8 | `trip-health-findings` | 版面 | 第二張建議卡只有第一張一半寬 | 看圖 |
| 9 | `oauth-consent-invalid` | D3 | 沒有返回鈕或導覽列，只有頁內連結 | 看圖 |
| 10 | `trip-map`、`trip-map-route-failed` | C1 | 玻璃元件量得 2.07～2.74:1，但背景是測試用純色，**不能當作對真實地圖的結論** | 像素量測，結論受限 |
| 11 | `add-to-trip-invalid-favorite`、`add-to-trip-missing-data` | G6、G7 | 錯誤有說明原因（G6 符合），但只有一行灰字，沒有圖示、重試或返回，底部分頁列仍顯示；「缺下一步動作」在檢查表沒有直接對應條目 | 看圖 |
| 12 | `ax-favorites-2x` | — | 場景沒有餵資料流，只拍到載入骨架，不是 2x 的清單畫面 | 看圖加程式碼對照 `favorites` 場景 |
| 13 | `ax-public-share-2x` | B2 | 「登入後複製行程」折行剩孤字，與圖示鈕擠同列 | 看圖 |

第 2、3、12 項是**證據本身的缺陷**（場景沒有證明想證明的畫面），不是 App 缺陷。這三個場景的守門（proof）只確認「畫面上有錯誤元素」，沒確認是想證明的那一種，需要修場景。

與專案決策有張力（非新發現）：`account-home`、`account-home-security` 有生物辨識開關與外觀設定（F7、H1）；`app-lock-enable-prompt` 在 App 內詢問是否開 Face ID（F7）。

## 逐場景結果

| 場景 | 檢視 | 結論 | 檢查表 | 說明 |
|---|---|---|---|---|
| `account-connected-app-revoke-confirm` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `account-connected-apps` | 淺深已看 | 疑慮 | C4、H2 | 深色下 scope 標籤（讀取／建立修改行程）沒有膠囊底，文字浮在卡片上；列左側圖示與標題錯位，留白不均 |
| `account-delete-dialog` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `account-developer-app-new` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `account-developer-apps` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `account-home-security` | 淺深已看 | 張力 | F7、H1 | 有「生物辨識 解鎖」開關（F7 建議避免）與「外觀」淺／深色設定（H1 建議避免）；已知專案決策，非新發現 |
| `account-home` | 淺深已看 | 張力 | F7、H1 | 有「生物辨識 解鎖」開關（F7 建議避免）與「外觀」淺／深色設定（H1 建議避免）；已知專案決策，非新發現 |
| `account-logout-confirm` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `account-sessions-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `account-sessions` | 淺深已看 | 疑慮 | C1 | 「管理已連結應用」文字量得 4.36:1（<4.5:1），背景是灰色提示卡；該卡看起來帶有按下／焦點外框，需確認是否為截圖當下的狀態 |
| `account-settings-appearance` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `account-settings-notifications` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `account-settings-profile` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `add-to-trip-direct` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `add-to-trip-invalid-favorite` | 淺深已看 | 疑慮 | G6、G7 | 錯誤只有一行灰字「收藏 ID 無效」，沒有圖示、重試或返回；底部分頁列仍顯示（同發現 5） |
| `add-to-trip-missing-data` | 淺深已看 | 疑慮 | G6、G7 | 同上：一行灰字，沒有下一步動作，底部分頁列仍顯示 |
| `app-lock-enable-prompt` | 淺深已看 | 張力 | F7 | App 內詢問是否開啟 Face ID，與 F7 建議有張力（同上）；alert 結構符合 G2、G3 |
| `app-lock-locked-ax-2x` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `app-lock-locked` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `auth-check-email` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全 |
| `auth-forgot-password` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全 |
| `auth-login-error` | 淺深已看 | 符合 | F3 | 沒有密碼欄（OAuth 瀏覽器登入）；錯誤有文字說明（G6）。深色為純黑底 |
| `auth-login` | 淺深已看 | 符合 | F3 | 沒有密碼欄（OAuth 瀏覽器登入）；錯誤有文字說明（G6）。深色為純黑底 |
| `auth-reset-password-expired` | 淺深已看 | 場景無效 | G6 | 畫面顯示「暫時無法處理，請稍後再試」，不是「連結已過期」：stub 丟的 error code 是 `expired`，畫面只認 `RESET_TOKEN_INVALID`／`RESET_TOKEN_MISSING`（account_flow_screens.dart:541-546）。此場景沒有證明過期畫面 |
| `auth-reset-password-success` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全 |
| `auth-reset-password` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全 |
| `auth-signup` | 淺深已看 | 疑慮 | F5 | 空表單、未勾同意時右上「建立」仍是可按的實心樣式；程式 `primaryActionEnabled: !_submitting`（account_flow_screens.dart:145）已確認 |
| `auth-verify-email-incomplete` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全 |
| `auth-verify-email-success` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全 |
| `auth-verify-email` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全 |
| `auth-welcome` | 淺深已看 | 符合 | F3 | 沒有密碼欄（OAuth 瀏覽器登入）；錯誤有文字說明（G6）。深色為純黑底 |
| `ax-account-appearance-2x` | 淺深已看 | 符合 | B2 | 2x 下選項不截斷，勾選清楚 |
| `ax-account-home-2x-bottom` | 淺深已看 | 符合 | B2 | 捲到底仍完整，登出與刪除帳號的紅色在深淺兩色都清楚 |
| `ax-account-home-2x` | 淺深已看 | 符合 | B2 | 長文換行、列高跟著長，沒有截斷，可捲動 |
| `ax-account-notifications-2x` | 淺深已看 | 符合 | B2 | 說明文字換行，開關仍在右側可點 |
| `ax-chat-2x` | 淺深已看 | 符合 | B2 | 建議按鈕折行不截斷，輸入列完整 |
| `ax-components-2x` | 淺深已看 | 未見明顯問題 | B2 | 分段控制在大字級改垂直堆疊（`tp_segmented_control.dart:106` 的刻意設計）；選中態只靠底色 |
| `ax-explore-2x` | 淺深已看 | 未見明顯問題 | B2 | 篩選膠囊橫向可捲，右側被截斷屬預期；卡片折行正常 |
| `ax-favorites-2x` | 淺深已看 | 場景無效 | — | 沒有餵收藏資料流（對照 `favorites` 場景有 `act`），只拍到載入骨架，沒證明 2x 的清單畫面 |
| `ax-invite-2x` | 淺深已看 | 符合 | B2 | 卡片與按鈕折行不截斷 |
| `ax-login-2x` | 淺深已看 | 符合 | B2 | 按鈕與連結置中完整 |
| `ax-public-share-2x` | 淺深已看 | 疑慮 | B2、版面 | 「登入後複製行程」折成兩行並剩孤字「程」，與兩個圖示鈕擠在同一列 |
| `ax-share-manage-2x` | 淺深已看 | 符合 | B2 | 分段控制堆疊、標籤欄位不截斷 |
| `ax-trip-create-2x` | 淺深已看 | 符合 | B2 | 日期欄位與分段控制堆疊，沒有截斷 |
| `ax-trip-map-2x` | 淺深已看 | 無法判讀 | — | 背景是測試用地圖 fixture，玻璃元件的對比與層次不能下結論；底部卡片文字折行正常 |
| `ax-trip-notes-2x` | 淺深已看 | 未見明顯問題 | B2 | 日期「星期日」折出孤字「日」，不影響閱讀 |
| `ax-trip-print-2x` | 淺深已看 | 符合 | B2 | 內容折行正常 |
| `ax-trip-timeline-2x` | 淺深已看 | 符合 | B2 | 時間軸與停留點卡片折行不截斷 |
| `ax-trips-list-2x` | 淺深已看 | 符合 | B2 | 分段控制堆疊；卡片高度跟著長 |
| `ax-trips-list-3x` | 淺深已看 | 未見明顯問題 | B2 | 標題折成兩行；底部分頁列蓋住最後一張卡（可捲動），標籤彼此貼近 |
| `ax-welcome-2x` | 淺深已看 | 符合 | B2 | 大標與內文折行、按鈕完整 |
| `chat-voice-consent` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `chat` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `collab-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `collab` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `components` | 淺深已看 | 未見明顯問題 | — | 元件示範頁；右上角 DEBUG 角標是 debug build 的標示，不是 App 問題 |
| `entry-add` | 淺深已看 | 疑慮 | D12 | modal 式表單（取消／儲存在頂部）底下仍顯示底部分頁列；取消在左、完成在右（D8）符合 |
| `entry-copy` | 淺深已看 | 疑慮 | D12 | modal 式表單（取消／儲存在頂部）底下仍顯示底部分頁列；取消在左、完成在右（D8）符合 |
| `entry-edit` | 淺深已看 | 疑慮 | D12 | modal 式表單（取消／儲存在頂部）底下仍顯示底部分頁列；取消在左、完成在右（D8）符合 |
| `entry-move` | 淺深已看 | 疑慮 | D12 | modal 式表單（取消／儲存在頂部）底下仍顯示底部分頁列；取消在左、完成在右（D8）符合 |
| `entry-pois` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `explore-empty-results` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `explore-search-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `explore` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `favorites-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `favorites` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `global-map-empty` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `global-map-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `global-map` | 淺深已看 | 無法判讀 | — | 背景是測試用地圖 fixture，不能當地圖畫面的證據 |
| `invite-load-failed` | 淺深已看 | 未見明顯問題 | G6 | 有重試與「暫不加入」；淺色橫幅是高彩度鮭紅，與深色的深紅風格落差大 |
| `invite-logged-out` | 淺深已看 | 符合 | F | 主要動作「註冊並加入」、次要「登入並加入」層級清楚 |
| `invite-signed-in` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `invite-wrong-account-pending` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `invite-wrong-account` | 淺深已看 | 符合 | G6 | 邀請帳號與目前帳號並列，動作是「切換帳號」 |
| `oauth-consent-invalid` | 淺深已看 | 疑慮 | D3 | 無返回鈕也無關閉鈕，只有頁內「返回行程列表」連結；標題靠左無導覽列（InvalidLinkScreen 固定提示頁） |
| `offline-banner-network` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `offline-banner-pending` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `public-share-signed-in` | 淺深已看 | 符合 | E | 登入後主動作文字改為「複製到我的行程」 |
| `public-share` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `share-create-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `share-created-card` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `share-custom-expiry-missing` | 淺深已看 | 符合 | F5、G | 就地錯誤「請選擇到期日」，建立鈕停用 |
| `share-list-load-failed` | 淺深已看 | 未見明顯問題 | G6 | 有就地錯誤與「重試」；錯誤文字約 12pt，偏小 |
| `share-manage` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-audit-empty` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-audit-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-audit` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-create` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-delete-confirm` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `trip-edit-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-edit` | 淺深已看 | 疑慮 | D10、G5 | 頂部說明「按『儲存』才會生效」，下方卻寫「日期平移與天數新增、刪除會立即生效，取消不會還原」；同一個有「取消」的表單混用兩種生效語意 |
| `trip-health-findings` | 淺深已看 | 疑慮 | 版面 | 第二張建議卡只有第一張一半寬，疑似版面缺陷（HIG 無對應條文） |
| `trip-health-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-health-not-run` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-map-route-failed` | 淺深已看 | 場景無效 | — | 淺、深色圖與 `trip-map` 的 SHA-1 完全相同，看不到路線失敗的提示；此場景沒有證明失敗畫面 |
| `trip-map` | 淺深已看 | 無法判讀 | C1 | 玻璃元件疊在「Google Map fixture」純色底上；量得 2.07～2.74:1，但真實地圖底色不同，不能作結論 |
| `trip-notes` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-print` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trip-timeline` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trips-list-empty` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trips-list-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `trips-list` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |

## 沒做的事

- B2 只做了目視：沒有量實際字級倍率，也沒檢查系統「更大字體」在真機上的上限（模擬器以 textScale 2.0、3.0 模擬）。
- 沒有量字級（B1）。對比與可點擊元素標籤另用 Flutter 內建 guideline 掃過，結果在[修改清單](2026-11-04-hig-fix-list.md)「補掃」一節，本表的「符合」「未見明顯問題」是**目視**結論，沒有被該補掃推翻或確認；兩者有出入處（例如分頁列選中標籤 4.39:1）以補掃為準。沒有檢查 Increase Contrast、Reduce Motion，也沒用 VoiceOver 實際走過。
- 目視判讀有主觀成分，上表「符合」是我看圖的結論，沒有第二人複核。
- 場景是 mock 資料與測試用地圖，真實畫面（含真實地圖、鍵盤、系統 alert）需真機驗證。
