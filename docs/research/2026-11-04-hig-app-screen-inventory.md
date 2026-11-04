# App 畫面完整清單與 mock 場景對照（#533，屬 #531）

HIG 取證的驗收依據：App 的每個路由與彈出層，各對到哪個 mock 場景；沒有場景的明列為缺口。
檢查項目見 [HIG 檢查表](2026-11-04-hig-screen-checklist.md)。

- 場景來源：`integration_test/support/hig_screenshot_scenes.dart` 的 `higScenes()`，全部用 mock repository，不碰 prod。
- 「已有場景」只代表**能取得模擬畫面並被量測**（目前量到的是觸控目標，見 `test/flows/hig_scene_guidelines_test.dart`），**不代表已通過 HIG 判讀**。判讀結果由 #534～#537 與 #538 之後的彙整報告負責。
- 本清單由 `test/docs/hig_screen_inventory_test.dart` 守門：路由表新增路徑、新增彈出層 helper、新增場景，卻沒登記在這裡，測試會紅。

## 一、路由

路徑照 `lib/app/router.dart` 的 `path:` 字面值（子路由只寫該層的寫法）。

| 路由 | 畫面 | 狀態 | 場景 |
|---|---|---|---|
| `/login` | LoginScreen | 已有場景 | `auth-login` `auth-login-error` `ax-login-2x` |
| `/welcome` | WelcomeScreen | 已有場景 | `auth-welcome` `ax-welcome-2x` |
| `/signup` | SignupScreen | 已有場景 | `auth-signup` |
| `/signup/check-email` | EmailVerifyPendingScreen | 已有場景 | `auth-check-email` |
| `/login/forgot` | ForgotPasswordScreen | 已有場景 | `auth-forgot-password` |
| `/auth/password/reset` | ResetPasswordScreen | 已有場景 | `auth-reset-password` `auth-reset-password-success` `auth-reset-password-expired` |
| `/auth/verify-email` | VerifyEmailScreen | 已有場景 | `auth-verify-email` `auth-verify-email-success` `auth-verify-email-incomplete` |
| `/new-trip` | CreateTripScreen | 已有場景 | `trip-create` `ax-trip-create-2x` |
| `/edit-trip/:tripId` | EditTripScreen | 已有場景 | `trip-edit` `trip-edit-save-failed` `trip-edit-finish-blocked-confirm` `trip-edit-load-failed` |
| `/collab/:tripId` | CollabScreen | 已有場景 | `collab` `collab-load-failed` `collab-remove-member-confirm` `collab-revoke-invite-confirm` |
| `/share-trip/:tripId` | ShareScreen | 已有場景 | `share-manage` `share-custom-expiry-missing` `share-created-card` `share-create-failed` `share-list-load-failed` `share-revoke-confirm` `ax-share-manage-2x` |
| `/oauth/consent` | InvalidLinkScreen（固定提示文字） | 已有場景 | `oauth-consent-invalid` |
| `/invite` | InviteScreen | 已有場景 | `invite-signed-in` `invite-wrong-account` `invite-wrong-account-pending` `invite-load-failed` `invite-logged-out` `ax-invite-2x` |
| `/s/:token` | PublicShareScreen | 已有場景 | `public-share` `public-share-signed-in` `ax-public-share-2x` |
| `/chat` | ChatScreen | 已有場景 | `chat` `ax-chat-2x` |
| `/trips` | TripsListScreen | 已有場景 | `trips-list` `trips-list-load-failed` `trips-list-empty` `offline-banner-network` `offline-banner-pending` `ax-trips-list-2x` `ax-trips-list-3x` |
| `:tripId` | TripTimelineScreen | 已有場景 | `trip-timeline` `timeline-delete-entry-confirm` `ax-trip-timeline-2x` |
| `map` | 行程地圖（TripMap） | 已有場景 | `trip-map` `trip-map-route-failed` `ax-trip-map-2x` |
| `notes` | TripNotesScreen | 已有場景 | `trip-notes` `ax-trip-notes-2x` |
| `print` | TripPrintScreen | 已有場景 | `trip-print` `ax-trip-print-2x` |
| `health` | TripHealthScreen | 已有場景 | `trip-health-not-run` `trip-health-findings` `trip-health-load-failed` |
| `audit` | TripAuditScreen | 已有場景 | `trip-audit` `trip-audit-empty` `trip-audit-load-failed` |
| `/trips/:tripId/entries/new`（shell 外整頁 modal） | EntryAddRouteScreen | 已有場景 | `entry-add` |
| `/trips/:tripId/entries/:eid/edit`（shell 外整頁 modal） | EntryEditRouteScreen | 已有場景 | `entry-edit` |
| `/trips/:tripId/entries/:eid/copy`（shell 外整頁 modal） | EntryActionRouteScreen | 已有場景 | `entry-copy` |
| `/trips/:tripId/entries/:eid/move`（shell 外整頁 modal） | EntryActionRouteScreen | 已有場景 | `entry-move` |
| `entries/:eid/pois` | EntryPoiScreen | 已有場景 | `entry-pois` |
| `/map` | GlobalMapScreen | 已有場景 | `global-map` `global-map-empty` `global-map-load-failed` |
| `/favorites` | FavoritesScreen | 已有場景 | `favorites` `favorites-load-failed` `ax-favorites-2x` |
| `explore` | ExploreScreen | 已有場景 | `explore` `explore-empty-results` `explore-search-failed` `ax-explore-2x` |
| `:favoriteId/add-to-trip` | AddToTripRouteScreen | 部分 | `add-to-trip-invalid-favorite`（只有無效 ID 狀態；正常載入狀態沒有場景） |
| `add-to-trip` | AddToTripRouteScreen | 已有場景 | `add-to-trip-direct` `add-to-trip-missing-data` |

