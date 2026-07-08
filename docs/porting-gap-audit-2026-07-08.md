# Tripline Flutter 移植缺口盤點（2026-07-08）

> 流程：依 `tp-team` 先做 Think/Plan，比對現況；本文件是進入 Build 前的缺口清單。
> 來源：web repo `src/entries/main.tsx`、web `src/pages/*`、Flutter `lib/app/router.dart`、`lib/features/*`、`docs/PORTING_PLAN.md`。

## 結論

Flutter v0.1.0 已完成 P0「可登入並唯讀瀏覽行程」：登入、5-tab shell、行程清單、行程時間軸、行程地圖、行程筆記唯讀、帳號 hub。
還沒翻寫的主體集中在三類：

1. **Primary tab placeholder**：`/chat`、`/map`、`/favorites` 仍是 `PlaceholderScreen`。
2. **Trip action surface**：新增/編輯行程、景點 CRUD、共編、健檢、列印/分享都尚未有 Flutter route。
3. **Auth/OAuth/設定生態**：註冊、忘記密碼、email 驗證、settings、connected apps、developer apps、consent 尚未翻。

## 現行 Route 對照

| Web route/component | Flutter route/component | 狀態 | 下一步 |
|---|---|---|---|
| `/login` → `LoginPage` | `/login` → `LoginScreen` | 已翻 | 後續補 signup/forgot/reset/verify |
| `/trips` → `TripsListPage` | `/trips` → `TripsListScreen` | 部分翻 | 補 filter/sort/search、新增、分享、menu actions |
| `/trip/:id` embedded `TripPage` | `/trips/:id` → `TripTimelineScreen` | 部分翻 | 補 action menu、focus/deeplink、segment 即時 refetch |
| `/trip/:id/map` → `MapPage` | `/trips/:id/map` → `TripMapScreen` | 部分翻 | 補 entry focus route、pin/card 雙向同步、路線/定位控制 |
| `/trip/:id/notes` → `TripNotesPage` | `/trips/:id/notes` → `TripNotesScreen` | 唯讀翻寫 | 補 5 區 CRUD + AI generate/pending |
| `/account` → `AccountPage` | `/account` → `AccountScreen` | 部分翻 | 補 displayName inline edit、settings rows 導航 |
| `/chat` → `ChatPage` | `/chat` → placeholder | 未翻 | P1：AI request queue |
| `/map` → `GlobalMapPage` | `/map` → placeholder | 未翻 | P1：跨行程 POI map |
| `/favorites` → `PoiFavoritesPage` | `/favorites` → placeholder | 未翻 | P1：收藏 tab 轉正 |
| `/explore` → `ExplorePage` | 無 | 未翻 | P1：收藏 secondary route |
| `/favorites/:id/add-to-trip`, `/add-to-trip` | 無 | 未翻 | P1：收藏/探索加入行程 fast-path |
| `/trips/new` → `NewTripPage` | 無 | 未翻 | P1：建立行程 |
| `/trip/:id/edit` → `EditTripPage` | 無 | 未翻 | P1：編輯行程 meta |
| `/trip/:id/add-entry`, `add-stop`, `add-custom-stop` | 無 | 未翻 | P1：新增景點表單群 |
| `/trip/:id/stop/:eid/edit/change-poi/copy/move` | 無 | 未翻 | P1：Entry CRUD / action forms |
| `/trip/:id/collab`, `/invite` | 無 | 未翻 | P1：共編與邀請 |
| `/trip/:id/health` | 無 | 未翻 | P1：AI 健檢報告 |
| `/trip/:id/print` | 無 | 未翻 | P2：列印/PDF/分享 |
| `/s/:token` | 無 | 未翻 | P2：公開分享頁 |
| `/signup`, `/login/forgot`, `/auth/password/reset`, `/auth/verify-email` | 無 | 未翻 | P1/P2：auth 補齊 |
| `/account/*`, `/settings/*` 子頁 | 無 | 未翻 | P2：設定/裝置/連結 app |
| `/developer/apps*`, `/oauth/consent` | 無 | 未翻 | P2：OAuth 生態 |

## P0 Parity Debt

這些不是全新 P1 功能，但 web P0 畫面已有而 Flutter P0 只做到可用版。

