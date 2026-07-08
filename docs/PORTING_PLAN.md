# Tripline Flutter 移植藍圖

> 來源：trip-planner React SPA（https://github.com/raychiutw/trip-planner）
> 後端不變：Cloudflare Pages Functions API（https://trip-planner-dby.pages.dev/api）
> 詳細調查報告：`docs/discovery/{screens,api-auth,models,design}.md`

## 架構決策

| 面向 | 決策 | 理由 |
|---|---|---|
| State management | flutter_riverpod 3.x | scoped provider 天然對應 web 的 TripLayout 共用 fetch（規劃時為 2.x，實作採 3.x） |
| Routing | go_router + StatefulShellRoute | 5-tab shell（聊天/行程/地圖/收藏/帳號）保留各 tab navigation stack |
| HTTP | dio + interceptor | interceptor 統一處理 session cookie、Origin header、錯誤轉換、429 retry |
| 認證 | 密碼登入拿 session cookie | `POST /api/oauth/login` → 解析 `Set-Cookie: tripline_session`，存 flutter_secure_storage；mutating request 手動帶 `Origin: https://trip-planner-dby.pages.dev`（CSRF Origin 檢查必要）。OAuth PKCE+Bearer 留待後續（需註冊 public client） |
| 地圖 | flutter_map + OSM tiles | 免 API key、零帳務設定；介面抽象化，之後可換 google_maps_flutter |
| JSON | 手寫 fromJson（camelCase wire） | server 端 `deepCamel()` 已轉 camelCase；不用 build_runner 減少建置複雜度 |
| 測試 | flutter_test + mocktail + http_mock_adapter | TDD：models 解析測試、api client 行為測試、widget 測試 |

## API client 必守規則（來自 web `src/lib/apiClient.ts` 行為）

1. Base URL `https://trip-planner-dby.pages.dev/api`；`--dart-define=TRIPLINE_API_URL` 覆寫為規劃項尚未實作（目前以 `ApiClient(origin:)` 建構參數覆寫，測試即用此法）
2. 認證：`Cookie: tripline_session=<token>` header（secure storage 持久化）
3. POST/PUT/PATCH/DELETE 一律帶 `Origin: https://trip-planner-dby.pages.dev`（缺少 → 403）
4. `/api/oauth/*` 路徑免 Origin；userinfo 只吃 cookie
5. 錯誤 shape：`{error:{code,message,detail?}}`；code 是穩定機器碼（`AUTH_REQUIRED`/`PERM_DENIED`/`STALE_ENTRY`/`SYS_RATE_LIMIT`…）
6. 429：讀 `Retry-After`（cap 30s），只 retry GET 一次，mutation 絕不 retry
7. 204 → 成功、無 body（不可呼叫 json 解析）
8. OCC：PATCH 帶 `expectedVersion`，409 `STALE_ENTRY` 時重抓再套用

## MVP 範圍（P0）

| Screen | Web 對應 | 資料來源 |
|---|---|---|
| 5-tab shell | GlobalBottomNav | — |
| LoginScreen | LoginPage | `POST /oauth/login` |
| TripsListScreen | TripsListPage（分類/搜尋/排序/action menu/JSON 匯入/ShareLink 第一波） | `GET /my-trips` rich summary（client-side filter/sort/search）、`DELETE /trips/:id`、`POST /trips/import`、`GET/POST/PATCH/DELETE /trips/:id/shares`、現有 trips child routes |
| TripFormScreen | NewTripPage / EditTripPage（基本資料 + day management slice） | `POST /trips`、`GET /trips/:id`、`PUT /trips/:id`、`GET/POST /trips/:id/days`、`DELETE /trips/:id/days/:num`、`POST /trips/:id/days/shift` |
| TripTimelineScreen | TripPage（embedded） | `GET /trips/:id` + `GET /trips/:id/days?all=1` + `GET/PATCH /trips/:id/segments`；支援 `?focus=<entryId>` 初載定位 |
| TripMapScreen | MapPage | 共用 trip scope 資料（不重抓） |
| TripNotesScreen | TripNotesPage | `GET /trips/:id/notes`、各 section CRUD、`POST /trips/:id/notes/:docType/generate` + request polling |
| TripHealthScreen | TripHealthCheckPage | `GET/POST /trips/:id/health-check` + report polling |
| AccountScreen / settings first wave | AccountPage / AppearanceSettingsPage / NotificationsSettingsPage | `GET /oauth/userinfo`、`GET /account/stats`、`PATCH /account/profile`、`POST /oauth/logout`、本機 theme/notification preferences |
| Auth supplement screens | SignupPage / EmailVerifyPendingPage / ForgotPasswordPage / ResetPasswordPage / VerifyEmailPage | `POST /oauth/signup`、`POST /oauth/send-verification`、`POST /oauth/forgot-password`、`POST /oauth/reset-password`、`POST /oauth/verify` |
| ChatScreen | ChatPage（request queue 第一波） | `GET /requests?tripId=...`、`POST /requests`、`GET /requests/:id` |
| GlobalMapScreen | GlobalMapPage（trip-bound resolver 第一波） | `GET /my-trips` + `GET /trips/:id/days?all=1` |
| CollabScreen / InviteScreen | CollabPage / InvitePage（共編邀請第一波） | `GET/POST/PATCH/DELETE /permissions`、`GET /invitations?tripId=...`、`POST /invitations/revoke`、`GET /invitations?token=...`、`POST /invitations/accept` |
| FavoritesScreen / ExploreScreen / AddPoiFavoriteToTripScreen | PoiFavoritesPage / ExplorePage / AddPoiFavoriteToTripPage | `GET /poi-favorites`、`GET /poi-search`、`POST /pois/find-or-create`、`POST/DELETE /poi-favorites`、`POST /poi-favorites/:id/add-to-trip`、`POST /trips/:id/days/:num/entries`、`POST /trips/:id/recompute-travel` |
| AddEntryScreen | AddEntryPage / AddStopPage / AddCustomStopPage（新增景點 slice） | `GET /trips/:id/days?all=1`、`GET /poi-search`、`GET /poi-favorites`、`POST /trips/:id/days/:num/entries`、`POST /poi-favorites/:id/add-to-trip`、`POST /trips/:id/recompute-travel` |
| EditEntryScreen | EditEntryPage（時間/描述/刪除 + 備選管理 slice） | `GET/PATCH/DELETE /trips/:id/entries/:entryId`、`DELETE /trips/:id/entries/:entryId/alternates/:poiId`、`PATCH /trips/:id/entries/:entryId/alternates/reorder`、`POST /trips/:id/recompute-travel` |
| ChangePoiScreen | ChangePoiPage（主景點置換/加備選 slice） | `PUT /trips/:id/entries/:entryId/poi-id`、`POST /trips/:id/entries/:entryId/alternates`、`GET /poi-search`、`GET /poi-favorites`、`POST /trips/:id/recompute-travel` |
| EntryActionScreen | EntryActionPage（copy/move slice） | `POST /trips/:id/entries/:entryId/copy`、`PATCH /trips/:id/entries/:entryId`(`day_id` + `expectedVersion`)、`POST /trips/:id/recompute-travel` |

