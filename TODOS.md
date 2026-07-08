# TODOS

待辦範圍以 [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md) 的 P1/P2 規劃為準;此檔追蹤執行狀態。新增功能一律走 TDD + feature branch(見 [CONTRIBUTING.md](CONTRIBUTING.md))。

## P1(第二波)

- [x] 收藏 + 探索 + 收藏加入行程 fast-path(`/favorites`,`/explore`,`/favorites/:id/add-to-trip`;favorites tab 由 placeholder 轉正)(**Completed:** feature/favorites-explore)
- [x] Explore direct-mode 加入行程(`/add-to-trip?place_id=...`;不需先收藏)(**Completed:** feature/favorites-explore)
- [ ] Entry CRUD 表單群(`/trips/:id/add-entry`,`add-stop`,`add-custom-stop`,`stop/:entryId/edit/change-poi/copy/move`;已完成 `/trips/:id/add-entry` 搜尋/收藏/自訂座標新增 slice、`/trips/:id/stop/:entryId/edit` 時間/描述/刪除 slice、`/trips/:id/stop/:entryId/change-poi` 主景點置換/加備選 slice、`/trips/:id/stop/:entryId/copy` 與 `/move` 跨日複製/移動 slice、edit screen 備選移除/排序 slice、timeline travel segments edit slice；edit/move/segments 已帶 OCC `expectedVersion`,POI 變更已帶 `entryPoisVersion`,409 `STALE_ENTRY` 已重抓 entry/segments 並 retry 一次；後續仍可補更多 web parity 細節)
- [x] 建立/編輯行程(`/trips/new`,`/trips/:id/edit`;行程基本資料、目的地、日期、語言、發布狀態表單與 edit day management:prepend/append/insert/delete/shift)(**Completed:** feature/favorites-explore)
- [x] AI 聊天(`/chat`;chat tab 轉正;request queue + pending/polling)(**Completed:** feature/favorites-explore)
- [x] 全域地圖(`/map`;map tab 轉正,以 trip picker 重用行程地圖內容)(**Completed:** feature/favorites-explore)
- [x] 共編邀請(`/trips/:id/collab`,`/invite`;成員/待邀請讀取、新增 member/viewer 邀請、撤回 pending invitation、既有成員 member/viewer role update、移除非 owner 成員、公開邀請預覽與 email 相符接受)(**Completed:** feature/favorites-explore)
- [x] 行程筆記 CRUD + AI generate(`/trips/:id/notes`;5 區新增/編輯/刪除與 AI generate/polling 第一波)(**Completed:** feature/favorites-explore)
- [x] AI 健檢報告(`/trips/:id/health`;GET/POST health-check、severity 分組、reports polling 第一波)(**Completed:** feature/favorites-explore)
- [x] Auth 補齊(`/signup`,`/signup/check-email`,`/login/forgot`,`/auth/password/reset`,`/auth/verify-email`;signup session cookie、重寄驗證信、忘記/重設密碼、user-gesture email verify 第一波)(**Completed:** feature/favorites-explore)

## P0 parity debt

- [x] TripsListScreen 補 web parity:分類 tabs/排序/搜尋/filtered empty/TripCard action menu/尾端新增卡/JSON 匯入/分享連結管理(**Completed:** feature/favorites-explore)
- [ ] TripTimelineScreen 補 web parity:segment 背景同步細節（offline banner、focus deep link、scroll-spy active day、今日自動定位、overflow actions 已完成）
- [x] TripMapScreen 補 web parity:focus route、overview pin day switch、pin-card 雙向同步、polyline、定位/圖層 FAB(**Completed:** feature/favorites-explore)
- [x] AccountScreen 補 web parity:displayName inline edit、外觀/通知 row 實際導航與 `/account/*`、`/settings/*` alias 第一波(**Completed:** feature/favorites-explore)

## P2

- [ ] 公開分享頁/列印/JSON 匯出(`/s/:token`,`/trips/:id/print`,PDF/JSON 匯出)
- [ ] 設定子頁後續：sessions、connected apps、developer apps、OAuth consent（外觀/通知第一波已完成）
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
