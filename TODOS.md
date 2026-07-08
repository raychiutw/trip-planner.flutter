# TODOS

待辦範圍以 [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md) 的 P1/P2 規劃為準;此檔追蹤執行狀態。新增功能一律走 TDD + feature branch(見 [CONTRIBUTING.md](CONTRIBUTING.md))。

## P1(第二波)

P1 全數完成 🎉(見 Completed)。

## P2

- [x] 分享/列印/匯入:**公開分享頁 + 複製公開行程、列印/PDF 預覽、JSON 匯入/匯出 已完成**。
- [~] 設定子頁:**外觀、個人資料、登入裝置、已連結 OAuth app、開發者 OAuth app 已完成**;通知仍延後。
- [~] OAuth PKCE + Bearer 認證:**client 端、登入按鈕、consent 頁、connected/developer app 管理已完成 + 單測**(pkce/token/refresh/Bearer ApiClient/loopback 編排),預設關閉(`--dart-define` 啟用)。**e2e 待 backend owner provision active public client + loopback redirect**(見 `docs/howto-oauth-pkce.md`)。
- [x] 離線快取:讀取快取、離線寫入佇列、flush、OCC rebase/conflict UI 已完成。

## 技術債

- [x] v0.1.0 PR merge 後在 master 補打 `git tag v0.1.0` 並 push(**Completed:** 2026-06-10)
- [x] `--dart-define=TRIPLINE_API_ORIGIN` base URL 覆寫(**Completed:** 2026-06-10)
- [x] 地圖介面抽象化(PORTING_PLAN 決策:保留之後換 google_maps_flutter 的空間;`TripMapScreen`/`GlobalMapScreen` 已改走 `features/map/map_adapter.dart`)

## Completed

- [x] 建立/編輯行程:目的地優先 POI 建立(固定/彈性日期 + 每地天數)+ 編輯(PUT 欄位,明確儲存)(**Completed:** 2026-06-12)
- [x] P2 分享/列印/匯入:公開分享頁 `/s/:token` + clone、行程列印/PDF 預覽、JSON import/export(**Completed:** 2026-07-08)
- [x] P2 帳號安全與 OAuth 設定:登入裝置、connected apps、developer apps、OAuth consent shell route(**Completed:** 2026-07-08)
- [x] 地圖 adapter:`TripMapPoint`/`FlutterMapCanvas` 抽象化,保留之後替換地圖 SDK 的空間(**Completed:** 2026-07-08)
- [x] 全域地圖(map tab 轉正):收藏 POI 跨行程 flutter_map(依 poi_type 上色 + 點選資訊卡)(**Completed:** 2026-06-12)
- [x] 共編邀請(成員管理):成員/角色/移除 + 待接受邀請撤銷 + email 邀請(`/permissions` + `/invitations`)(**Completed:** 2026-06-12)
- [x] AI 聊天(chat tab 轉正):工單佇列(`POST /api/requests` + polling)+ markdown 回覆 + deep-link 映射 + 行程下拉(預設最近)+ 三方氣泡;completed 後 invalidate 行程 providers(**Completed:** 2026-06-11)
- [x] 行程筆記 CRUD:5 區（航班/住宿/預訂/行前須知/緊急聯絡）新增/編輯/刪除 + 每區拖曳排序(spec-driven 表單 + 泛型 repository,OCC `expectedVersion`)(**Completed:** 2026-06-11)
- [x] Entry CRUD 表單群:編輯/刪除/新增停留點 + 拖曳排序/跨天搬移 + 地點管理（master/alternates/per-POI）+ 交通編輯;三套 OCC、409 `STALE_ENTRY` 重抓(**Completed:** 2026-06-11)
- [x] 收藏 + 探索:收藏清單 + 探索（poi-search/find-or-create）+ 加入行程（favorite/direct mode、409 conflict）(**Completed:** 2026-06-11)
- [x] P0:登入/行程清單/時間軸/地圖/筆記/帳號 + 5-tab shell(**Completed:** v0.1.0, 2026-06-10)
- [x] 基礎層:tokens/theme、models、API client、providers(**Completed:** v0.1.0, 2026-06-10)
- [x] Diataxis 文件 9 篇 + CLAUDE.md + 標準專案文件(**Completed:** v0.1.0, 2026-06-10)