P1（第二波）：TripsList P0 parity 已補分類/搜尋/排序/filtered empty/action menu/尾端新增卡/JSON 匯入/分享連結管理；TripTimelineScreen 已補 focus entry deep link；AccountScreen 已補 displayName inline edit 與外觀/通知設定第一波；收藏 + Explore + 加入行程 fast-path 已完成第一波；建立/編輯行程已完成基本資料、目的地表單與 edit day management（新增/補缺日/刪除/平移日期）slice；Entry CRUD 已完成 `/trips/:id/add-entry` 搜尋/收藏/自訂座標新增 slice、`/trips/:id/stop/:entryId/edit` 時間/描述/刪除與備選移除/排序 slice、`/trips/:id/stop/:entryId/change-poi` 主景點置換/加備選 slice、`/trips/:id/stop/:entryId/copy` 與 `/move` 跨日複製/移動 slice、timeline travel segments edit slice，並支援 409 `STALE_ENTRY` 重抓再套用；聊天 request queue + pending/polling、全域地圖 tab resolver、共編邀請/成員管理、行程筆記 CRUD + AI generate、AI 健檢報告與 Auth 補齊第一波已完成。
P2：公開分享頁/列印/JSON 匯出、settings sessions / connected apps / developer apps、OAuth 生態、離線快取。

## 目錄結構

```
lib/
  main.dart                 # ProviderScope + MaterialApp.router
  app/app_preferences.dart  # themeMode 與通知偏好本機 provider
  app/router.dart           # go_router + StatefulShellRoute + auth redirect
  theme/tokens.dart         # design token 常數（tokens.css 對應）
  theme/app_theme.dart      # light/dark ThemeData + ThemeExtension（三色 4 階）
  models/                   # auth / trip / day / entry / poi / chat / collab / health / notes / user…（fromJson + 等值）
  api/api_client.dart       # dio 封裝：cookie、origin、錯誤、retry、204
  api/api_error.dart        # ApiError（code/message/detail）
  api/auth_repository.dart  # login / signup / password reset / email verification / session 持久化
  api/trip_repository.dart  # my-trips / trips / days / segments / requests / permissions / invitations / health / notes / stats
  features/auth/            # LoginScreen + signup / forgot-reset / email verification screens
  features/chat/            # ChatScreen
  features/collab/          # CollabScreen
  features/invite/          # InviteScreen
  features/map/             # GlobalMapScreen
  features/trips/           # TripsListScreen + TripFormScreen + trip card
  features/trip_detail/     # TripTimelineScreen / TripMapScreen / TripNotesScreen / TripHealthScreen + trip scope providers
  features/favorites/       # FavoritesScreen / ExploreScreen / AddPoiFavoriteToTripScreen
  features/account/         # AccountScreen
  features/shell/           # 5-tab scaffold + remaining placeholder screens
  widgets/                  # 共用：toast、confirm dialog、empty state、chips
test/                       # 與 lib/ 鏡像
```

## 設計系統重點（詳見 discovery/design.md）

- 主色柔褐 `#A97A4A`（dark `#CBA06E`），奶油底 `#FFFBF5`（dark `#1A140F`）
- 三色系統：玩/看/買=柔褐 accent、住/移動=sage `#A8BAAA`、吃=粉 `#E78C99`，各 4 階（base/deep/subtle/bg）
- 卡片：elevation 0 + 1px hairline `#EADFCF`、radius 8；shadow 只給浮層
- 字體：Inter → Noto Sans TC fallback；中文內文 16/26；時間 tabular-nums
- Bottom nav：高 88（含 safe area）、glass blur、active = accent + accent-subtle pill
- 禁止：gradient 裝飾、emoji icon、rainbow 色（地圖 polyline 例外）
