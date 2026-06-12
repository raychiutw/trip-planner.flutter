# TODOS

待辦範圍以 [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md) 的 P1/P2 規劃為準;此檔追蹤執行狀態。新增功能一律走 TDD + feature branch(見 [CONTRIBUTING.md](CONTRIBUTING.md))。

## P1(第二波)

P1 全數完成 🎉(見 Completed)。

## P2

- [~] 分享/列印/匯入:**分享(公開連結)已完成**(建立/清單/撤銷 + 複製 URL);列印/匯入未做。
- [ ] 設定子頁
- [~] OAuth PKCE + Bearer 認證:**client 端已完成 + 單測**(pkce/token/refresh/Bearer ApiClient/loopback 編排),預設關閉(`--dart-define` 啟用)。**e2e 待 backend owner provision active public client + loopback redirect**(見 `docs/howto-oauth-pkce.md`)。登入頁 OAuth 按鈕待接。
- [ ] 離線快取

## 技術債

- [x] v0.1.0 PR merge 後在 master 補打 `git tag v0.1.0` 並 push(**Completed:** 2026-06-10)
- [x] `--dart-define=TRIPLINE_API_ORIGIN` base URL 覆寫(**Completed:** 2026-06-10)
- [ ] 地圖介面抽象化(PORTING_PLAN 決策:保留之後換 google_maps_flutter 的空間;目前 flutter_map 直接用在 TripMapScreen)

## Completed

- [x] 建立/編輯行程:目的地優先 POI 建立(固定/彈性日期 + 每地天數)+ 編輯(PUT 欄位,明確儲存)(**Completed:** 2026-06-12)
- [x] 全域地圖(map tab 轉正):收藏 POI 跨行程 flutter_map(依 poi_type 上色 + 點選資訊卡)(**Completed:** 2026-06-12)
- [x] 共編邀請(成員管理):成員/角色/移除 + 待接受邀請撤銷 + email 邀請(`/permissions` + `/invitations`)(**Completed:** 2026-06-12)
- [x] AI 聊天(chat tab 轉正):工單佇列(`POST /api/requests` + polling)+ markdown 回覆 + deep-link 映射 + 行程下拉(預設最近)+ 三方氣泡;completed 後 invalidate 行程 providers(**Completed:** 2026-06-11)
- [x] 行程筆記 CRUD:5 區（航班/住宿/預訂/行前須知/緊急聯絡）新增/編輯/刪除 + 每區拖曳排序(spec-driven 表單 + 泛型 repository,OCC `expectedVersion`)(**Completed:** 2026-06-11)
- [x] Entry CRUD 表單群:編輯/刪除/新增停留點 + 拖曳排序/跨天搬移 + 地點管理（master/alternates/per-POI）+ 交通編輯;三套 OCC、409 `STALE_ENTRY` 重抓(**Completed:** 2026-06-11)
- [x] 收藏 + 探索:收藏清單 + 探索（poi-search/find-or-create）+ 加入行程（favorite/direct mode、409 conflict）(**Completed:** 2026-06-11)
- [x] P0:登入/行程清單/時間軸/地圖/筆記/帳號 + 5-tab shell(**Completed:** v0.1.0, 2026-06-10)
- [x] 基礎層:tokens/theme、models、API client、providers(**Completed:** v0.1.0, 2026-06-10)
- [x] Diataxis 文件 9 篇 + CLAUDE.md + 標準專案文件(**Completed:** v0.1.0, 2026-06-10)
