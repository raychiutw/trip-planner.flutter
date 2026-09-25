# 共編角色與局部失敗驗證

- 來源：#359；檢查基底 `cf44648af380ac111da5f3e41c202f1ca4e6057e`。
- 範圍：既有 `CollabScreen` 公開 widget seam；尚未完成真機驗收。

## 已驗證

在 320×568 畫面、200% 文字尺寸，使用長 email 的成員與邀請資料。成員的角色選單可開啟並切換為共編成員；向下捲動後，邀請的撤銷按鈕可開啟對應 email 的確認。測試不抑制點擊命中警告，並確認過程沒有 Flutter layout exception。

另一個案例放入兩封邀請，令第一封撤銷首次失敗。錯誤保留兩封邀請；點擊錯誤區的「重試」只重送第一封，成功後只移除第一封，第二封完全沒有送出撤銷 API。兩項斷言曾暫改為錯誤預期而失敗，還原後通過，以避免假綠燈。

```text
flutter test --no-pub test/features/trips/collab/collab_screen_test.dart
```

## 尚待真機驗收

在目前整合 build 的 iPhone 上，以最大系統字級實際操作長 email 的角色選單與撤銷確認，並用 VoiceOver 核對完整名稱、焦點與失敗重試。此次 Mac 的 iPhone 鏡像未建立視窗，無線 debug 測試版亦缺開發用 provisioning profile；因此此文件只證明 widget 行為，不把 #359 標為完成。
