# 自訂探索地區提交與關閉驗證（#372）

- 基準：`671312fbd937c58d9f236840cbb1b20f3aa2e93b`（`feat/372-custom-region-guard-verification` 建立時）。
- 重現缺陷：開啟探索的「自訂地區…」，輸入「大阪」後按鍵盤 Done。原本只執行 `AppSheetFormController.submit()` 的檢查，沒有走 sheet 標題列「切換」的完成與關閉流程，因此地區仍為「全部地區」。新增的公開畫面測試先以此結果失敗，紀錄在 `/tmp/372-red.log`。
- 修正：由 `showAppFormSheet` 把提交、清除 dirty 與關閉 sheet 集中為 controller 的 `requestSubmit()`；鍵盤 Done 與標題列「切換」使用同一流程。sheet 結束時解除回呼，避免重用 controller 指向已關閉的 sheet。
- 回歸：Done 輸入前後空白的「大阪」後，地區切為大阪並關閉；重新開啟輸入「京都」後往下拖曳，仍顯示捨棄確認；按取消保留京都草稿與原大阪篩選。焦點測試與共用 sheet 測試共 52 個通過。
- 檢查：`flutter analyze --no-pub` 為 `No issues found`；完整 `flutter test --no-pub` 共 2222 個測試通過（2026-09-26，執行紀錄：`/tmp/372-full.log`）。Standards 審查沒有發現問題；Spec 的實機條件仍待完成。
- 實機界線：widget test 模擬 `TextInputAction.done` 與 sheet 拖曳，尚未以外接鍵盤和真機手勢操作；本票的 P3 裝置驗收仍待指定最終版本的裝置、OS、鍵盤、操作與畫面證據。
