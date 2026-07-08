# Changelog

本專案的重要變更紀錄。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/),版本依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

### 新增

- **P0 帳號頁 parity**:AccountScreen 新增 displayName inline 編輯；失焦或送出會呼叫 `PATCH /account/profile`，成功後同步刷新全域登入使用者狀態，空白會清除顯示名稱，失敗時保留欄位錯誤。
- **P0 行程清單 parity**:TripsList 新增分類 tabs（全部/我的/共編/已歸檔）、搜尋、排序（最新編輯/出發日近/名稱）、filtered empty、TripCard action menu（編輯/共編/AI 健檢/筆記/分享/刪除）、尾端新增卡、JSON 匯入（512KB/schemaVersion 1 檢查）與分享連結管理（列出/建立/編輯/重新產生/關閉/刪除）；`TripSummary` 解析 owner/role/countries/start/end/updated/member/archive 等 `/my-trips` rich fields。
- **P1 收藏/探索**:`/favorites` 改成真收藏清單,支援取消收藏、usage badge 與加入行程入口;新增 `/explore` 搜尋 POI、加入/取消收藏;新增 `/favorites/:id/add-to-trip` 以 4-field fast-path 將收藏排入行程;補上 `/add-to-trip?place_id=...` direct-mode,可不先收藏就從搜尋結果排入行程並觸發 travel recompute。
- **P1 建立/編輯行程**:新增 `/trips/new` 與 `/trips/:tripId/edit`;TripsList AppBar/空狀態可建立行程,長按卡片可進入編輯行程,支援基本資料、目的地、日期、語言與發布狀態送出。編輯模式已接上 day management,可前/後新增行程日、補回缺漏日期、刪除 day 前顯示景點影響範圍,並以新的 Day 1 日期平移整段行程。
- **P1 新增景點**:新增 `/trips/:tripId/add-entry`、`/trips/:tripId/add-stop` 與 `/add-custom-stop` 相容入口;時間軸 AppBar 可進入新增景點表單,支援搜尋 POI、收藏 POI 或自訂地圖座標加入指定 day,成功後觸發 travel recompute。
- **P1 Entry 編輯**:新增 `/trips/:tripId/stop/:entryId/edit`;時間軸 entry 可進入編輯表單,支援讀取單一 entry、修改開始/結束時間與描述、刪除景點,更新時帶 `expectedVersion`,成功後觸發 travel recompute。
- **P1 Entry POI 變更**:新增 `/trips/:tripId/stop/:entryId/change-poi`;可用搜尋結果或收藏 POI 置換主景點,也可從 edit screen 加入備選景點,POI 變更帶 `entryPoisVersion` 避免覆蓋他人操作。
- **P1 Entry 跨日操作**:新增 `/trips/:tripId/stop/:entryId/copy` 與 `/move`;edit screen 可進入複製/移動表單,copy 呼叫後端 copy endpoint,move 以 `day_id` + `expectedVersion` PATCH entry,成功後重算受影響 day 的 travel segments。
- **P1 Entry 備選管理**:edit screen 顯示備選 POI 列表,支援移除與上/下移排序;移除以 DELETE query string 帶 `entryPoisVersion`,排序以 PATCH `/alternates/reorder` 帶完整 `order` 與 OCC token。
- **P1 Travel segments 編輯**:時間軸 travel pill 會讀取 `GET /trips/:id/segments` 作為 source of truth,可調整 driving / walking / transit;transit 需手填 1-1440 分鐘,mutation 以 `PATCH /segments/:sid` 帶 `expectedVersion`,成功後重新整理 segments 與 days。
- **P1 Entry OCC 重試**:edit、move、change-poi、備選管理與 travel segments edit 遇 `STALE_ENTRY` 時會重抓最新 entry/segments,以新的 `version` / `entryPoisVersion` retry 同一個使用者操作一次。
- **P1 AI 聊天**:`/chat` 由 placeholder 轉為 `ChatScreen`;會載入使用者行程、顯示 active trip 最近 request history、送出 `POST /requests` 後以 pending bubble 顯示「思考中...」並 polling `GET /requests/:id` 替換成 AI 回覆。
- **P1 全域地圖**:`/map` 由 placeholder 轉為 `GlobalMapScreen`;會載入我的行程、預設第一趟行程並可切換行程,重用 `TripMapContent` 顯示 OSM pins/day tabs/entry cards;無行程時提供新增行程 CTA。
- **P1 共編邀請**:新增 `/trips/:tripId/collab` 與 `/invite?token=...` 第一波;共編頁可讀取成員與 pending invitations、送出 member/viewer 邀請、撤回 pending 邀請、調整既有非 owner 成員角色並移除成員;邀請頁支援公開預覽、未登入登入 CTA、登入 email 相符後接受邀請並進入行程。
- **P1 行程筆記**:`/trips/:tripId/notes` 由唯讀 accordion 升級為 CRUD 第一波;5 區可新增/編輯/刪除 row,mutation 帶 notes row `expectedVersion`,行前須知與緊急聯絡可觸發 AI generate 並 polling request 狀態後重新整理。
- **P1 AI 健檢**:新增 `/trips/:tripId/health`;可讀取最新 health report、觸發 `POST /trips/:id/health-check`、pending 時 polling report,完成後依 high/medium/low 分組顯示 findings 並可導向 Day 或景點編輯頁。
- **P1 Auth 補齊**:新增 `/signup`、`/signup/check-email`、`/login/forgot`、`/auth/password/reset`、`/auth/verify-email`;支援 signup 讀 `Set-Cookie` 建立 session、best-effort 寄/重寄驗證信、忘記/重設密碼與 user-gesture email verification。

## [0.1.0] - 2026-06-10

P0 里程碑:trip-planner 的 iOS/Android 唯讀版可用 — 登入後能瀏覽自己的行程、逐日時間軸、地圖與筆記,資料與 web 版完全同步(共用同一套後端)。

### 新增

- **登入**:email/密碼登入,session 以 flutter_secure_storage 持久化,重開 app 免重登
- **5-tab shell**:聊天/行程/地圖/收藏/帳號底部導航,各 tab 保留瀏覽狀態;未登入自動導向登入頁
- **行程清單**:三色 tone 卡片、下拉更新、長按刪除(二次確認)
- **行程時間軸**:day pills 換日、逐日 timeline(三色 POI tone、travel pill、hotel 卡)
- **行程地圖**:flutter_map + OSM(免 API key)、逐日 pin 配色、day tabs 與 entry cards 同步
- **行程筆記**:航班/住宿/預訂/行前/緊急聯絡 5-section accordion(唯讀)
- **帳號**:profile、行程統計、登出
- **基礎層**:design tokens + light/dark 雙主題、手寫 fromJson models、dio API client(cookie 認證、CSRF Origin、429 retry、204 處理)
- **測試**:TDD 全程,144 tests(models 解析/API client 行為/widget)

### 文件

- Diataxis 四象限文件 9 篇(新手教學、3 篇 how-to、4 篇 reference、架構說明),README 文件索引
- 專案 CLAUDE.md(agent 開發指南)
- PORTING_PLAN/CONTRACTS 與實作同步(riverpod 3.x、歷史契約標註)

[Unreleased]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/raychiutw/trip-planner.flutter/releases/tag/v0.1.0