### 帳號畫面（不是獨立路由）

帳號是 `/trips?account=…` 疊在行程清單上的全頁面，由 AccountScreen 內部切換，所以不在 `router.dart`，但仍是完整畫面。

| 區段 | 狀態 | 場景 |
|---|---|---|
| 首頁 | 已有場景 | `account-home` `account-home-security` `ax-account-home-2x` `ax-account-home-2x-bottom` |
| 登入裝置 | 已有場景 | `account-sessions` `account-sessions-load-failed` |
| 已連結的 App | 已有場景 | `account-connected-apps` |
| 開發者 App | 已有場景 | `account-developer-apps` |
| 新增開發者 App | 已有場景 | `account-developer-app-new` |
| 外觀 | 已有場景 | `account-settings-appearance` `ax-account-appearance-2x` |
| 個人資料 | 已有場景 | `account-settings-profile` |
| 通知 | 已有場景 | `account-settings-notifications` `ax-account-notifications-2x` |
| 變更密碼 | **缺口**（畫面在 PR #530，尚未進 master） | 無 |

### 啟動時的全螢幕狀態

| 畫面 | 狀態 | 場景 |
|---|---|---|
| App 鎖（鎖定畫面） | 已有場景 | `app-lock-locked` `app-lock-locked-ax-2x` |
| App 鎖（開啟提示） | 已有場景 | `app-lock-enable-prompt` |

## 二、彈出層（sheet／dialog／picker）

彈出層幾乎都經過 `lib/app/adaptive.dart` 與 `lib/app/irreversible_action.dart` 的 helper，另有兩處直接呼叫 `showCupertinoDialog`（列在表尾）。「呼叫畫面」是呼叫該 helper 的檔案所屬功能。

