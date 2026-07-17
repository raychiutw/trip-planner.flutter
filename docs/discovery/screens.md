# Tripline React SPA — 畫面與導航結構調查（Flutter 移植用）

> 這是 Web 來源調查快照，不是目前 Flutter UI 規格。Flutter 最終導覽、色彩與互動以 [`design.md`](design.md) 為準；其中 Web 的 5-tab、帳號 tab 與三色卡片均不可直接沿用。

入口：`src/entries/main.tsx`（非 src/main.tsx）。`BrowserRouter` + lazy route，外層 Provider：`ErrorBoundary > ActiveTripProvider > NewTripProvider`。`TripLayout`（`src/pages/TripLayout.tsx`）只是 thin wrapper：`useParams.tripId → useTrip() → TripContext.Provider > <Outlet/>`，讓所有 `/trip/:tripId/*` 子路由共用同一份 trip+days fetch — Flutter 對應「per-trip scoped state（Provider/Riverpod scope）」。

## 1. Route 表（src/entries/main.tsx）

### 頂層 route

| Route | Component | 備註 |
|---|---|---|
| `/trips` | `TripsListPage` | **核心**；`?selected=X` 時內嵌 `TripPage` 滿版（mobile 詳情頁就是這條） |
| `/trips/new` | `NewTripPage` | 建立行程全頁 form |
| `/chat` | `ChatPage` | AI 聊天改行程（tab 1） |
| `/map` | `GlobalMapPage` | 全域地圖（tab 3） |
| `/explore` | `ExplorePage` | POI 探索（secondary，從收藏進） |
| `/favorites` | `PoiFavoritesPage` | 收藏（tab 4 primary） |
| `/favorites/:id/add-to-trip`、`/add-to-trip` | `AddPoiFavoriteToTripPage` | 收藏/Explore POI → 加入行程 fast-path |
| `/login`、`/signup`、`/signup/check-email`、`/login/forgot`、`/auth/password/reset`、`/auth/verify-email` | `LoginPage`/`SignupPage`/`EmailVerifyPendingPage`/`ForgotPasswordPage`/`ResetPasswordPage`/`VerifyEmailPage` | Auth 流程 |
| `/account` | `AccountPage` | 帳號 hub（tab 5） |
| `/account/appearance`、`/account/notifications` | `AppearanceSettingsPage`/`NotificationsSettingsPage` | （`/settings/*` 同名 alias 並存） |
| `/settings/sessions`、`/settings/connected-apps` | `SessionsPage`/`ConnectedAppsPage` | （`/account/*` alias 並存） |
| `/developer/apps`、`/developer/apps/new` | `DeveloperAppsPage`/`DeveloperAppNewPage` | OAuth dev |
| `/oauth/consent` | `ConsentPage` | OAuth 授權 |
| `/invite` | `InvitePage` | 共編邀請 landing |
| `/s/:token` | `TripSharePage` | **無登入**公開分享頁 |
| `/admin` `/manage` `*` | redirect | → `/trips`、`/chat`、LegacyRedirect（`?trip=` 相容） |

### `/trip/:tripId` 巢狀（TripLayout 之下，共用 TripContext）

| 子 route | Component | 備註 |
|---|---|---|
| （index） | `TripIndexRedirect` | → `/trips?selected=:id`（統一 URL） |
| `map` | `MapPage` | 全螢幕行程地圖 |
| `stop/:entryId/map` | `MapPage` | focus 單一 entry |
| `stop/:entryId` | `StopDetailRedirect` | → `/trips?selected=:id&focus=:eid` |
| `notes` | `TripNotesPage` | 行程筆記 |
| `collab` | `CollabPage` | 共編設定 |
| `health` | `TripHealthCheckPage` | AI 健檢 |
| `print` | `TripPrintPage` | 列印文件 |
| `edit` | `EditTripPage` | 編輯行程 meta |
| `add-entry` / `add-stop` / `add-custom-stop` | `AddEntryPage`/`AddStopPage`/`AddCustomStopPage` | 新增景點 wizard / bulk / 自訂（mobile-only） |
| `stop/:entryId/edit` / `change-poi` / `copy` / `move` | `EditEntryPage`/`ChangePoiPage`/`EntryActionPage` | Entry CRUD 全頁 form（已全面 modal→fullpage） |

## 2. Mobile 5-tab 導航（`src/components/shell/GlobalBottomNav.tsx`）

