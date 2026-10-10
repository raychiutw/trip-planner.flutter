# HIG 修補（#415–#430）擷圖驗證

基底 `integ/hig-all`（PR #441）。iOS 模擬器 `tripline-qa`（iOS 27，Debug build，393x852 pt @3x），
整合測試 `integration_test/hig_screenshots_test.dart` 產生，全程走 mock repository，不碰 prod、不用鍵盤輸入。

重跑：

```bash
flutter test integration_test/hig_screenshots_test.dart -d <UDID> \
  --dart-define=HIG_SHOT_DIR=$PWD/docs/qa/2026-10-hig-screenshots
# 只跑單一情境：--dart-define=HIG_ONLY=<情境名稱子字串>
```

## 範圍與證據

- 56 個畫面 × 淺／深 = 112 張 PNG（`light/`、`dark/`，檔名即情境名稱）。為了控制 repo 體積（原圖 34MB）
  已縮成 603x1311（原 1206x2622）。
- 深淺只走 App 的 `themeModeProvider`（`ThemeModeController(initialMode:)`），不靠 `simctl ui appearance`。
- 深淺確實不同：測試內對每個畫面解碼兩張圖，要求「bytes 不同、取樣像素差異 ≥ 5%、深色平均亮度低於淺色」，
  任一不成立測試就失敗。結果見 `report.tsv`：全部 56 組 bytes 皆不同、像素差異 96.7%–100%、
  平均亮度淺色 195–253 對深色 2.6–48。
- 同一支測試也會在淺色內抓出「兩個情境其實是同一畫面」：`trip-create-validation` 與 `trip-create` 位元組
  完全相同（送出鈕停用，點了沒反應），已刪掉該情境。
- 注意 `components`／`ax-components-2x` 是獨立 `MaterialApp` 展示頁，右上角會有 DEBUG 角標，並非產品畫面。

## 我實際用眼睛看過的畫面（其餘僅靠上面的機器比對與預期文字，沒有逐張檢視）

| 畫面 | 票 | 結論 |
|---|---|---|
| `invite-wrong-account` | #415 | 已修好。帳號不符時並列「邀請帳號／目前帳號」，主按鈕「切換帳號」，淺色無問題。 |
| `invite-wrong-account-pending`（深色） | #415 | 已修好。待同步佇列有 3 筆時，切換帳號先跳「還有 3 筆變更尚未同步，登出後會遺失」確認，深色對比正常。 |
| `share-custom-expiry-missing` | #416 | 已修好。選「自訂」未選日期時，建立鈕停用，並顯示「請選擇到期日」。小缺陷：提示文字用一般 onSurface 色、字小，沒有任何警示色或圖示，視覺上不像錯誤。 |
| `share-created-card`（深色） | #416 #430 | 結果卡可見（連結、顯示 QR、分享、複製）。仍有缺陷：卡片下緣與下方「使用中的連結（0）」標題之間沒有間距，標題貼著卡片。 |
| `trip-edit-load-failed`（深色） | #417 | 已修好。顯示「無法載入行程／請檢查網路後再試一次。／重試」，不再是可儲存的空表單。 |
| `explore-empty-results`（深色） | #418 | 已修好（有空結果文案）。小缺陷：訊息寫「沒有找到『東京』的結果」，但搜尋框是空的（預設自動搜尋「東京」，欄位沒回填）。 |
| `auth-login-error` | #420 | 已修好。錯誤文案改成人話「登入失敗，請稍後再試」，深字在淡紅底，對比足夠。 |
| `ax-trips-list-3x`（3.0x） | #422 | 仍有缺陷：大標題「我的行程」被截成只剩上半（「我的」被切），分段控制「共編」貼齊右緣，疑似被截。卡片標題改為換行，沒有溢出。 |
| `ax-share-manage-2x`（2.0x） | #422 #416 | 部分修好。標籤輸入框 placeholder 被截成「標籤（選填,如「給爸…」；有效期限分段控制只露出「永久／24 小時／7 天」，「30 天／自訂」被切掉且沒有任何可捲動提示（實作是橫向捲動）。Chip 有換行，沒有溢出。 |
| `ax-account-home-2x`（2.0x） | #422 #425 | 已修好。列表項目在 2x 下完整、沒有截斷；個人資料列副標題換行。 |
| `components` 淺深 | #426 | TpChip、TpSegmentedControl、TpPickerField 深色皆正常（選取、停用態都看得出差異）。 |
| `trip-timeline`（深色） | #421 #423 | 深色適配正常，卡片、時間、tab bar 對比足夠。 |
| `trips-list-load-failed`（淺色） | #418 | 看不出來：畫面停在載入轉圈，沒有看到錯誤態。原因是 `myTripsRetryProvider` 會先自動重試（有退避），我的 8 秒等待內還沒進入錯誤頁。 |
| `account-sessions-load-failed`（淺色） | #425 #418 | 看不出來：同樣停在 skeleton，未等到錯誤態（同上，自動重試）。 |

## 情境與票對照（未逐張檢視者，僅確認有產出與深淺差異）

`auth-welcome`／`auth-signup`／`auth-forgot-password`（#423 #424 #428）、`trips-list`／`trips-list-empty`（#418 #426 #427）、
`trip-create`（#424 #426）、`trip-edit`（#417 #424）、`trip-map`（#418）、`trip-notes`（#419 #422）、`trip-print`（#419）、
`favorites`／`favorites-load-failed`／`explore`／`explore-search-failed`（#418 #426）、`chat`（#429）、
`account-home`／`account-sessions`／`account-connected-apps`／`account-developer-apps`／`account-developer-app-new`／
`account-settings-*`／`account-delete-dialog`（#424 #425 #426）、`invite-*`（#415）、`share-manage`／`share-create-failed`／
`share-list-load-failed`（#416 #430）、`public-share`／`public-share-signed-in`（#428）、
`offline-banner-network`／`offline-banner-pending`（#415 #419）、`ax-*`（#422 #423）。

## 沒做到／做不到

- `trip-map-route-failed`：與 `trip-map` 位元組完全相同。Fixture 用假地圖 canvas，路線抓取沒有被觸發，所以
  #418「地圖路線失敗」這個狀態在此環境拍不到，需要真地圖或補觸發路徑。
- 載入失敗類（`trips-list-load-failed`、`account-sessions-load-failed`、`share-list-load-failed` 等）因自動重試退避，
  可能只拍到載入中；`share-create-failed` 與 `share-list-load-failed` 的像素亮度完全相同，疑似未進入各自的失敗態，
  結論是「看不出來」。
- 地圖畫面是假 canvas（純色底），真實地圖疊圖不在此驗證範圍。
- iPad、橫向、真機、VoiceOver／系統 Dynamic Type 都沒測；AX 字級是以 MediaQuery 注入 textScaler。
- Debug build，非 release；效能與玻璃材質在 release 可能略有差異。
