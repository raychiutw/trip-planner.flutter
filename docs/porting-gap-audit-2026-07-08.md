# Tripline Flutter 移植缺口盤點（2026-07-08）

> 流程：依 `tp-team` 先做 Think/Plan，比對現況；本文件是進入 Build 前的缺口清單。
> 來源：web repo `src/entries/main.tsx`、web `src/pages/*`、Flutter `lib/app/router.dart`、`lib/features/*`、`docs/PORTING_PLAN.md`。

## 結論

Flutter v0.1.0 已完成 P0「可登入並唯讀瀏覽行程」：登入、5-tab shell、行程清單、行程時間軸、行程地圖、行程筆記唯讀、帳號 hub。
還沒翻寫的主體集中在三類：

1. **Primary tab placeholder**：`/map` 仍是 `PlaceholderScreen`；`/favorites` 與 `/chat` 已轉正。
2. **Trip action surface**：新增/編輯行程、景點 CRUD 剩餘子流程、共編、健檢、列印/分享仍待 Flutter route 或完整實作。
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
| `/chat` → `ChatPage` | `/chat` → `ChatScreen` | 已翻第一波 | 後續可補 SSE、歷史分頁與更完整 trip picker parity |
| `/map` → `GlobalMapPage` | `/map` → placeholder | 未翻 | P1：跨行程 POI map |
| `/favorites` → `PoiFavoritesPage` | `/favorites` → `FavoritesScreen` | 已翻第一波 | 後續可補更多 web card actions |
| `/explore` → `ExplorePage` | `/explore` → `ExploreScreen` | 已翻第一波 | 後續可補分類 chips / landing polish |
| `/favorites/:id/add-to-trip` | `/favorites/:favoriteId/add-to-trip` → `AddPoiFavoriteToTripScreen` | 已翻第一波 | 後續補衝突細節顯示 |
| `/add-to-trip` | `/add-to-trip?place_id=...` → `AddPoiFavoriteToTripScreen` | 已翻第一波 | 後續補衝突細節顯示 |
| `/trips/new` → `NewTripPage` | `/trips/new` → `TripFormScreen.create` | 已翻第一波 | 後續可補 POI autocomplete / flexible month parity |
| `/trip/:id/edit` → `EditTripPage` | `/trips/:id/edit` → `TripFormScreen.edit` | 已翻 meta slice | 後續補 day management / auto-save parity |
| `/trip/:id/add-entry`, `add-stop`, `add-custom-stop` | `/trips/:id/add-entry`、`/trips/:id/add-stop`、`/trips/:id/add-custom-stop` → `AddEntryScreen` | 部分翻 | 已補搜尋/收藏新增與自訂地圖座標新增 slice |
| `/trip/:id/stop/:eid/edit/change-poi/copy/move` | `/trips/:id/stop/:entryId/edit` → `EditEntryScreen`; `/trips/:id/stop/:entryId/change-poi` → `ChangePoiScreen`; `/trips/:id/stop/:entryId/copy`、`/move` → `EntryActionScreen` | 部分翻 | 已補時間/描述/刪除、主景點置換、加備選、copy/move、備選移除/排序與 409 重抓 retry slice；segments edit 等 web parity 細節仍待補 |
| `/trip/:id/collab`, `/invite` | 無 | 未翻 | P1：共編與邀請 |
| `/trip/:id/health` | 無 | 未翻 | P1：AI 健檢報告 |
| `/trip/:id/print` | 無 | 未翻 | P2：列印/PDF/分享 |
| `/s/:token` | 無 | 未翻 | P2：公開分享頁 |
| `/signup`, `/login/forgot`, `/auth/password/reset`, `/auth/verify-email` | 無 | 未翻 | P1/P2：auth 補齊 |
| `/account/*`, `/settings/*` 子頁 | 無 | 未翻 | P2：設定/裝置/連結 app |
| `/developer/apps*`, `/oauth/consent` | 無 | 未翻 | P2：OAuth 生態 |

## P0 Parity Debt

這些不是全新 P1 功能，但 web P0 畫面已有而 Flutter P0 只做到可用版。