Sticky bottom、64px、5 等分 grid、毛玻璃背景；active = accent 色 + accent-subtle 底 + 頂部 32×2px indicator；label 11px/700。

| # | Tab | Icon | Route | Active 額外規則 |
|---|---|---|---|---|
| 1 | 聊天 | `chat` | `/chat` | — |
| 2 | 行程 | `home` | `/trips` | `/trip/:id` 全部非地圖子路由 |
| 3 | 地圖 | `map` | `/map`（exact） | `/trip/:id/map`、`/trip/:id/stop/:eid/map` |
| 4 | 收藏 | `heart` | `/favorites` | `/explore`、`/favorites/*` |
| 5 | 帳號（已登入）/ 登入（匿名） | `user` | `/account`（含 `/settings`）/ `/login` | — |

Flutter 對應：`go_router` ShellRoute + `BottomNavigationBar`；trip 詳情在 mobile 是「行程 tab 內 push 的 detail screen」（web 用 `?selected=` 模擬）。

## 3. P0 頁面區塊描述

### TripsListPage（/trips，1336 行）
- **Layout**：AppShell（desktop 3-pane：sidebar｜card grid｜sheet portal；mobile 單欄）+ GlobalBottomNav。
- **區塊**：TitleBar「我的行程」（匯入 + 新增行程 action）→ toolbar（分類 tabs：全部/我的/共編/已歸檔 含 count；排序 pill select：最新編輯/出發日近/名稱；展開式搜尋）→ trip card grid（mobile 2 欄、desktop auto-fill 240px；card = 漸層 cover + eyebrow（國家·天數）+ title + owner avatar/meta；kebab `TripCardMenu`：共編/編輯/健檢/筆記/分享/刪除）+ 尾端「+ 新增行程」card → empty hero / filtered-empty。刪除走 ConfirmModal，分享走 ShareLinkModal。
- **互動**：card click → `?selected=X` → 內嵌 TripPage 滿版，TitleBar 換成（back、新增景點→`/add-entry`、切換行程 dropdown、⋯ EmbeddedActionMenu：編輯/共編/健檢/筆記/列印/分享/下載）。
- **資料**：`GET /api/my-trips` + `GET /api/trips?all=1`、`DELETE /trips/:id`；hooks：`useRequireAuth`、`useCurrentUser`、`useMediaQuery`、`useActiveTrip`。

### TripPage（時間軸，837 行；永遠 embedded `noShell` 模式）
- **區塊**：離線 AlertPanel banner → `DayNav`（sticky day pill，含今天 marker）→ 逐日 `DaySection`（day header + 天氣 `HourlyWeather` + `Timeline`/`TimelineEvent` + 站間 `TravelPill` 移動方式）→ FooterArt。Loading 用 `DaySkeleton`。
- **互動**：scroll-spy（捲動同步 active day pill + `#dayN` hash）、初載自動捲到今天（行程時區感知）、`?focus=:entryId` 捲到指定 entry、`?sheet=collab` deeplink；desktop 右側 `TripSheet`（lazy 地圖 rail，portal 進 AppShell）；imperative handle 開放下載 PDF/JSON、列印、openAddStop 給父層選單。
- **資料**：`useTrip(tripId)` → `GET /trips/:id` + `GET /trips/:id/days?all=1`、單日 refetch `/trips/:id/days/:n`；`useTripSegments` → `/trips/:id/segments`；contexts：`TripIdContext`/`TripDaysContext`/`TripSegmentsContext`；localStorage trip 偏好 + 離線快取。

### MapPage（/trip/:id/map，563 行）
- **結構**（上到下）：TitleBar（trip 名 + back + 切換行程 dropdown）→ 地圖本體 `TpMap`（Google Maps，lazy；overview = fitBounds + 逐日色 polyline，單日 = flyTo active entry）+ `MapFabs`（圖層切換/我的位置）→ day tabs 橫向 snap-scroll（「總覽·N天」+ DAY NN·日期，逐日色）→ entry cards 橫向 snap-scroll（D{N} 前綴 + 時間 + 標題）。
- **互動**：card 捲動 ⇆ 地圖 focus 雙向同步（IntersectionObserver）；點 pin/card → 居中 + overview 模式自動切該日 tab；`?day=N|all`、`stop/:eid/map` deep link。
- **資料**：來自 TripLayout 共用 `TripContext`（不重抓）；`extractPinsFromDay/AllDays` 萃取 pins。

