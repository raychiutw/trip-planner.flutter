# TODOS

待辦範圍以 [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md) 的 P1/P2 規劃為準;此檔追蹤執行狀態。新增功能一律走 TDD + feature branch(見 [CONTRIBUTING.md](CONTRIBUTING.md))。

## P1(第二波)

- [x] 收藏 + 探索 + 收藏加入行程 fast-path(`/favorites`,`/explore`,`/favorites/:id/add-to-trip`;favorites tab 由 placeholder 轉正)(**Completed:** feature/favorites-explore)
- [x] Explore direct-mode 加入行程(`/add-to-trip?place_id=...`;不需先收藏)(**Completed:** feature/favorites-explore)
- [x] Entry CRUD 表單群(`/trips/:id/add-entry`,`add-stop`,`add-custom-stop`,`stop/:entryId/edit/change-poi/copy/move`;搜尋/收藏/自訂座標新增、時間/描述/刪除、主景點置換/加備選、copy/move 跨日操作、備選移除/排序、timeline travel segments edit；edit/move/segments 已帶 OCC `expectedVersion`,POI 變更已帶 `entryPoisVersion`,409 `STALE_ENTRY` 已重抓 entry/segments 並 retry 一次)(**Completed:** feature/favorites-explore)
- [x] 建立/編輯行程(`/trips/new`,`/trips/:id/edit`;行程基本資料、目的地、日期、語言、發布狀態表單與 edit day management:prepend/append/insert/delete/shift)(**Completed:** feature/favorites-explore)
- [x] AI 聊天(`/chat`;chat tab 轉正;request queue + pending/polling)(**Completed:** feature/favorites-explore)
- [x] 全域地圖(`/map`;map tab 轉正,以 trip picker 重用行程地圖內容)(**Completed:** feature/favorites-explore)
- [x] 共編邀請(`/trips/:id/collab`,`/invite`;成員/待邀請讀取、新增 member/viewer 邀請、撤回 pending invitation、既有成員 member/viewer role update、移除非 owner 成員、公開邀請預覽與 email 相符接受)(**Completed:** feature/favorites-explore)
- [x] 行程筆記 CRUD + AI generate(`/trips/:id/notes`;5 區新增/編輯/刪除與 AI generate/polling 第一波)(**Completed:** feature/favorites-explore)
- [x] AI 健檢報告(`/trips/:id/health`;GET/POST health-check、severity 分組、reports polling 第一波)(**Completed:** feature/favorites-explore)
- [x] Auth 補齊(`/signup`,`/signup/check-email`,`/login/forgot`,`/auth/password/reset`,`/auth/verify-email`;signup session cookie、重寄驗證信、忘記/重設密碼、user-gesture email verify 第一波)(**Completed:** feature/favorites-explore)

## P0 parity debt

- [x] TripsListScreen 補 web parity:分類 tabs/排序/搜尋/filtered empty/TripCard action menu/尾端新增卡/JSON 匯入/匯出/分享連結管理(**Completed:** feature/favorites-explore)
- [x] TripTimelineScreen 補 web parity:focus deep link、scroll-spy active day、今日自動定位、overflow actions(編輯/AI 健檢/共編/分享連結)、offline banner、segment 背景同步細節、行程切換 dropdown(**Completed:** feature/favorites-explore)
- [x] TripMapScreen 補 web parity:focus route、overview pin day switch、pin-card 雙向同步、polyline、定位/圖層 FAB(**Completed:** feature/favorites-explore)
- [x] AccountScreen 補 web parity:displayName inline edit、外觀/通知 row 實際導航與 `/account/*`、`/settings/*` alias 第一波(**Completed:** feature/favorites-explore)

## P2

- [x] 公開分享頁第一波(`/s/:token`;未登入可讀公開 payload,登入後可 clone)(**Completed:** feature/favorites-explore)
- [x] 列印/PDF 第一波(`/trips/:id/print`;預覽 + 平台列印 + 分享 PDF,JSON 匯出已完成)(**Completed:** feature/favorites-explore)
- [x] 設定子頁後續：connected apps、developer apps、OAuth consent（列出/撤銷已連結應用、developer app 清單/建立、consent allow/deny 第一波；外觀/通知與登入裝置 sessions 已完成）(**Completed:** feature/favorites-explore)
- [ ] OAuth PKCE + Bearer 認證(**Blocked:** 需後端註冊 public client / native redirect scheme,才能完整取代 session cookie + Origin 過渡方案)
- [x] 離線快取第一波（Repository read-through JSON cache：`/my-trips`、`/trips`、trip detail、days、segments、notes；5xx/網路錯誤時回退本機快取，401/403 不遮蔽）(**Completed:** feature/favorites-explore)

## 技術債

- [ ] v0.1.0 PR merge 後在 master 補打 `git tag v0.1.0` 並 push — CHANGELOG 的 compare/release 連結目前指向尚不存在的 tag(**Blocked:** 需 PR merge 到 master 後執行)
- [x] `--dart-define=TRIPLINE_API_URL` base URL 覆寫（可傳 origin 或完整 `/api` URL；Origin header 取 scheme/host/port）(**Completed:** feature/favorites-explore)
- [x] 地圖介面抽象化（`features/map/map_adapter.dart` 集中 `flutter_map` adapter；TripMap / AddEntry 畫面改用 `TripMapPoint`、`TripMapRoute`、`TripMapMarker`）(**Completed:** feature/favorites-explore)

## Completed

- [x] P0:登入/行程清單/時間軸/地圖/筆記/帳號 + 5-tab shell(**Completed:** v0.1.0, 2026-06-10)
- [x] 基礎層:tokens/theme、models、API client、providers(**Completed:** v0.1.0, 2026-06-10)
- [x] Diataxis 文件 9 篇 + CLAUDE.md + 標準專案文件(**Completed:** v0.1.0, 2026-06-10)
