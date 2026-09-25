# 收藏篩選大量選項驗證（#371）

- 基準：`263dd058d75e4da5d3433870776533ce0309bc48`（`feat/371-favorites-filter-scroll` 建立時）。
- 測試環境：Flutter widget test，320 × 568pt，文字縮放 200%。資料含沖繩、京都、大阪、東京、釜山、首爾、台北、其他共八個地區，每個地區一筆收藏。
- 重現：開啟收藏篩選，捲到表單底部，確認「重設」與「套用」可見；套用東京後再次開啟，改選京都，點「取消」及「捨棄」。
- 結果：可捲到底部，無 layout exception；關閉後仍顯示「已篩選：東京」與東京收藏，京都收藏未出現。驗證用例在 `test/features/favorites/favorites_screen_test.dart`，沒有修改 production code。
- 檢查：該用例通過；`flutter analyze` 為 `No issues found`；完整 `flutter test` 共 2228 個測試通過（2026-09-26，執行紀錄分別為 `/tmp/371-analyze.log`、`/tmp/371-full.log`）。
- 實機界線：已在 iPhone 17（iOS 27.0 beta）安裝並啟動整合候選版 0.29.6+54，但 iPhone 鏡像回報連線錯誤；本票沒有取得裝置畫面或實機點擊證據，不將 widget 結果宣稱為實機驗證。
