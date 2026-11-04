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
| `/edit-trip/:tripId` | EditTripScreen | 已有場景 | `trip-edit` `trip-edit-load-failed` |
| `/collab/:tripId` | CollabScreen | 已有場景 | `collab` `collab-load-failed` |
| `/share-trip/:tripId` | ShareScreen | 已有場景 | `share-manage` `share-custom-expiry-missing` `share-created-card` `share-create-failed` `share-list-load-failed` `ax-share-manage-2x` |
| `/oauth/consent` | InvalidLinkScreen（固定提示文字） | 已有場景 | `oauth-consent-invalid` |
| `/invite` | InviteScreen | 已有場景 | `invite-signed-in` `invite-wrong-account` `invite-wrong-account-pending` `invite-load-failed` `invite-logged-out` `ax-invite-2x` |
| `/s/:token` | PublicShareScreen | 已有場景 | `public-share` `public-share-signed-in` `ax-public-share-2x` |
| `/chat` | ChatScreen | 已有場景 | `chat` `ax-chat-2x` |
| `/trips` | TripsListScreen | 已有場景 | `trips-list` `trips-list-load-failed` `trips-list-empty` `offline-banner-network` `offline-banner-pending` `ax-trips-list-2x` `ax-trips-list-3x` |
| `:tripId` | TripTimelineScreen | 已有場景 | `trip-timeline` `ax-trip-timeline-2x` |
| `map` | 行程地圖（TripMap） | 已有場景 | `trip-map` `trip-map-route-failed` `ax-trip-map-2x` |
| `notes` | TripNotesScreen | 已有場景 | `trip-notes` `ax-trip-notes-2x` |
| `print` | TripPrintScreen | 已有場景 | `trip-print` `ax-trip-print-2x` |
| `health` | TripHealthScreen | 已有場景 | `trip-health-not-run` `trip-health-findings` `trip-health-load-failed` |
| `audit` | TripAuditScreen | 已有場景 | `trip-audit` `trip-audit-empty` `trip-audit-load-failed` |
| `entries/new` | EntryAddRouteScreen | 已有場景 | `entry-add` |
| `entries/:eid/edit` | EntryEditRouteScreen | 已有場景 | `entry-edit` |
| `entries/:eid/copy` | EntryActionRouteScreen | 已有場景 | `entry-copy` |
| `entries/:eid/move` | EntryActionRouteScreen | 已有場景 | `entry-move` |
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
| `showAppConfirm` | 聊天、帳號、通知設定、停留點異動 | 部分 | `chat-voice-consent`（只覆蓋聊天語音） |
| `showAppDestructiveConfirm` | 登出、收藏、筆記、行程、停留點、開發者 App、已連結 App、登入裝置 | 部分 | `account-logout-confirm` `account-connected-app-revoke-confirm` `trip-delete-confirm`（只覆蓋三處；從選單觸發的是 action sheet，不是 alert） `favorites-remove-confirm`（收藏移除，direct 來源，確認走 alert）|
| `showAppAlert` | 加入行程、帳號 | 部分 | `account-delete-preview-failed`（只覆蓋帳號；加入行程的衝突 alert 仍無場景） |
| `showAppActionSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppSelectionSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppContentSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppScreenSheet` | 畫面沒有直接呼叫（只有 helper 之間互相使用） | 已排除（沒有使用） | 無 |
| `showAppFormSheet` | 聊天 AI 同意、收藏、探索、停留點 POI、筆記編輯、交通編輯、衝突解決、分享、停留點編輯 | 部分 | `note-edit-sheet` `favorites-filter-sheet`（筆記與收藏篩選；聊天 AI 同意、探索、停留點 POI、交通編輯、衝突解決、分享、停留點編輯仍無場景） |
| `showAppNotice` | 幾乎所有可操作的畫面（Snackbar／提示） | 部分 | `favorites-removed-notice`（只覆蓋收藏移除成功；其餘畫面的通知仍無場景） |
| `confirmAndRunIrreversibleAction` | 協作、分享 | **缺口** | 無 |
| `confirmAndDelete` | 停留點 POI、時間軸、筆記 | **缺口** | 無 |
| `showCupertinoDialog`（直接呼叫，帳號畫面） | 刪除帳號確認 | 已有場景 | `account-delete-dialog` |
| `showCupertinoDialog`（直接呼叫，生物辨識登入列） | 開啟生物辨識確認 | **缺口** | 無 |

## 三、缺口摘要

- 路由缺口 0 個，另有 1 個部分（#534～#536 補了 15 個）：`:favoriteId/add-to-trip` 只有無效 ID 狀態（正常載入狀態沒有場景）；另加上變更密碼（PR #530，尚未進 master）。
- 彈出層缺口：幾乎全部。目前只有帳號刪除、登出確認、解除連結確認、刪除行程確認、聊天語音同意取得場景（App 鎖開啟提示是全螢幕狀態，不算彈出層）。這是補場景時優先度最高的一塊，因為 HIG 對 alert、action sheet、picker 的規定集中在這裡。
- 已排除的 4 個 helper 沒有呼叫端；若之後有人開始使用，守門測試會逼著更新這份清單。
- 後續取證票補場景時，把狀態從「**缺口**」改成「已有場景」並填上場景名稱，守門測試會檢查場景名稱真的存在。