### TripNotesPage（/trip/:id/notes，581 行）
- **區塊**：TitleBar「行程筆記 — {trip}」→（empty 時 hero + 5 點進度）→ 5-section accordion：航班/住宿/預訂/行前須知/緊急聯絡，head = icon + title + count meta + chevron，展開 body = 各自 CRUD section component（FlightsSection 等，含 row 編輯 form）。
- **互動**：行前須知/緊急聯絡有 AI 生成按鈕（一般/住宿/AI），觸發後顯示 pulse pending banner「通常 3–7 分鐘」；mobile 預設展開航班、desktop 全展開。
- **資料**：`GET /trips/:id/notes`（aggregator 一次回 5 區）、`POST /trips/:id/notes/:docType/generate`、`useRequestSSE` 監聽 job 完成。

### AccountPage（/account，496 行）
- **區塊**：profile hero（avatar 首字母、displayName inline 編輯 blur 自動存 `PATCH /account/profile`、email、3 統計：行程數/旅程天數/旅伴數 `GET /account/stats`）→ 3 組設定 rows（應用程式：外觀/通知；共編&整合：已連結 app/開發者；帳號：已登入裝置/登出）→ 登出 ConfirmModal → `POST /oauth/logout` → `/login`。

### ExplorePage（/explore，872 行）— P1 但附結構
- TitleBar（back→/favorites）→ 地區 pill popover（沖繩/東京/…+ 自訂）→ 搜尋 bar（submit 制，≥2 字，`GET /poi-search?q&region&limit=20`，AbortController 防 race）→ 分類 subtab chips（為你推薦/景點/美食/住宿/購物，client-side filter）→ POI card grid（heart 收藏 toggle：`POST /pois/find-or-create` + `POST/DELETE /poi-favorites`；「加入行程」link）→ landing/empty states。

## 4. Flutter MVP 移植優先級

### P0（核心使用流程必備）
| 項目 | 對應 |
|---|---|
| 5-tab BottomNav shell + go_router | GlobalBottomNav |
| 登入（email/密碼 session） | LoginPage + useRequireAuth 等價 auth guard |
| 行程清單（filter tabs + 排序 + card grid + 刪除） | TripsListPage |
| 行程時間軸（DayNav + 逐日 timeline + 移動 pill；mobile 上是 list→push detail） | TripPage |
| 行程地圖（day tabs + entry cards + pin 同步；google_maps_flutter） | MapPage |
| 行程筆記（5-section accordion，手動 CRUD 即可） | TripNotesPage |
| 帳號 hub（profile + 統計 + 登出） | AccountPage |
| API client + 錯誤/離線 banner + toast | apiClient/Toast/AlertPanel |

### P1（重要，第二波）
- 收藏 PoiFavoritesPage（primary tab 4）+ ExplorePage + 加入行程 fast-path（AddPoiFavoriteToTripPage）
- Entry CRUD 全頁 form 群：AddEntryPage（新增景點 wizard）、EditEntryPage、ChangePoiPage、EntryActionPage（複製/移動）、AddStopPage、AddCustomStopPage
- NewTripPage / EditTripPage（建立/編輯行程）
- ChatPage（tab 1 — AI 改行程，依賴後端 request queue）
- GlobalMapPage（tab 3 全域地圖）
- CollabPage 共編 + InvitePage

### P2（可延後）
- TripPrintPage / PDF·JSON 下載、匯入行程
- TripSharePage 公開分享（`/s/:token`）+ ShareLinkModal
- 設定子頁：AppearanceSettingsPage（深色模式可先用系統值）、NotificationsSettingsPage、SessionsPage
- OAuth 生態：ConsentPage、ConnectedAppsPage、DeveloperAppsPage/New
- Service worker 等價（離線快取進階）、scroll-spy hash 還原等 web-only 細節

**移植注意**：(1) web 的「trip 詳情 = `/trips?selected=`」是 URL 技巧，Flutter 直接做 push navigation 即可；(2) `/trip/:tripId/*` 子頁共用一次 trip+days fetch（TripLayout），Flutter 用 scoped Provider 重現避免每頁重抓；(3) 所有 modal 已全面改 full-page form，與 mobile push screen 模型天然吻合。

關鍵檔案：`src/entries/main.tsx`（router）、`src/components/shell/GlobalBottomNav.tsx`、`src/pages/{TripsListPage,TripPage,MapPage,TripNotesPage,AccountPage,ExplorePage,TripLayout}.tsx`、`src/hooks/useTrip.ts`、`src/lib/apiClient.ts`。
