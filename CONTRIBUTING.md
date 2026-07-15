# 貢獻指南

個人專案,但流程照團隊標準走。讀完這頁就能開工;深入細節都在 [README 文件索引](README.md#文件)。

## 環境

```bash
flutter --version    # 需 Flutter 3.41+ / Dart 3.11.3+（pubspec: sdk ^3.11.3）
flutter pub get
flutter test         # 全綠才算環境就緒；數量以當次輸出為準
```

完整上手流程(含跑 app、走一輪 TDD)見[新手教學](docs/tutorial-getting-started.md)。

## 開發流程

1. **開 feature branch** — 不直接 commit 到 `master`(base branch 是 `master`,無 `main`)
2. **TDD 紅綠重構** — 任何 production code 變更先寫失敗測試;修 bug 先寫重現測試。具體手法見 [How to 用 provider override 寫測試](docs/howto-test-with-providers.md)
3. **完成定義** — `flutter analyze` 零 error/warning、`flutter test` 全綠、新增 public class/method 有 `///` 文件註解
4. **開 PR** — commit message 與 PR 一律繁體中文(台灣用語),技術名詞保留英文
5. **同步文件** — 動到 public surface(model 欄位、repository 方法、路由、token)時,對應的 `docs/reference-*.md` 跟著更新;使用者可感知的變更補進 `CHANGELOG.md` 的 `[Unreleased]`

## 常見任務入口

| 任務 | 文件 |
|---|---|
| 新增 API endpoint(model + repository) | [howto-add-endpoint](docs/howto-add-endpoint.md) |
| 新增畫面/路由 | [howto-add-screen](docs/howto-add-screen.md) |
| 寫測試(假資料注入) | [howto-test-with-providers](docs/howto-test-with-providers.md) |
| 了解設計取捨 | [explanation-architecture](docs/explanation-architecture.md) |
| 了解自適應 UI 與 Apple Music/HIG 對標 | [explanation-adaptive-ui](docs/explanation-adaptive-ui.md) |

## 不可妥協的慣例

- mutating request 一律走 `ApiClient`(它負責 `Origin` CSRF header)— 不要用 raw dio 打 API
- fromJson 遵守[通用解析規則](docs/reference-models.md#通用解析規則)(camelCase、num 轉型、0/1 bool)
- UI 變更遵守[設計系統參考](docs/reference-theme.md)：取色走 `colorScheme`/`TpTones`、平台差異走 `app/adaptive.dart`、寬版內容走 `AppAdaptiveContent`
- 成功或低風險狀態用 `showAppNotice`；真正錯誤用可關閉、可重試的 `showAppError`，不可用短暫 toast 取代
- 待辦進 [TODOS.md](TODOS.md),範圍變更先改 [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md)
