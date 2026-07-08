# Changelog

本專案的重要變更紀錄。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/),版本依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

### 新增

- **P1 收藏/探索**:`/favorites` 改成真收藏清單,支援取消收藏、usage badge 與加入行程入口;新增 `/explore` 搜尋 POI、加入/取消收藏;新增 `/favorites/:id/add-to-trip` 以 4-field fast-path 將收藏排入行程;補上 `/add-to-trip?place_id=...` direct-mode,可不先收藏就從搜尋結果排入行程並觸發 travel recompute。
- **P1 新增景點**:新增 `/trips/:tripId/add-entry` 與 `/trips/:tripId/add-stop` 相容入口;時間軸 AppBar 可進入新增景點表單,支援搜尋 POI 或收藏 POI 加入指定 day,成功後觸發 travel recompute。
- **P1 Entry 編輯**:新增 `/trips/:tripId/stop/:entryId/edit`;時間軸 entry 可進入編輯表單,支援讀取單一 entry、修改開始/結束時間與描述、刪除景點,更新時帶 `expectedVersion`,成功後觸發 travel recompute。
- **P1 Entry POI 變更**:新增 `/trips/:tripId/stop/:entryId/change-poi`;可用搜尋結果或收藏 POI 置換主景點,也可從 edit screen 加入備選景點,POI 變更帶 `entryPoisVersion` 避免覆蓋他人操作。
- **P1 Entry 跨日操作**:新增 `/trips/:tripId/stop/:entryId/copy` 與 `/move`;edit screen 可進入複製/移動表單,copy 呼叫後端 copy endpoint,move 以 `day_id` + `expectedVersion` PATCH entry,成功後重算受影響 day 的 travel segments。
- **P1 Entry 備選管理**:edit screen 顯示備選 POI 列表,支援移除與上/下移排序;移除以 DELETE query string 帶 `entryPoisVersion`,排序以 PATCH `/alternates/reorder` 帶完整 `order` 與 OCC token。
- **P1 Entry OCC 重試**:edit、move、change-poi 與備選管理遇 `STALE_ENTRY` 時會重抓最新 entry,以新的 `version` / `entryPoisVersion` retry 同一個使用者操作一次。

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
