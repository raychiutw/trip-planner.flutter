# Tripline Flutter 移植藍圖

> 來源：trip-planner React SPA（https://github.com/raychiutw/trip-planner）
> 後端不變：Cloudflare Pages Functions API（https://trip-planner-dby.pages.dev/api）
> 詳細調查報告：`docs/discovery/{screens,api-auth,models,design}.md`
>
> 本檔保留移植範圍與架構決策；P0/P1/P2 已完成。現行 UI 規格只以根目錄 [`design.md`](../design.md) 為 SOT；下列已完成項目已同步為目前架構。

## 架構決策

| 面向 | 決策 | 理由 |
|---|---|---|
| State management | flutter_riverpod 3.x | scoped provider 天然對應 web 的 TripLayout 共用 fetch（規劃時為 2.x，實作採 3.x） |
| Routing | go_router + StatefulShellRoute | 4-tab shell（聊天／行程／地圖／收藏）保留各 tab navigation stack；Account 使用獨立 sheet |
| HTTP | dio + interceptor | interceptor 統一處理 session cookie、Origin header、錯誤轉換、429 retry |
| 認證 | Cookie 登入 + OAuth PKCE/Bearer 就緒 | `POST /api/oauth/login` → 解析 `Set-Cookie: tripline_session`，存 flutter_secure_storage；mutating request 手動帶 `Origin: https://trip-planner-dby.pages.dev`（CSRF Origin 檢查必要）。OAuth PKCE/Bearer client 端已實作並以 dart-define 啟用，production backend 已 provision `tripline-mobile` active public client |
| 地圖 | google_navigation_flutter + domain adapter | iOS／Android 使用各自受平台限制的金鑰；`features/map/map_adapter.dart` 隔離 SDK 型別並支援原生 Google POI callback，路線沿用 Web `/route` 契約 |
| JSON | 手寫 fromJson（camelCase wire） | server 端 `deepCamel()` 已轉 camelCase；不用 build_runner 減少建置複雜度 |
| 測試 | flutter_test + mocktail + http_mock_adapter | TDD：models 解析測試、api client 行為測試、widget 測試 |

## API client 必守規則（來自 web `src/lib/apiClient.ts` 行為）

1. Base URL `https://trip-planner-dby.pages.dev/api`；origin 可用 `--dart-define=TRIPLINE_API_ORIGIN`（值為 origin，不含 /api）覆寫，同一 origin 也用於 CSRF Origin header；測試另可用 `ApiClient(origin:)` 建構參數覆寫（見 `docs/howto-local-backend.md`）
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
| 4-tab shell + Account sheet | GlobalBottomNav／Account | — |
| LoginScreen | LoginPage | `POST /oauth/login` |
| TripsListScreen | TripsListPage | `GET /my-trips` + `GET /trips?all=1`、`DELETE /trips/:id` |
| TripTimelineScreen | TripPage（embedded） | `GET /trips/:id` + `GET /trips/:id/days?all=1` |
| TripMapScreen | MapPage | 共用 trip scope 資料（不重抓） |
| TripNotesScreen | TripNotesPage | `GET /trips/:id/notes` + 各 section CRUD |
| AccountScreen | AccountPage | `GET /oauth/userinfo`、`PATCH /account/profile`、`POST /oauth/logout` |
| ChatScreen / FavoritesScreen | P1 已轉正 | `POST /requests` chat flow、收藏清單 / Explore / 加入行程 |

P1（第二波）：收藏 + Explore、Entry CRUD 表單群、建立/編輯行程、聊天（request queue）、全域地圖、共編。
P2：列印/分享/匯入、設定子頁、通知偏好 toggle、OAuth 生態、離線快取已補齊；OAuth 實機 browser/loopback e2e 仍需手動驗證。

## 目錄結構

```
lib/
  main.dart                 # ProviderScope + MaterialApp.router
  app/router.dart           # go_router + StatefulShellRoute + auth redirect
  theme/tokens.dart         # iOS system semantic colors、單一 tint、間距與 motion
  theme/app_theme.dart      # iOS 系統語意 Light／Dark／High Contrast ThemeData
  models/                   # trip / day / entry / poi / notes / user…（fromJson + 等值）
  api/api_client.dart       # dio 封裝：cookie、origin、錯誤、retry、204
  api/api_error.dart        # ApiError（code/message/detail）
  api/auth_repository.dart  # login / logout / userinfo / session 持久化
  api/trip_repository.dart  # my-trips / trips / days / notes 與協作資料
  app/adaptive.dart         # 共用 HIG calendar、time wheel、alert、confirm、notice
  features/auth/            # LoginScreen
  features/trips/           # TripsListScreen + trip card
  features/trip_detail/     # TripTimelineScreen / TripMapScreen / TripNotesScreen + trip scope providers
  features/map/             # GlobalMapScreen + map_adapter.dart
  features/account/         # AccountScreen
  features/shell/           # 4-tab scaffold + root navigation
  ui/                       # 共用 surface、selector、App Bar、settings row
test/                       # 與 lib/ 鏡像
```

## 設計系統重點（規範詳見根目錄 `/design.md`）

- 全 App 只使用一個 tint；Light／Dark／High Contrast 皆由 `TpSystemColors*` 對應 iOS system semantic colors，不另立品牌暖白 palette
- POI／收藏／行程 surface 與 outline 使用系統 semantic colors；sage／pink 分類色及舊暖白色票已退場
- 卡片：elevation 0 + 1px system semantic outline、radius 8；shadow 只給浮層
- 字體：平台系統字（iOS/macOS SF Pro、Android Roboto，中文走系統 fallback）；主要內文 17/26；時間 tabular-nums
- 導覽：四個 branch 共用 `AppleRootTabBar` Liquid Glass 浮動功能層；帳號由 Header 的 `person.crop.circle` 開啟獨立 sheet，內容寬版由 `AppAdaptiveContent` 依角色限寬
- 禁止：gradient 裝飾、emoji icon、rainbow 色（地圖 polyline 例外）
