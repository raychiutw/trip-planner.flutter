# HIG 取證：登入、帳號、分享、邀請、離線（#534，屬 #531）

範圍與清單見 [畫面清單](2026-11-04-hig-app-screen-inventory.md)，項目依據見 [HIG 檢查表](2026-11-04-hig-screen-checklist.md)。
量測由 `test/flows/hig_scene_guidelines_test.dart` 在一般 `flutter test` 跑（手機視窗 393×852 pt，淺色）。

## 這次做了什麼

- 補上 10 個缺口場景：`auth-check-email`、`auth-reset-password`（初始、成功、連結過期）、`auth-verify-email`（初始、成功、連結不完整）、`oauth-consent-invalid`、`account-logout-confirm`、`account-connected-app-revoke-confirm`。
- `HigScene` 新增 `proof`：場景進入截圖前必須找得到預期的 widget，證明渲染的是該畫面而不是空白或錯誤頁。
- 守門測試新增「對話框蓋住」斷言（見下節）。

## 發現：已登入場景預設被「要用 Face ID 登入嗎？」蓋住

在一般 widget test 的場景框架裡，`HigFakes` 預設的生物辨識驗證器回報「有 Face ID」，所以**幾乎每個已登入場景都會跳出登入後的生物辨識詢問**（79 個場景中有 59 個出現 `CupertinoAlertDialog`）。影響：

- 這些場景在 widget test 裡截到／量到的是對話框，不是畫面本體。
- 修正：預設改成沒有生物辨識的裝置；App 鎖相關場景自行指定 Face ID。修正後只剩 5 個場景有對話框，且都是刻意的（見 `_scenesWithDialog`）。
- 守門：非刻意場景出現對話框會紅（mutation：預設改回 Face ID，測試轉紅）。

限制：`docs/qa/2026-10-hig-screenshots/` 的 112 張舊截圖，我只開了 `light/account-sessions.png` 一張，裡面看不到這個對話框；其餘沒有逐張確認，所以**不能斷言舊截圖是否受影響**。

## 量測結果（觸控目標 ≥ 44×44 pt，檢查表 A1）

範圍內的違規（已登錄在 `_knownTapTargetViolations`，只減不增）：

| 場景 | 元素 | 尺寸 | 說明 |
|---|---|---|---|
| `auth-signup` | 無標籤的可點擊元素 | 40×40 | 疑似密碼顯示／隱藏按鈕，同時缺語意標籤 |
| `account-developer-app-new` | 無標籤的可點擊元素 | 40×40 | 同上類型 |
| `share-manage` 等 5 個分享場景 | 無標籤的可點擊元素 | 40×40 | 同上類型 |
| `offline-banner-pending` | 立即重試 | 100×40 | 高度不足 44 |
| `account-delete-dialog` | 目前密碼（重新驗證）欄位 | 230×31 | 對話框內的文字欄位 |

範圍內其餘場景量到 0 個違規，包括這次新補的 10 個場景。

說明：
- 「無標籤」是兩件事疊在一起：觸控目標太小，且 VoiceOver 讀不出名稱（檢查表中屬標籤類項目）。這次只做了尺寸的自動斷言，標籤沒有獨立斷言。
- 對話框內的欄位 230×31 是否算違規有爭議（原生 UIAlertController 的文字欄位本身就較矮），先如實登記，不下結論。

## 沒做的（如實揭露）

- 檢查表其他可量化項目（字級、對比、Dynamic Type 下是否截斷、標籤）尚未轉成斷言，這張票只有觸控目標有自動量測。
- 逐畫面的 HIG 判讀（版面、導航模式、對話框用語等）沒有做，需要人看截圖。
- 深色模式沒有量測，只有淺色。
- 本次沒有改動 App 行為，違規都只是登記，沒有修。
