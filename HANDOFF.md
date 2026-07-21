# Handoff — 2026-07-21 行程景點卡／跨 Day 排序／Root UI

## 本輪已完成

- 行程景點卡改為四列摘要：名稱、可編輯時間／分類／停留／星等、平台導航、說明／備註等資訊；編號圓圈與主卡垂直置中。
- 點卡片改為展開／收合備選景點，不再直接開編輯；無備選時顯示「尚無備選景點」與「換景點」。
- 每張卡片的 `…` 固定六項三組：重新排序、換景點｜編輯景點、移動到其他天｜複製到其他天、刪除景點。
- 排序只保留短按拖曳 handle，沒有長按第二模式；同一次拖曳可在同日改序，也可放進其他 Day 的任意 drop target 或空 Day。
- 跨 Day drop 以既有 batch API 一次送出受影響 entry 的 `day_id + sort_order`；送出中禁止第二次拖曳，失敗同時還原來源／目標兩日並顯示 persistent error。
- 不同 Trip 切換後回 `DAY 1`；同一 Trip 的行程／地圖互切保留 Day。
- 起訖時間改成兩個 compact chips；iOS／macOS 使用 Cupertino wheel，其他平台使用 Material picker；本輪不支援跨午夜。
- 全 App 由 root 共用 tap-outside／user-scroll keyboard dismissal，收合不清除草稿、不 submit。
- Account 成為第 5 個 root tab；聊天／行程／地圖／收藏 Header 的 account avatar 已移除。
- Root Header、Day selector、Root tab 改用 regular／PlatformView glass recipes，並保留 High Contrast／Reduce Transparency 實色 fallback。
- swipe delete 只揭露紅色「刪除」按鈕，點擊後才確認；沒有 full swipe、Undo 或 Restore，且與 menu delete 共用 handler。

完整規格與驗收條件：`docs/superpowers/plans/2026-07-21-trip-entry-card-menu-keyboard-glass.md`。

## 已驗證

```powershell
C:\flutter\bin\dart.bat format --output=none --set-exit-if-changed <本輪 Dart 檔案>
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --no-pub -r failures-only test\api test\app
C:\flutter\bin\flutter.bat test --no-pub -r failures-only test\features
C:\flutter\bin\flutter.bat test --no-pub -r failures-only test\helpers test\models test\platform test\theme test\ui
C:\flutter\bin\flutter.bat test --no-pub -r failures-only test\flows
C:\flutter\bin\flutter.bat test --no-pub -r failures-only
C:\flutter\bin\flutter.bat build apk --debug --no-pub
```

結果：analyze 0 issue；全庫 1,341 tests 全部通過，包含跨 Day 成功／失敗回滾、單日 move/copy disabled reason semantics、卡片內控制不誤觸展開，以及 27 個 POSIX workflow contract tests；Android debug APK 已產生於 `build/app/outputs/flutter-apk/app-debug.apk`。

## 下一手必做的平台驗收

1. 在 macOS 執行 `flutter build ios --simulator`，再跑 iOS simulator widget／integration flows。
2. iPhone 320pt／390pt／430pt，100%／200% Dynamic Type：檢查 5-tab labels、時間 chips、導航 pills、menu 與刪除 label。
3. Light／Dark、Reduce Transparency／High Contrast：以內容從 Header／Day selector／Root tab 下方滑過的錄影確認 glass 透出與可讀性。
4. VoiceOver：確認卡片 expanded/collapsed、時間、地圖、`…`、設為正選、移動到其他天、刪除與 Account tab 的 focus／閱讀順序。
5. 實機拖曳長行程：驗證畫面邊緣自動捲動、跨 Day drop、request lock、API 失敗兩日回滾及交通重算。
6. Google Map PlatformView：確認 map gestures 不被 glass navigation 攔截、玻璃不閃爍或凍結。

## Windows workflow 測試

POSIX contract tests 會明確使用 Git for Windows Bash，並把 Windows temp paths 轉成 Bash paths，避免系統搜尋順序誤選 WSL `bash.exe`。本機 27 個 workflow tests 已全部通過；Linux CI 仍須照常執行，作為不同 host 的獨立證據。

## 仍等待後續規格

- 政策版本更新後的重新同意時機、阻擋範圍與既有使用者遷移流程。

隱私權聲明、Signup 同意欄位與後端紀錄、公開政策連結、Welcome／Signup／Account 入口及刪除帳號流程已在 `0.9.2` 完成並發布；後續不要把這些已完成項目重新列為本版阻塞。

## Git／發布狀態

- 本輪尚未 commit、push 或 release。
- `.context/` 為既有未追蹤內容，未納入本輪修改。
