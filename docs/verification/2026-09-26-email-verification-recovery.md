# 驗證信等待頁恢復出口驗證（#337）

驗證基準為 `a8ef16c7a61bc5d25e9a2ba1203e9803b03a7b3f`（本分支原 HEAD；App 版本 `0.29.6+54`）。本票沿用現有 `/signup/check-email` 路由、`EmailVerifyPendingScreen` 與 `AuthRepository`，只補公開互動測試，沒有修改產品程式碼。

## 重現步驟與結果

1. 直接開啟 `/signup/check-email`，再以 `?email=%20%20` 進入：畫面保留「回登入」，「重寄」停用；點擊後沒有寄信請求。兩種入口都能返回 `/login`。
2. 以有效 email 進入等待頁，第一次重寄回傳 `429 VERIFY_EMAIL_RATE_LIMITED`：畫面持續顯示「驗證信請求過多，請稍後再試」，不顯示原始英文錯誤；訊息具 live region 語意。
3. 再次點擊「重寄」並讓請求成功：成功訊息取代錯誤，仍能返回登入。這個測試的 429 沒有 `Retry-After`，因此維持現有文案，不推測可重寄倒數時間。

上述兩個公開測試位於 `test/features/auth/account_flow_screens_test.dart`，以假路由和 repository override 觀察畫面、導航與對外請求。第一個測試原始程式碼即通過（`/tmp/337-first-test.log`）；第二個測試原始程式碼亦通過（`/tmp/337-second-test.log`）。為排除假綠，暫時使缺值時「重寄」可點擊，以及使 429 顯示原始錯誤；兩個測試分別如預期失敗（`/tmp/337-first-mutation-red.log`、`/tmp/337-second-mutation-red.log`），隨後完整還原產品程式碼。

驗證指令：

```bash
flutter test test/features/auth/account_flow_screens_test.dart
flutter analyze
flutter test
```

單檔 `flutter test` 共 46 項通過（`/tmp/337-focused.log`）；`flutter analyze` 零問題（`/tmp/337-analyze.log`）；完整 `flutter test` 共 2,221 項通過、程序結束碼 0（`/tmp/337-full.log`）。正式整合後仍須在最終版本重播；本次 widget 測試不能代替實機讀屏與登入恢復操作。真機證據需註明裝置、OS、App commit／build。
