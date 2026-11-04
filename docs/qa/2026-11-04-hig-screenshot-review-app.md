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
| 符合 | 16 |
| 未見明顯問題 | 40 |
| 疑慮 | 10 |
| 張力（與檢查表建議衝突，但屬已知專案決策） | 3 |
| 場景無效（截圖沒有證明想證明的畫面） | 2 |
| 無法判讀 | 1 |
| **未看** | **30** |

「未看」的 30 個：`ax-*` 共 20 個大字級場景、`components` 與 `global-map`，以及 `share-custom-expiry-missing`、`share-list-load-failed`、`invite-wrong-account`、`invite-logged-out`、`invite-load-failed`、`public-share-signed-in`、`add-to-trip-invalid-favorite`、`add-to-trip-missing-data`。**所以 B2（放大 200%）這一類完全沒有逐張檢查過。**「未見明顯問題」只代表目視沒看到，沒有量字級，也沒有逐一量對比。

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

第 2、3 項是**證據本身的缺陷**（場景沒有證明想證明的畫面），不是 App 缺陷。這兩個場景的守門（proof）只確認「畫面上有錯誤元素」，沒確認是想證明的那一種，需要修場景。

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
| `add-to-trip-invalid-favorite` | 未看 | — | — | 本輪未逐張檢視 |
| `add-to-trip-missing-data` | 未看 | — | — | 本輪未逐張檢視 |
| `app-lock-enable-prompt` | 淺深已看 | 張力 | F7 | App 內詢問是否開啟 Face ID，與 F7 建議有張力（同上）；alert 結構符合 G2、G3 |
| `app-lock-locked-ax-2x` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `app-lock-locked` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `auth-check-email` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全
| `auth-forgot-password` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全
| `auth-login-error` | 淺深已看 | 符合 | F3 | 沒有密碼欄（OAuth 瀏覽器登入）；錯誤有文字說明（G6）。深色為純黑底 |
| `auth-login` | 淺深已看 | 符合 | F3 | 沒有密碼欄（OAuth 瀏覽器登入）；錯誤有文字說明（G6）。深色為純黑底 |
| `auth-reset-password-expired` | 淺深已看 | 場景無效 | G6 | 畫面顯示「暫時無法處理，請稍後再試」，不是「連結已過期」：stub 丟的 error code 是 `expired`，畫面只認 `RESET_TOKEN_INVALID`／`RESET_TOKEN_MISSING`（account_flow_screens.dart:541-546）。此場景沒有證明過期畫面 |
| `auth-reset-password-success` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全
| `auth-reset-password` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全
| `auth-signup` | 淺深已看 | 疑慮 | F5 | 空表單、未勾同意時右上「建立」仍是可按的實心樣式；程式 `primaryActionEnabled: !_submitting`（account_flow_screens.dart:145）已確認 |
| `auth-verify-email-incomplete` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全
| `auth-verify-email-success` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全
| `auth-verify-email` | 淺深已看 | 符合 | D3、D4 | 返回用標準符號、單一 prominent 動作在右上；文字說明齊全
| `auth-welcome` | 淺深已看 | 符合 | F3 | 沒有密碼欄（OAuth 瀏覽器登入）；錯誤有文字說明（G6）。深色為純黑底 |
| `ax-account-appearance-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-account-home-2x-bottom` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-account-home-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-account-notifications-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-chat-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-components-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-explore-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-favorites-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-invite-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-login-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-public-share-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-share-manage-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-trip-create-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-trip-map-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-trip-notes-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-trip-print-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-trip-timeline-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-trips-list-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-trips-list-3x` | 未看 | — | — | 本輪未逐張檢視 |
| `ax-welcome-2x` | 未看 | — | — | 本輪未逐張檢視 |
| `chat-voice-consent` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `chat` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `collab-load-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `collab` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `components` | 未看 | — | — | 本輪未逐張檢視 |
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
| `global-map` | 未看 | — | — | 本輪未逐張檢視 |
| `invite-load-failed` | 未看 | — | — | 本輪未逐張檢視 |
| `invite-logged-out` | 未看 | — | — | 本輪未逐張檢視 |
| `invite-signed-in` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `invite-wrong-account-pending` | 淺深已看 | 符合 | G2、G3、G4 | alert／action sheet 結構、取消在 leading、破壞性動作用紅字，目視符合 |
| `invite-wrong-account` | 未看 | — | — | 本輪未逐張檢視 |
| `oauth-consent-invalid` | 淺深已看 | 疑慮 | D3 | 無返回鈕也無關閉鈕，只有頁內「返回行程列表」連結；標題靠左無導覽列（InvalidLinkScreen 固定提示頁） |
| `offline-banner-network` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `offline-banner-pending` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `public-share-signed-in` | 未看 | — | — | 本輪未逐張檢視 |
| `public-share` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `share-create-failed` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `share-created-card` | 淺深已看 | 未見明顯問題 | — | 目視未發現與檢查表衝突之處；僅看圖，未量字級與對比 |
| `share-custom-expiry-missing` | 未看 | — | — | 本輪未逐張檢視 |
| `share-list-load-failed` | 未看 | — | — | 本輪未逐張檢視 |
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

- 30 個場景沒看；B2 大字級整類沒檢查。
- 沒有量字級（B1）、沒有逐一量對比（C1、C2 只量了上面幾處）、沒有檢查 Increase Contrast、Reduce Motion、VoiceOver 標籤。
- 目視判讀有主觀成分，上表「符合」是我看圖的結論，沒有第二人複核。
- 場景是 mock 資料與測試用地圖，真實畫面（含真實地圖、鍵盤、系統 alert）需真機驗證。
