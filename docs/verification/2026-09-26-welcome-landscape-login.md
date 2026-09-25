# Welcome 橫向與大字級登入入口預驗證（#333）

- 基準：`58c6987629f03a08d8e018f45b7a92d4b188cb25`（`feat/333-welcome-landscape-verification` 建立時）。
- 公開測試 seam：`WelcomeScreen` 的 widget test，844 × 390pt 橫向 viewport、文字縮放 320%；驗證頁尾登入入口可捲到、尺寸至少 44pt、點擊後呼叫登入動作，且沒有 layout exception。
- 結果：焦點測試 8 個通過；現有 320pt compact、regular width 與大字級測試仍通過，沒有修改 production code。
- 檢查：`flutter analyze --no-pub` 為 `No issues found`；完整 `flutter test --no-pub` 共 2221 個測試通過（2026-09-26，執行紀錄：`/tmp/333-full.log`）。Standards 審查沒有發現測試或文件問題；Spec 的真機驗收條件仍未滿足。
- 實機界線：widget viewport 與縮放設定不能取代 iPhone 的橫向旋轉及系統最大字級。仍需在指定最終版本的真機記錄裝置、OS、字級、安裝來源、找到頁尾 CTA 的步驟與畫面證據，才可完成本票的 P3 驗收。
