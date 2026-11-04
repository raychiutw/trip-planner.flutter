# App HIG 截圖（#531：#534～#536 新補場景＋既有場景重拍）

iOS 模擬器 iPhone 17（iOS 27，Debug build，393×852 pt @3x），整合測試 `integration_test/hig_screenshots_test.dart` 產生，全程走 mock repository，不碰 prod。
102 個場景 × 淺／深 = 204 張 PNG（縮到 603×1311 以控制體積）。`report.tsv` 是深淺色比對（全部 bytes 不同、像素差異 ≥ 98%、深色亮度明顯較低）。

重跑：

```bash
flutter test integration_test/hig_screenshots_test.dart -d <UDID> \
  --dart-define=HIG_SHOT_DIR=$PWD/docs/qa/2026-11-04-hig-screenshots
# 只跑單一場景：--dart-define=HIG_ONLY=<場景名稱子字串>
```

**前置條件（這次卡了 20 分鐘才發現）**：`ios/Flutter/Secrets.xcconfig`（gitignored）必須存在。沒有它，App 一啟動就 `fatalError("Missing GOOGLE_MAPS_IOS_API_KEY build setting")`，`flutter test` 等不到 VM service 而無限等待、沒有任何錯誤輸出。新的 git worktree 不會帶這個檔案。

## 我實際用眼睛看過的畫面（其餘 190+ 張沒有逐張檢視，只有深淺色的機器比對）

淺色：`entry-edit`、`global-map`、`account-logout-confirm`、`auth-reset-password-success`、`collab`、`trip-health-findings`。
（`chat-voice-consent`、`entry-add` 已縮圖但沒有開。）

| 畫面 | 觀察 | 對照檢查表 |
|---|---|---|
| `account-logout-confirm` | 標準 alert：標題、一行說明、左「取消」右紅色「登出」。符合預期。 | 破壞性確認 |
| `collab` | 角色選擇 chip「共編成員／檢視成員」畫面上高約 35pt，低於 44pt；但觸控量測回報 0 違規，因為量的是語意節點範圍，可能比畫出來的大。**畫面尺寸與量測結果不一致，需人確認實際可點區域。** | A1 |
| `trip-health-findings` | 第二張建議卡（低風險）寬度只有第一張的約一半，兩張卡寬不一致，疑似版面缺陷。 | 版面一致性 |
| `entry-edit` | （已於 #547 改為整頁 modal，重拍後沒有分頁列；原觀察：帶「取消／儲存」的 modal 表單底下仍顯示底部分頁列。） | modal 與 tab bar |
| `global-map` | 地圖區域是測試用的「Google Map fixture」文字，不是真地圖，只能看疊在地圖上的控制項與底部卡片。 | — |
| `auth-reset-password-success` | 成功頁頂端仍有返回鈕，頁面大片留白，主按鈕「前往登入」。 | — |

上表的「觀察」是我看圖得出的判斷，沒有逐條對照 HIG 原文；「對照檢查表」欄只是指出可能相關的項目。

## 沒做的

- 約 190 張沒有人或我逐張看過。
- 觸控目標以外的檢查（字級、對比、標籤、Dynamic Type）沒有量測。
- 舊截圖（`docs/qa/2026-10-hig-screenshots/`）沒有刪，兩批並存；已登入場景在 widget test 框架曾被生物辨識詢問蓋住（見 #540），這批重拍的截圖來自整合測試，沒有逐張確認是否同樣被蓋住。
