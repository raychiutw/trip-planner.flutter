# 探索搜尋錯誤與空結果驗證（#348）

驗證基準：`1bdb963c06e254a781e8b82ceff5d41d919a075a`。本次修正只在搜尋結果為空且有載入錯誤時，隱藏代表成功搜尋的「沒有找到」文案；既有持續錯誤訊息及「重試」入口保留。

## 重現與預期

1. 在探索頁搜尋「東京」，讓地點搜尋回傳錯誤。原版同時顯示「搜尋失敗」與「沒有找到」，容易把網路失敗誤認成真的沒有結果。
2. 修正後只顯示易懂的錯誤與「重試」，不顯示「沒有找到」。
3. 使重試成功並回傳空清單，此時錯誤消失，才顯示「沒有找到『東京』的結果」。

公開畫面測試 `搜尋失敗保留錯誤與重試，不誤報無結果；重試成功後才顯示空結果` 走 repository provider 與 ExploreScreen。修正前的測試在「沒有找到」仍出現時失敗（`/tmp/348-first-red.log`）；修正後同一測試通過（`/tmp/348-first-green.log`）。ExploreScreen 與 ExploreController 合計 20 項測試通過（`/tmp/348-focused.log`），`flutter analyze` 零問題（`/tmp/348-analyze.log`），完整 `flutter test` 2,190 項通過（`/tmp/348-full.log`）。

重跑指令：

```bash
flutter test test/features/favorites/explore/explore_screen_test.dart test/features/favorites/explore/explore_controller_test.dart
flutter analyze
flutter test
```

快速連續輸入時的 VoiceOver 宣告仍需以最終整合版本在實際裝置檢查：記錄裝置、OS、App commit／build；在搜尋欄依序快速輸入並修改關鍵字，確認舊查詢沒有打斷目前輸入或朗讀過期結果。公開 widget 測試與 debounce 程式碼不能代替這項原生驗收。