- **TripsListScreen**：目前有單欄清單、下拉更新、AppBar/空狀態新增入口、長按編輯/刪除。尚缺分類 tabs（全部/我的/共編/已歸檔）、排序、搜尋、匯入、完整 TripCardMenu（共編/健檢/筆記/分享等）、尾端新增卡、filtered empty。
- **TripTimelineScreen**：目前有 day pills + timeline + travel pill + map/notes/add-entry actions。尚缺 scroll-spy 自動同步 active day、今日自動定位、`focus` entry deep link、offline banner、segment 即時 refetch、行程切換 dropdown、overflow actions。
- **TripMapScreen**：目前是 OSM pins + day tabs + entry cards。尚缺 `stop/:entryId/map` focus route、pin/card 雙向同步、overview 點 pin 自動切 day、路線 polyline、圖層/我的位置 FAB。
- **TripNotesScreen**：目前 5-section accordion 唯讀。尚缺 CRUD、OCC、AI generate、request pending 狀態。
- **AccountScreen**：目前 profile/stat/logout 可用。尚缺 displayName inline edit UI、外觀/通知/connected apps/sessions/developer rows 實際頁面。

## P1 建議切分

1. **Favorites / Explore / Add-to-trip**
   - Routes：`/favorites`、`/explore`、`/favorites/:id/add-to-trip`、`/add-to-trip`
   - API：`GET /poi-favorites`、`POST/DELETE /poi-favorites`、`GET /poi-search`、`POST /pois/find-or-create`、`POST /trips/:id/days/:num/entries`、`POST /trips/:id/recompute-travel`
   - 狀態：`/favorites`、`/explore`、`/favorites/:id/add-to-trip`、`/add-to-trip` 已完成第一波。
   - 理由：功能邊界獨立；完成後 primary tab 不再是 placeholder。

2. **Trip action surface**
   - Routes：`/trips/new`、`/trips/:id/edit`、`/trips/:id/add-entry`、`add-stop`、`add-custom-stop`
   - API：trip create/update、entry create/update/delete、segments create/patch、places resolve/search
   - 狀態：`/trips/new`、`/trips/:id/edit` 已有基本資料與目的地表單 slice；`/trips/:id/add-entry` / `add-stop` 已有搜尋/收藏/自訂座標新增 slice；`/trips/:id/stop/:entryId/edit` 已有時間/描述/刪除與備選移除/排序 slice；`/trips/:id/stop/:entryId/change-poi` 已有主景點置換/加備選 slice；`/trips/:id/stop/:entryId/copy` 與 `/move` 已有跨日操作 slice；segments edit、edit day management 等 web parity 細節仍待補。
   - 理由：補上 mobile app 最直接的規劃能力；需 TDD + OCC handling。

3. **Entry detail/action forms**
   - Routes：`stop/:entryId/edit`、`change-poi`、`copy`、`move`
   - API：entry PATCH、entry POI master/alternates、copy/move endpoints、recompute-travel trigger
   - 狀態：`stop/:entryId/edit` 已先補讀取、時間/描述更新、刪除與備選移除/排序；`change-poi` 已補搜尋/收藏置換 master 與新增 alternate；`copy` / `move` 已補跨日複製/移動；edit/move/POI mutation 遇 409 `STALE_ENTRY` 會重抓 entry 並 retry 一次。
   - 理由：和第 2 項共用 models/providers，可分 PR 避免過大。

4. **Chat / request queue**
   - Route：`/chat`
   - API：`GET /requests?tripId=...`、`POST /requests`、`GET /requests/:id`
   - 狀態：已完成第一波 request history、create request、pending bubble 與 polling 替換 AI 回覆；未先做 SSE。
   - 理由：依賴 active trip 與 request lifecycle；第一波已讓 primary tab 不再是 placeholder。

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

下一個 Build branch 建議接 **全域地圖** 或 **共編邀請**。Favorites / Explore / 加入行程 fast-path 第一波已把 favorites tab 轉正；AI 聊天已完成 request queue + pending/polling 第一波；建立/編輯行程已補基本資料 slice；Entry CRUD 已先補新增景點搜尋/收藏/自訂座標、edit 時間/描述/刪除與備選移除/排序、change-poi 主景點置換/加備選、copy/move 跨日操作與 stale retry slice。

1. 若續做 Trip action surface：優先補 edit day management 或 segments edit,避免與既有 entry mutation contract 脫節。
2. 若續做 Chat：補 SSE、歷史分頁與 web trip picker parity。
3. 本分支完成後，重跑 `flutter analyze`、`flutter test`，再更新 `TODOS.md` 的 P1 剩餘項。
