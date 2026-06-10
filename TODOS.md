# TODOS

待辦範圍以 [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md) 的 P1/P2 規劃為準;此檔追蹤執行狀態。新增功能一律走 TDD + feature branch(見 [CONTRIBUTING.md](CONTRIBUTING.md))。

## P1(第二波)

- [ ] 收藏 + 探索(favorites tab 由 placeholder 轉正,對應 web Explore)
- [ ] Entry CRUD 表單群(新增/編輯/刪除停留點;OCC `expectedVersion`,409 `STALE_ENTRY` 重抓再套用)
- [ ] 建立/編輯行程(行程基本資料表單)
- [ ] AI 聊天(chat tab 轉正;request queue)
- [ ] 全域地圖(map tab 轉正,跨行程 POI)
- [ ] 共編邀請(成員管理)
- [ ] 行程筆記 CRUD(5 區由唯讀轉可編輯)

## P2

- [ ] 分享/列印/匯入
- [ ] 設定子頁
- [ ] OAuth PKCE + Bearer 認證(需後端註冊 public client;取代 session cookie + 偽造 Origin 的過渡方案)
- [ ] 離線快取

## 技術債

- [ ] `--dart-define=TRIPLINE_API_URL` base URL 覆寫(PORTING_PLAN 規劃項,尚未實作;目前僅能以 `ApiClient(origin:)` 建構參數覆寫)
- [ ] 地圖介面抽象化(PORTING_PLAN 決策:保留之後換 google_maps_flutter 的空間;目前 flutter_map 直接用在 TripMapScreen)

## Completed

- [x] P0:登入/行程清單/時間軸/地圖/筆記/帳號 + 5-tab shell(**Completed:** v0.1.0, 2026-06-10)
- [x] 基礎層:tokens/theme、models、API client、providers(**Completed:** v0.1.0, 2026-06-10)
- [x] Diataxis 文件 9 篇 + CLAUDE.md + 標準專案文件(**Completed:** v0.1.0, 2026-06-10)
