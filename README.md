# Tripline Flutter

[trip-planner](https://github.com/raychiutw/trip-planner) React SPA 的 **iOS / Android 移植版**。後端共用同一套 Cloudflare Pages Functions API（`https://trip-planner-dby.pages.dev/api`），本 repo 只是另一個 client。

## 功能狀態

**P0（已完成）**
- 登入（email/密碼 → `tripline_session` cookie，flutter_secure_storage 持久化）
- 5-tab shell（聊天 / 行程 / 地圖 / 收藏 / 帳號）— go_router StatefulShellRoute + auth redirect
- 行程清單（三色 tone 卡片、pull-to-refresh、分類/搜尋/排序、action menu、filtered empty、尾端新增卡、JSON 匯入）
- 行程時間軸（day pills、逐日 timeline、三色 POI tone、travel pill、hotel 卡）
- 行程地圖（flutter_map + OSM、逐日 pin、day tabs、entry cards 同步）
- 行程筆記（航班/住宿/預訂/行前/緊急 5-section accordion，新增/編輯/刪除與 AI 生成第一波）
- AI 健檢（行程層級報告、severity 分組、pending polling）
- Auth 補齊（註冊、查看信箱/重寄驗證信、忘記/重設密碼、Email 驗證）
- 帳號（profile、統計、登出）

**P1（進行中）**：收藏 + 探索 + 加入行程 fast-path（含 direct-mode）已完成第一波；建立/編輯行程已完成基本資料、目的地與 edit day management（新增/補缺日/刪除/平移日期）slice；Entry CRUD 已完成 `/trips/:id/add-entry` 搜尋/收藏/自訂座標新增 slice、`/trips/:id/stop/:entryId/edit` 時間/描述/刪除 slice、`/trips/:id/stop/:entryId/change-poi` 主景點置換/加備選 slice、`/trips/:id/stop/:entryId/copy` 與 `/move` 跨日複製/移動 slice、edit screen 備選移除/排序 slice、travel segments edit slice，並支援 `STALE_ENTRY` 重抓 retry；AI 聊天 request queue + polling、全域地圖 tab resolver、共編邀請/成員管理、行程筆記 CRUD + AI generate、AI 健檢報告、Auth 補齊已完成第一波。
**P2**：分享/列印/JSON 匯出、設定子頁、OAuth PKCE Bearer 認證、離線快取。

## 開發

```bash
flutter pub get
flutter test       # 全部測試
flutter analyze
flutter run        # 連 prod API（注意：請用測試帳號）
```

## 架構

```
lib/
  theme/        # design tokens（對應 web css/tokens.css）+ ThemeData + TpTones 三色 ThemeExtension
  models/       # Trip/Day/Entry/Chat/Collab/Health/Notes/User —— camelCase wire fromJson
  api/          # dio 封裝（cookie、Origin CSRF、429 retry、204）+ repositories + riverpod providers
  app/          # go_router（5-tab StatefulShellRoute + auth redirect）
  features/     # auth / chat / collab / invite / map / trips / trip_detail（timeline·map·notes）/ favorites / account / shell
docs/
  PORTING_PLAN.md   # 移植藍圖與架構決策
  CONTRACTS.md      # 模組介面契約（多 agent 平行開發用）
  discovery/        # 來源 SPA 的畫面/API/模型/設計系統調查報告
```

## 文件

| 想做什麼 | 看哪份 |
|---|---|
| 從零跑起來、走一輪 TDD | [新手教學](docs/tutorial-getting-started.md) |
| 懂整體設計與取捨 | [架構說明](docs/explanation-architecture.md) |
| 新增 API endpoint | [How to 新增 API endpoint](docs/howto-add-endpoint.md) |
| 新增畫面 | [How to 新增畫面](docs/howto-add-screen.md) |
| 寫測試（provider override） | [How to 用 provider override 寫測試](docs/howto-test-with-providers.md) |
| 查 API 層介面 | [reference-api](docs/reference-api.md) |
| 查 model 欄位與解析規則 | [reference-models](docs/reference-models.md) |
| 查 design token / 三色 tone | [reference-theme](docs/reference-theme.md) |
| 查路由表 / auth redirect | [reference-navigation](docs/reference-navigation.md) |
| 查 web→Flutter 尚未翻寫功能 | [移植缺口盤點](docs/porting-gap-audit-2026-07-08.md) |
| 貢獻流程與慣例 | [CONTRIBUTING](CONTRIBUTING.md) |
| 變更紀錄 / 待辦 | [CHANGELOG](CHANGELOG.md) · [TODOS](TODOS.md) |

技術棧：Flutter 3.41 / Dart 3.11.3（pubspec `sdk: ^3.11.3`）、flutter_riverpod 3、go_router 17、dio 5、flutter_map 8（OSM tiles，免 API key）。

## API client 關鍵行為（與 web `src/lib/apiClient.ts` 對齊）

- mutating request 一律帶 `Origin: https://trip-planner-dby.pages.dev`（後端 CSRF Origin allowlist，缺少 → 403）
- 429 讀 `Retry-After`（cap 30s）只 retry GET 一次；mutation 不 retry
- 錯誤 shape `{error:{code,message,detail}}`；204 → null

## 設計

視覺規範以 web repo 的 `DESIGN.md` + `css/tokens.css` 為 SoT：柔褐 `#A97A4A` 主色、三色系統（玩/看/買=柔褐、住/移動=sage、吃=玫瑰粉）、hairline 卡片（elevation 0）、HIG 字級、light/dark 雙主題。
