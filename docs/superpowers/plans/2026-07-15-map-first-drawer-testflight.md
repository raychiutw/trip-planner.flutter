# Tripline Final HIG Redesign — Temporary TestFlight Checklist

> 狀態：暫存發佈清單。Apple 完成處理後刪除本檔；它不是設計權威。

## Authority

- `docs/design-sessions/2026-07-17-tripline-final.html`
- `docs/discovery/design.md`

## Completed implementation

- [x] 最終 Light／Dark mockup 集中為一份 HTML，舊 process SVG 與重複 spec 已移除。
- [x] root tab 收斂為聊天／行程／地圖／收藏；帳號位於 shell 外並提供右上 44pt close。
- [x] 聊天、行程、地圖共用行程切換 sheet 與右上帳號入口。
- [x] 行程使用「地圖＋DAY」、地圖使用「行程＋DAY」；互切 root branch 並保留 DAY。
- [x] 每日與無座標日期 zoom 固定 `12.0`，POI focus 為 `16.0`，不做全行程 bounds fit。
- [x] POI 使用相同中性卡片、水平 `viewportFraction = 0.84`，並避讓浮動 root tab。
- [x] 收藏、設定與共用色彩移除 sage／pink／brown 類型上色。
- [x] `VERSION`／`pubspec.yaml`／`CHANGELOG.md` 更新為 `0.9.0`。
- [x] `dart format lib test` 無變更。
- [x] `flutter analyze --no-fatal-infos`：0 error、0 warning；僅 3 個既有 deprecated info。
- [x] `flutter test`：1119 tests passed。
- [x] `flutter build ios --release --no-codesign` 完成。
- [x] iPhone 17 Pro simulator 驗證啟動畫面 Light／Dark。

## Remaining release steps

- [ ] `git diff --check`，commit 並 push `feat/android-play-closed-testing`。
- [ ] 建立 PR 到 `master`，等待 required checks 後 merge。
- [ ] 從 `master` 觸發：

  ```sh
  gh workflow run mobile.yml --ref master -f release_target=testflight
  ```

- [ ] 監看同一 run 通過 analyze、test、簽章、IPA build、upload 與 Apple processing。
- [ ] Apple processing 完成後刪除本檔，commit 並 push 最終文件清理。

舊 TestFlight run 不算完成；必須是本次合併後的新 run。
