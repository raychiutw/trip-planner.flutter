# TODOS

待辦範圍以 [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md) 的 P1/P2 規劃為準;此檔追蹤執行狀態。新增功能一律走 TDD + feature branch(見 [CONTRIBUTING.md](CONTRIBUTING.md))。

## P1(第二波)

- [x] 收藏 + 探索 + 收藏加入行程 fast-path(`/favorites`,`/explore`,`/favorites/:id/add-to-trip`;favorites tab 由 placeholder 轉正)(**Completed:** feature/favorites-explore)
- [x] Explore direct-mode 加入行程(`/add-to-trip?place_id=...`;不需先收藏)(**Completed:** feature/favorites-explore)
- [ ] Entry CRUD 表單群(`/trips/:id/add-entry`,`add-stop`,`add-custom-stop`,`stop/:entryId/edit/change-poi/copy/move`;已完成 `/trips/:id/add-entry` 搜尋/收藏/自訂座標新增 slice、`/trips/:id/stop/:entryId/edit` 時間/描述/刪除 slice、`/trips/:id/stop/:entryId/change-poi` 主景點置換/加備選 slice、`/trips/:id/stop/:entryId/copy` 與 `/move` 跨日複製/移動 slice、edit screen 備選移除/排序 slice；edit/move 已帶 OCC `expectedVersion`,POI 變更已帶 `entryPoisVersion`,409 `STALE_ENTRY` 已重抓 entry 並 retry 一次；後續仍可補 segments edit 與更多 web parity 細節)
- [x] 建立/編輯行程(`/trips/new`,`/trips/:id/edit`;行程基本資料、目的地、日期、語言與發布狀態表單)(**Completed:** feature/favorites-explore)
- [x] AI 聊天(`/chat`;chat tab 轉正;request queue + pending/polling)(**Completed:** feature/favorites-explore)
- [x] 全域地圖(`/map`;map tab 轉正,以 trip picker 重用行程地圖內容)(**Completed:** feature/favorites-explore)
- [ ] 共編邀請(`/trips/:id/collab`,`/invite`;已完成成員/待邀請讀取、新增 member/viewer 邀請、撤回 pending invitation、公開邀請預覽與 email 相符接受；尚缺既有成員 role update / remove)
- [ ] 行程筆記 CRUD + AI generate(`/trips/:id/notes`;5 區由唯讀轉可編輯)
- [ ] AI 健檢報告(`/trips/:id/health`;reports polling)
- [ ] Auth 補齊(`/signup`,`/login/forgot`,`/auth/password/reset`,`/auth/verify-email`)

## P0 parity debt

- [ ] TripsListScreen 補 web parity:分類 tabs/排序/搜尋/匯入/完整 TripCardMenu/分享/filtered empty
- [ ] TripTimelineScreen 補 web parity:scroll-spy active day/今日自動定位/focus deep link/offline banner/segment 即時 refetch/overflow actions
- [ ] TripMapScreen 補 web parity:`stop/:entryId/map` focus route/pin-card 雙向同步/overview 點 pin 切 day/polyline/定位 FAB
- [ ] AccountScreen 補 web parity:displayName inline edit/外觀與通知 row 實際導航

## P2

- [ ] 分享/列印/匯入(`/s/:token`,`/trips/:id/print`,ShareLink,PDF/JSON)
- [ ] 設定子頁(`/account/*`,`/settings/*`,`/developer/apps*`,`/oauth/consent`)
- [ ] OAuth PKCE + Bearer 認證(需後端註冊 public client;取代 session cookie + 偽造 Origin 的過渡方案)
- [ ] 離線快取

## 技術債

- [ ] v0.1.0 PR merge 後在 master 補打 `git tag v0.1.0` 並 push — CHANGELOG 的 compare/release 連結目前指向尚不存在的 tag
- [ ] `--dart-define=TRIPLINE_API_URL` base URL 覆寫(PORTING_PLAN 規劃項,尚未實作;目前僅能以 `ApiClient(origin:)` 建構參數覆寫)
- [ ] 地圖介面抽象化(PORTING_PLAN 決策:保留之後換 google_maps_flutter 的空間;目前 flutter_map 直接用在 TripMapScreen)

## Completed

- [x] P0:登入/行程清單/時間軸/地圖/筆記/帳號 + 5-tab shell(**Completed:** v0.1.0, 2026-06-10)
- [x] 基礎層:tokens/theme、models、API client、providers(**Completed:** v0.1.0, 2026-06-10)
- [x] Diataxis 文件 9 篇 + CLAUDE.md + 標準專案文件(**Completed:** v0.1.0, 2026-06-10)
