# Handoff — 2026-07-24 HIG #96 全 App 契約收斂

## 本輪交付

- 外觀只跟隨系統；`MaterialApp` 提供 Light／Dark／High Contrast 主題，不再保留 Account 外觀頁、session 外觀選單或 `themeModeProvider`。
- Root 固定聊天、行程、地圖、收藏四個 branches；Account 只由 Header 的 `person.crop.circle` 開啟 sheet。舊 `/account/appearance` 與 `/settings/appearance` 保留為回到 Account 根頁的 alias。
- 移除舊 `TpTones`、`TpColorsLight/Dark`、Account 統計 hero／API、無 production consumer 元件，以及 audit／收藏的復原入口；Apple ID 登入仍不實作。
- 一般提示、確認、單一提示與表單統一走 `app/adaptive.dart` 的 HIG 元件；永久刪除只可左滑揭露後點擊，不允許 full swipe 直接執行。
- 探索 POI 改為自然高度列表，名稱與地址在 Accessibility Size 下不受固定 grid 比例裁切。
- `test/flows/release_wide_consistency_test.dart` 守住系統主題、iOS launch surface、calendar date picker、四 branches、無 Large Title、非搜尋頁無搜尋控制、系統 12／24 小時偏好與無 favorite restore 等 release-wide 契約。

## 驗證

- `dart format --output=none --set-exit-if-changed .`：342 個檔案，0 變更。
- `flutter analyze`：0 issue。
- `flutter test --no-pub -r failures-only`：1,566 個測試全數通過（150.5 秒）。
- `git diff --check`：通過。

---

# Handoff — 2026-07-23 HIG #84 四個根層分頁與帳號 Sheet

## 本輪交付

- #83 已透過 PR #98 合併至 `master`；本分支以該 merge commit `6bd1eb5` 為基底。
- #84 已把 compact root shell 改為聊天、行程、地圖、收藏四個分頁，Account 不再占用第五個 branch。
- 每個 app-owned 內容頁 Header 都以至少 44×44pt、VoiceOver label「帳號」的 `person.crop.circle` 開啟獨立 Navigation Stack sheet。
- 舊 `/account`、`/settings/*`、`/developer/apps*` deep links 會從目前 branch 開啟 Account sheet，關閉後保留 branch、Day、搜尋、捲動與聊天草稿。
- 已涵蓋 tab reselect、鍵盤開啟時隱藏 root bar、loading／empty／offline／error 狀態，以及 Header 單一直接 action 與 More overflow 規則。
- #87 已明確排除 Apple ID／Sign in with Apple 登入實作與入口。

## 驗證

```powershell
flutter analyze --no-fatal-infos
$env:Path = 'C:\Program Files\Git\usr\bin;' + $env:Path
flutter test --no-pub -r failures-only
```

結果：analyzer 0 issue；完整 1,425 tests 全數通過。Windows 本機 workflow tests 需要把 Git Bash `usr/bin` 放進 PATH；產品程式碼不需為此修改。

## Git／交付狀態

- 實作提交：`0c56b9b feat: 遷移四個根層分頁與帳號 sheet (#84)`。
- 交付分支：`feat/hig-02-root-tabs-account-sheet`，目標為 `master`，PR 使用 `Closes #84`。
- 本輪到 PR 建立即停止，不合併，也不開始 #85。

## 尚未執行

- 目前只偵測到 Windows、Chrome 與 Edge，沒有可用 iOS 裝置，因此未執行 `integration_test/app_owned_release_flow_test.dart` 的 iOS 實機驗證。

---

# Handoff — 2026-07-23 v0.9.6 Firebase iOS 驗證與雙商店發布

## v0.9.6 發布結案

