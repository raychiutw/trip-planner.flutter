# Tripline Flutter

[trip-planner](https://github.com/raychiutw/trip-planner) React SPA 的 **iOS / Android 移植版**。後端共用同一套 Cloudflare Pages Functions API（`https://trip-planner-dby.pages.dev/api`），本 repo 只是另一個 client。

## 功能狀態

**P0（已完成）**
- 登入（email/密碼 → `tripline_session` cookie，flutter_secure_storage 持久化）
- 4-tab Liquid Glass shell（聊天 / 行程 / 地圖 / 收藏）— go_router StatefulShellRoute + auth redirect；帳號由各頁右上 avatar 進入
- 行程清單（中性 grouped surface、pull-to-refresh、尾端左滑刪除，並保留長按操作）
- 行程時間軸（單層 day selector、D1 單 rail、單行起訖時間、Google 分類、travel pill）
- 行程地圖（原生 Google Maps、逐日 marker、路線 polyline、day tabs、entry cards 同步）
- 行程筆記（航班/住宿/預訂/行前/緊急 5-section accordion，支援新增、編輯、刪除與排序）
- 帳號（profile、統計、登出）

**P1（已完成）**：收藏 + 探索、Entry CRUD 表單群、建立/編輯行程、AI 聊天、全域地圖、共編邀請。
**P2（已完成）**：分享/列印/匯入、設定子頁、通知偏好 toggle、OAuth PKCE Bearer 認證（production `tripline-mobile` public client 已 provision）、離線快取。

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
  theme/        # 暖白／中性深色 design tokens + ThemeData + 語意色 ThemeExtension
  models/       # Trip/Day/Entry/Notes/User —— camelCase wire fromJson
  api/          # dio 封裝（cookie、Origin CSRF、429 retry、204）+ repositories + riverpod providers
  app/          # go_router（4-tab StatefulShellRoute + auth redirect）
  features/     # auth / trips / trip_detail（timeline·map·notes）/ account / shell
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
| 改連本機後端 | [How to 指向本機後端](docs/howto-local-backend.md) |
| 啟用 OAuth PKCE | [How to 啟用 OAuth PKCE](docs/howto-oauth-pkce.md) |
| 寫測試（provider override） | [How to 用 provider override 寫測試](docs/howto-test-with-providers.md) |
| 跑 Patrol／Firebase Test Lab 外部裝置證據 | [Mobile E2E automation](docs/mobile-e2e.md) |
| 查 API 層介面 | [reference-api](docs/reference-api.md) |
| 查 model 欄位與解析規則 | [reference-models](docs/reference-models.md) |
| 查設計 token / 自適應 UI 規格 | [reference-theme](docs/reference-theme.md) |
| 理解 Apple Music / Apple HIG 對標取捨 | [自適應 UI 設計理由](docs/explanation-adaptive-ui.md) |
| 查路由表 / auth redirect | [reference-navigation](docs/reference-navigation.md) |
| 貢獻流程與慣例 | [CONTRIBUTING](CONTRIBUTING.md) |
| 變更紀錄 / 待辦 | [CHANGELOG](CHANGELOG.md) · [TODOS](TODOS.md) |

技術棧：Flutter 3.44.6 / Dart 3.11.3（pubspec `sdk: ^3.11.3`）、flutter_riverpod 3、go_router 17、dio 5、google_navigation_flutter 0.10。

## API client 關鍵行為（與 web `src/lib/apiClient.ts` 對齊）

- mutating request 一律帶 `Origin: https://trip-planner-dby.pages.dev`（後端 CSRF Origin allowlist，缺少 → 403）
- 429 讀 `Retry-After`（cap 30s）只 retry GET 一次；mutation 不 retry
- 錯誤 shape `{error:{code,message,detail}}`；204 → null

## 設計

Flutter 的互動與版型以本 repo 的 [設計系統參考](docs/reference-theme.md)為準。方向是保留 Tripline 柔褐品牌，以暖白／中性深色 surface、Apple Music 的內容階層、Liquid Glass 功能層與 Apple HIG 平台慣例呈現；舊三色內容分類已退場。
