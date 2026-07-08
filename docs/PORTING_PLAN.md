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
| 認證 | Cookie 登入 + OAuth PKCE/Bearer 就緒 | `POST /api/oauth/login` → 解析 `Set-Cookie: tripline_session`，存 flutter_secure_storage；mutating request 手動帶 `Origin: https://trip-planner-dby.pages.dev`（CSRF Origin 檢查必要）。OAuth PKCE/Bearer client 端已實作並以 dart-define 啟用，production backend 已 provision `tripline-mobile` active public client |
| 地圖 | flutter_map + OSM tiles + adapter | 免 API key、零帳務設定；`features/map/map_adapter.dart` 集中 SDK 轉接，之後可換 google_maps_flutter |
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
| 5-tab shell | GlobalBottomNav | — |
| LoginScreen | LoginPage | `POST /oauth/login` |
| TripsListScreen | TripsListPage | `GET /my-trips` + `GET /trips?all=1`、`DELETE /trips/:id` |
| TripTimelineScreen | TripPage（embedded） | `GET /trips/:id` + `GET /trips/:id/days?all=1` |
| TripMapScreen | MapPage | 共用 trip scope 資料（不重抓） |
| TripNotesScreen | TripNotesPage | `GET /trips/:id/notes` + 各 section CRUD |
| AccountScreen | AccountPage | `GET /oauth/userinfo`、`GET /account/stats`、`PATCH /account/profile`、`POST /oauth/logout` |
| ChatScreen / FavoritesScreen | P1 已轉正 | `POST /requests` chat flow、收藏清單 / Explore / 加入行程 |

P1（第二波）：收藏 + Explore、Entry CRUD 表單群、建立/編輯行程、聊天（request queue）、全域地圖、共編。
P2：列印/分享/匯入、設定子頁、通知偏好 toggle、OAuth 生態、離線快取已補齊；OAuth 實機 browser/loopback e2e 仍需手動驗證。

## 目錄結構

```
lib/
  main.dart                 # ProviderScope + MaterialApp.router
  app/router.dart           # go_router + StatefulShellRoute + auth redirect
  theme/tokens.dart         # design token 常數（tokens.css 對應）
  theme/app_theme.dart      # light/dark ThemeData + ThemeExtension（三色 4 階）
  models/                   # trip / day / entry / poi / notes / user…（fromJson + 等值）
  api/api_client.dart       # dio 封裝：cookie、origin、錯誤、retry、204
  api/api_error.dart        # ApiError（code/message/detail）
  api/auth_repository.dart  # login / logout / userinfo / session 持久化
  api/trip_repository.dart  # my-trips / trips / days / notes / stats
  features/auth/            # LoginScreen
  features/trips/           # TripsListScreen + trip card
  features/trip_detail/     # TripTimelineScreen / TripMapScreen / TripNotesScreen + trip scope providers
  features/map/             # GlobalMapScreen + map_adapter.dart
  features/account/         # AccountScreen
  features/shell/           # 5-tab scaffold + placeholder screens
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