- **TripsListScreen**：目前只有單欄清單、下拉更新、長按刪除。尚缺分類 tabs（全部/我的/共編/已歸檔）、排序、搜尋、匯入、新增行程入口、TripCardMenu（共編/編輯/健檢/筆記/分享/刪除）、尾端新增卡、filtered empty。
- **TripTimelineScreen**：目前有 day pills + timeline + travel pill + map/notes actions。尚缺 scroll-spy 自動同步 active day、今日自動定位、`focus` entry deep link、offline banner、segment 即時 refetch、行程切換 dropdown、overflow actions、新增景點入口。
- **TripMapScreen**：目前是 OSM pins + day tabs + entry cards。尚缺 `stop/:entryId/map` focus route、pin/card 雙向同步、overview 點 pin 自動切 day、路線 polyline、圖層/我的位置 FAB。
- **TripNotesScreen**：目前 5-section accordion 唯讀。尚缺 CRUD、OCC、AI generate、request pending 狀態。
- **AccountScreen**：目前 profile/stat/logout 可用。尚缺 displayName inline edit UI、外觀/通知/connected apps/sessions/developer rows 實際頁面。

## P1 建議切分

1. **Favorites / Explore / Add-to-trip**
   - Routes：`/favorites`、`/explore`、`/favorites/:id/add-to-trip`、`/add-to-trip`
   - API：`GET /poi-favorites`、`POST/DELETE /poi-favorites`、`GET /poi-search`、`POST /pois/find-or-create`
   - 理由：目前 primary tab 仍 placeholder；功能邊界獨立，可先做唯讀+收藏 toggle，再接加入行程。

2. **Trip action surface**
   - Routes：`/trips/new`、`/trips/:id/edit`、`/trips/:id/add-entry`、`add-stop`、`add-custom-stop`
   - API：trip create/update、entry create/update/delete、segments create/patch、places resolve/search
   - 理由：補上 mobile app 最直接的規劃能力；需 TDD + OCC handling。

3. **Entry detail/action forms**
   - Routes：`stop/:entryId/edit`、`change-poi`、`copy`、`move`
   - API：entry PATCH、entry POI master/alternates、copy/move endpoints、recompute-travel trigger
   - 理由：和第 2 項共用 models/providers，可分 PR 避免過大。

4. **Chat / request queue**
   - Route：`/chat`
   - API：trip_requests / SSE or polling
   - 理由：依賴 active trip 與 request lifecycle；完成後 primary tab 才不再是 placeholder。

5. **Collab / Invite**
   - Routes：`/trips/:id/collab`、`/invite`
   - API：permissions、invitations、accept/revoke
   - 理由：涉及權限語意與 invite token，應獨立安全 review。

6. **Notes CRUD + AI**
   - Routes：沿用 `/trips/:id/notes`
   - API：5 section CRUD、`/notes/:docType/generate`、request pending refresh
   - 理由：現有 notes models 已解析 5 區，是可漸進升級的 P1。

7. **Health check**
   - Route：`/trips/:id/health`
   - API：`POST /trips/:id/health-check`、reports polling
   - 理由：web 最近仍在修 AI 健檢資料來源，Flutter 應等 contract 穩定後翻。

8. **Auth supplement**
   - Routes：signup、forgot/reset password、verify email
   - 理由：不是已登入核心流，但 mobile app 完整性需要；PKCE/Bearer 另列 P2。

## P2 / 可延後

- 公開分享 `/s/:token`、ShareLink、列印/PDF、JSON import/export。
- Account/settings 子頁：appearance、notifications、sessions、connected apps。
- OAuth developer apps / consent / PKCE Bearer 認證。
- 離線快取與 web service worker 等價能力。
- GlobalMap 進階：跨行程聚合、路線、多圖層、定位權限。

## 不建議照搬

- Web desktop sidebar / 3-pane layout：Flutter mobile-first，不需要翻成同等桌機 layout。
- Web `?selected=` URL 技巧：Flutter 已用 `/trips/:tripId` push detail，保留即可。
- Service worker / browser-only lazy chunk retry：Flutter 不需要同構。

## 下一步

建議下一個 Build branch 從 **Favorites / Explore / Add-to-trip** 開始，因為它能一次把 primary tab placeholder 轉正，且與既有 trip timeline CRUD 低耦合。流程：

1. 先寫 `test/features/favorites/*` widget tests + `test/api/trip_repository_test.dart` endpoint tests。
2. 補 `models/poi_favorite.dart` / repository methods / providers。
3. 實作 `/favorites` tab，再接 `/explore` secondary route。
4. 最後接加入行程 fast-path，回到 trip timeline 後 invalidate days/provider。