| helper | 呼叫畫面 | 狀態 | 場景 |
|---|---|---|---|
| `showAppDatePicker` | 建立／編輯行程、分享、筆記編輯 | 部分 | `create-trip-date-picker` `note-edit-date-picker`（建立行程與筆記；編輯行程、分享仍無場景） |
| `showAppTimePicker` | 筆記編輯 | 已有場景 | `note-edit-time-picker` |
| `showAppConfirm` | 聊天、帳號、通知設定、停留點異動 | 部分 | `chat-voice-consent`（只覆蓋聊天語音同意；聊天「無法使用語音輸入」、帳號「需要重新驗證才能刪除」、通知設定「允許通知」、停留點備選「設為正選？」四處仍無場景） |
| `showAppDestructiveConfirm` | 登出、收藏、筆記、行程、停留點、開發者 App、已連結 App、登入裝置 | 部分 | `account-logout-confirm` `account-connected-app-revoke-confirm` `trip-delete-confirm` `share-revoke-confirm` `collab-remove-member-confirm` `timeline-delete-entry-confirm` `account-session-revoke-confirm` `developer-app-delete-confirm` `trip-edit-delete-day-confirm`（編輯行程的刪除行程日；選單觸發的是 action sheet；詳情頁與編輯頁上的直接按鈕走 alert；停留點、筆記、交通的『保留你的版本？』覆寫確認已由 #559／#561 補 `entry-edit-overwrite-confirm` `note-edit-overwrite-confirm` `travel-edit-overwrite-confirm`） `favorites-remove-confirm`（收藏移除，direct 來源，確認走 alert）`trip-edit-finish-blocked-confirm`（編輯行程「有變更尚未送出」的完成攔截框，重試／放棄）（仍無場景：收藏多選的批次移除）|
| `showAppAlert` | 加入行程、帳號 | 已有場景（兩處呼叫端都有） | `account-delete-preview-failed` `add-to-trip-time-conflict-alert`（帳號與加入行程時段衝突） |
| `showAppActionSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppSelectionSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppContentSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppScreenSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppFormSheet` | 聊天 AI 同意、收藏、探索、停留點 POI、筆記編輯、交通編輯、衝突解決、分享、停留點編輯 | 已有場景（九處呼叫端都有） | `note-edit-sheet` `favorites-filter-sheet` `chat-ai-consent-sheet` `explore-custom-region-sheet` `poi-info-edit-sheet` `travel-edit-sheet` `share-edit-sheet` `entry-edit-sheet` `sync-conflict-sheet` `sync-conflict-sheet-many`（衝突解決 sheet 已有場景）`entry-edit-sheet-remote-conflict`（停留點遠端衝突狀態） |
| `showAppNotice` | 幾乎所有可操作的畫面（Snackbar／提示） | 部分 | `favorites-removed-notice`（只覆蓋收藏移除成功；其餘畫面的通知仍無場景） |
| `confirmAndRunIrreversibleAction` | 協作、分享 | 部分 | `share-revoke-confirm` `collab-remove-member-confirm` `collab-revoke-invite-confirm`（重新產生、刪除分享連結同一支元件，未各拍一張） |
| `confirmAndDelete` | 停留點 POI、時間軸、筆記 | 已有場景 | `timeline-delete-entry-confirm` `note-delete-confirm` `entry-alternate-remove-confirm` |
| `showCupertinoDialog`（直接呼叫，帳號畫面） | 刪除帳號確認 | 已有場景 | `account-delete-dialog` |
| `showCupertinoDialog`（直接呼叫，生物辨識登入列） | 關閉生物辨識確認 | 已有場景 | `account-biometric-disable-confirm`（原清單寫成「開啟」確認；程式碼只有「關閉並登出」這一個確認，已更正） |

## 三、缺口摘要

- 路由缺口 0 個，另有 1 個部分（#534～#536 補了 15 個）：`:favoriteId/add-to-trip` 只有無效 ID 狀態（正常載入狀態沒有場景）；另加上變更密碼（PR #530，尚未進 master）。
- 彈出層：#531 補了 23 個，#558～#561 再補 8 個（衝突解決 sheet 兩個、加入行程時段衝突 alert、刪除行程日確認〔原稱編輯行程放棄確認〕、三處『保留你的版本？』覆寫確認、停留點遠端衝突狀態），另有編輯行程的完成攔截框 1 個，共 32 個。`showAppFormSheet`、`showAppAlert` 的呼叫端已全數有場景。仍標「部分」的是 spec #557 範圍外的呼叫端：日期選擇器（編輯行程、分享）、`showAppConfirm` 四處、`showAppDestructiveConfirm` 一處（收藏批次移除；編輯行程的完成攔截框已有 `trip-edit-finish-blocked-confirm`）、`confirmAndRunIrreversibleAction`（重新產生、刪除分享連結）、`showAppNotice`（其餘畫面）。這些場景用測試替身造狀態的限制見缺口文件第 1 節。App 鎖開啟提示是全螢幕狀態，不算彈出層。
- 已排除的 4 個 helper 沒有呼叫端；若之後有人開始使用，守門測試會逼著更新這份清單。
- 後續取證票補場景時，把狀態從「**缺口**」改成「已有場景」並填上場景名稱，守門測試會檢查場景名稱真的存在。