- 最終 source SHA `4ac7776d95135cbcf1baded91511a11d28d171c9` 已經 PR [#80](https://github.com/raychiutw/trip-planner.flutter/pull/80) 合併至 `master`；PR CI [29963049945](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29963049945) 與 master CI [29963722375](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29963722375) 均通過 analyzer、完整測試、UI evidence 與 Android debug build。
- 本機 `flutter analyze` 0 issue、1,402 tests 全數通過；iOS simulator Patrol app-owned flow 1/1 通過登入、聊天、當時的五個 root tabs 與收藏搜尋（該導覽已由 #84 取代）。
- iOS Firebase Test Lab [29963749443](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29963749443) 在 iPhone 14 Pro／iOS 16.6 對 final master 回報 `3 test cases passed`，涵蓋 XCTest example、app-owned release flow 與 native Google map smoke。
- iOS release flow 已改用 Patrol 實機文字輸入 driver，root tab 導覽改用 app 自有唯一 `ValueKey`；不再依賴 release build 不提供的 debug semantics 或 Liquid Glass 套件內部手勢元件。
- Release workflow [29964801571](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29964801571) 已將共同 build `12701` 發布至 TestFlight（processing `VALID`）與 Google Play internal（status `completed`，Play edit `14630000200256184012`）。
- 本次 release dispatch 關閉重複 optional evidence；Firebase iOS 證據已由上述 final-master 獨立 run 完成，未重跑 Android matrix 或 staging favorite-restore contract。

以下保留 v0.9.4 與 v0.9.3 大型 UI 重構的交接背景，供後續維護追溯。

## v0.9.4 發布結案

- 行程地圖入口精簡為 `Google`／`Apple`，並保留完整 VoiceOver 動作語意，避免大字體或窄寬度折行。
- Timeline 第一個編號的直線由 marker 中心開始，交通列之間保持連續，最後一個 stop 下方亦保留延伸線。
- 起訖時間與精確停留時間固定同列，Google 分類與星等移至下一列；舊資料只有 `time` 時仍可正確計算。
- 編輯頁文字按鈕不再受 44pt 固定寬度限制，大字體下「取消」可完整顯示。
- iOS 模擬器已驗證行程、排序、編輯與地圖；地圖維持淺色、原生 Google POI 可見，預設／切 Day／點 POI 均維持 zoom `13`。
- Analyzer 0 issue、全庫 1,355 tests、PR CI 與 merge commit CI 的 Android debug build 全部通過。
- PR [#73](https://github.com/raychiutw/trip-planner.flutter/pull/73) 已合併，annotated tag `v0.9.4` 已推送；release workflow [29848648325](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29848648325) 已將共同 build `11201` 發布至 TestFlight（processing `VALID`）與 Google Play internal（status `completed`）。

## 本輪已完成

- 行程景點卡改為四列摘要：名稱、可編輯時間／分類／停留／星等、平台導航、說明／備註等資訊；編號圓圈與主卡垂直置中。
- 點卡片改為展開／收合備選景點，不再直接開編輯；無備選時顯示「尚無備選景點」與「換景點」。
- 每張卡片的 `…` 固定六項三組：重新排序、換景點｜編輯景點、移動到其他天｜複製到其他天、刪除景點。
- 排序只保留短按拖曳 handle，沒有長按第二模式；同一次拖曳可在同日改序，也可放進其他 Day 的任意 drop target 或空 Day。
- 跨 Day drop 以既有 batch API 一次送出受影響 entry 的 `day_id + sort_order`；送出中禁止第二次拖曳，失敗同時還原來源／目標兩日並顯示 persistent error。
- 不同 Trip 切換後回 `DAY 1`；同一 Trip 的行程／地圖互切保留 Day。
- 起訖時間改成兩個 compact chips；iOS／macOS 使用 Cupertino wheel，其他平台使用 Material picker；本輪不支援跨午夜。
- 全 App 由 root 共用 tap-outside／user-scroll keyboard dismissal，收合不清除草稿、不 submit。
- 當時曾將 Account 設為第 5 個 root tab；此決策已由 #84 的四分頁＋Header Account sheet 取代。
- Root Header、Day selector、Root tab 改用 regular／PlatformView glass recipes，並保留 High Contrast／Reduce Transparency 實色 fallback。
- swipe delete 只揭露紅色「刪除」按鈕，點擊後才確認；沒有 full swipe、Undo 或 Restore，且與 menu delete 共用 handler。

完整規格與驗收條件：`docs/superpowers/plans/2026-07-21-trip-entry-card-menu-keyboard-glass.md`。

## 已驗證

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --no-pub -r failures-only
flutter build apk --debug --no-pub
```

結果：analyze 0 issue；全庫 1,347 tests 全部通過，包含跨 Day 成功／失敗回滾、拖曳 feedback 寬度、單日 move/copy disabled reason semantics、卡片內控制不誤觸展開，以及 27 個 POSIX workflow contract tests；Android debug APK 已產生於 `build/app/outputs/flutter-apk/app-debug.apk`。PR CI [29829527458](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29829527458) 亦通過 analyzer、完整測試、UI artifacts 與 Android debug build。

## 後續非阻塞平台驗收

1. 在 macOS 執行 `flutter build ios --simulator`，再跑 iOS simulator widget／integration flows。
2. iPhone 320pt／390pt／430pt，100%／200% Dynamic Type：檢查四個 root tab labels、Header Account、時間 chips、導航 pills、menu 與刪除 label。
3. Light／Dark、Reduce Transparency／High Contrast：以內容從 Header／Day selector／Root tab 下方滑過的錄影確認 glass 透出與可讀性。
4. VoiceOver：確認卡片 expanded/collapsed、時間、地圖、`…`、設為正選、移動到其他天、刪除與 Header Account 的 focus／閱讀順序。
5. 實機拖曳長行程：驗證畫面邊緣自動捲動、跨 Day drop、request lock、API 失敗兩日回滾及交通重算。
6. Google Map PlatformView：確認 map gestures 不被 glass navigation 攔截、玻璃不閃爍或凍結。

## Windows workflow 測試

POSIX contract tests 會明確使用 Git for Windows Bash，並把 Windows temp paths 轉成 Bash paths，避免系統搜尋順序誤選 WSL `bash.exe`。本機 27 個 workflow tests 已全部通過；Linux CI 仍須照常執行，作為不同 host 的獨立證據。

## 仍等待後續規格

- 政策版本更新後的重新同意時機、阻擋範圍與既有使用者遷移流程。

隱私權聲明、Signup 同意欄位與後端紀錄、公開政策連結、Welcome／Signup／Account 入口及刪除帳號流程已在 `0.9.2` 完成並發布；後續不要把這些已完成項目重新列為本版阻塞。

## Git／發布狀態

- PR [#73](https://github.com/raychiutw/trip-planner.flutter/pull/73) 已合併至 `master`，source SHA 為 `e9517dd131836e80424b3aae6a7046df75f8a053`，並已推送 annotated tag `v0.9.4`。
- PR CI [29846766960](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29846766960) 與 merge commit CI [29847777356](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29847777356) 均通過 analyzer、1,355 tests、UI artifacts 與 Android debug build。
- Release workflow [29848648325](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29848648325) 已把共同 build `11201` 發布至 TestFlight（processing `VALID`）與 Google Play internal（status `completed`）。
- Optional Firebase／staging evidence 本次依 publish-first 設定未執行，不影響已完成的商店發布；後續可獨立回補。
