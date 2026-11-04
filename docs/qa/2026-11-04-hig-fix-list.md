# HIG 比對後的修改清單（#531）

日期：2026-11-04。來源：[App 逐張檢查報告](2026-11-04-hig-screenshot-review-app.md)（102 個場景全看）與 web 逐張檢查報告（trip-planner repo 的 `docs/qa/2026-11-04-hig-web-screenshot-review.md`，27 個場景桌機與手機寬全看）。

這份清單只列「要改什麼」，每項都帶位置、建議改法與怎麼驗證。**還沒有動任何程式碼**；排序是我的建議，開票與否由你決定。

證據強度：**程式碼**＝對照過原始碼；**像素**＝量過；**看圖**＝只有目視，改之前建議先在真機或模擬器再確認一次。

## 一、先修證據（場景本身有問題）

這三項不修，截圖就不能當作對應畫面的證據；都是測試端的改動，不影響 App 行為。

| # | 場景 | 問題 | 建議修改 | 驗證 |
|---|---|---|---|---|
| S1 | `auth-reset-password-expired` | stub 丟 `expired`，畫面只認 `RESET_TOKEN_INVALID`／`MISSING`，顯示的是「暫時無法處理」，不是過期提示（程式碼，`account_flow_screens.dart:541-546`） | 場景 stub 改丟畫面認得的 code | 重拍後畫面出現過期提示文字；`hig_scene_guidelines_test` 仍綠 |
| S2 | `trip-map-route-failed` | 與 `trip-map` 位元組完全相同（SHA-1），沒有失敗畫面 | 讓路線 stub 真的失敗，並讓 proof 確認是「路線失敗」的那個元素 | 重拍後 SHA-1 不同，且畫面看得到失敗提示 |
| S3 | `ax-favorites-2x` | 沒有 `act` 餵收藏資料流（對照 `favorites` 場景），只拍到載入骨架（程式碼加看圖） | 補上與 `favorites` 相同的 `act` | 重拍後是 2x 的收藏清單 |

另有兩個場景受限，不是缺陷：`trip-map`、`ax-trip-map-2x`、`global-map` 的地圖是測試用純色 fixture，玻璃元件的對比（量得 2.07～2.74:1）**不能當對真實地圖的結論**，要真機看。web 的 `trip-map`、`map` 場景擋掉了 Google Maps，畫面是錯誤態，同理。

## 二、App 要改的

| # | 場景 | 檢查表 | 問題 | 建議修改 | 強度 |
|---|---|---|---|---|---|
| A1 | `auth-signup` | F5 | 空表單、未勾同意時「建立」仍可按（`account_flow_screens.dart:145` 是 `primaryActionEnabled: !_submitting`） | 欄位未通過驗證或未勾同意時停用，與 web 對齊（web 已是停用外觀加就地說明） | 程式碼 |
| A2 | `add-to-trip-invalid-favorite`、`add-to-trip-missing-data` | G4、D12 | 錯誤態只有一行灰字，沒有圖示、重試或返回；底部分頁列仍顯示（`add_to_trip_screen.dart:76,90`） | 改用專案既有的錯誤態元件，附「返回」；modal 式畫面隱藏分頁列（與 A4 一起處理） | 程式碼加看圖 |
| A3 | `trip-edit` | D10、G5 | 同一個有「取消」的表單，部分欄位按「儲存」才生效、日期與天數立即生效 | 統一成「全部按儲存才生效」，或拿掉「取消」改成即時儲存 | 看圖 |
| A4 | `entry-add`／`entry-edit`／`entry-copy`／`entry-move` | D12 | modal 式表單下方仍顯示底部分頁列 | 這幾個路由進入時隱藏分頁列 | 看圖 |
| A5 | `account-sessions` | C1 | 「管理已連結應用」文字 4.36:1，低於 4.5:1；該卡疑似帶按下或焦點外框 | 調深文字色或換 token；確認外框是否為殘留焦點 | 像素加看圖 |
| A6 | `account-connected-apps` | C4、H2 | 深色下 scope 標籤沒有膠囊底；列內圖示與標題錯位 | 補深色底色 token；對齊圖示與標題基線 | 看圖 |
| A7 | `trip-health-findings` | 版面 | 第二張建議卡只有第一張一半寬 | 兩張卡同寬（檢查 Row／Expanded） | 看圖 |
| A8 | `oauth-consent-invalid` | D3 | 沒有返回鈕或導覽列，只有頁內連結 | 補返回；或確認這頁只能由系統瀏覽器進入而不需要 | 看圖 |
| A9 | `ax-public-share-2x` | B2 | 「登入後複製行程」折成兩行並剩孤字「程」，與兩個圖示鈕擠同列（`public_share_screen.dart:247`） | 大字級時按鈕換到獨立一列 | 看圖 |

**與專案決策有張力，需要你決定要不要改規則，不建議直接改程式：** `account-home`、`account-home-security` 的生物辨識開關與外觀設定（F7、H1）；`app-lock-enable-prompt` 在 App 內詢問是否開 Face ID（F7）。這些都是已知的專案決定。

## 三、web 要改的

| # | 場景 | 檢查表 | 問題 | 建議修改 | 強度 |
|---|---|---|---|---|---|
| W1 | `account-sessions`、`account-connected-apps`、`developer-apps` | 版面 | 頁面上方小標被固定頁首壓住而被裁切或重疊，桌機與手機都有 | 頁面內容區加上頁首高度的 `scroll-margin`／padding-top | 看圖 |
| W2 | `trip-detail`（桌機） | E1 | 地圖面板錯誤態的「重試」是未套樣式的原生灰色按鈕 | 改用專案按鈕元件 | 看圖 |
| W3 | `trip-detail`（手機） | 版面 | 移動方式膠囊超出右緣被截斷 | 允許換行或改成可橫向捲動並露出邊緣提示 | 看圖 |
| W4 | `explore`（手機） | — | 篩選膠囊「Sight 1」與卡片類別「SIGHT」是未在地化的英文原值 | 類別 key 對照到中文標籤 | 看圖 |
| W5 | `trips-new`（手機） | B | 日期欄位「選擇日期」字級明顯大於同頁其他 placeholder | 與其他欄位的 placeholder 字級對齊 | 看圖 |

需要設計確認、不一定要改：`trip-print` 淺深兩色相同（列印預覽固定淺色）；`login`、`signup`、`forgot-password` 的桌機右側宣傳面板與外觀反相；`login` 手機寬卡片內外各有一個 Tripline 標誌。

## 四、看過但判定沒問題的（避免重複討論）

- 大字級（B2）：能判讀的 `ax-*` 場景都沒有截斷。分段控制元件在大字級改垂直堆疊，是 `tp_segmented_control.dart:106` 的刻意設計；選中態堆疊後只靠底色。導覽列標題膠囊在 2x、3x 沒有跟著放大，我沒判斷這算不算違規。
- 深色模式：淺深兩色在可判讀的場景都有對應的 token，除了 A6。
- 就地錯誤與停用鍵：`share-custom-expiry-missing` 符合預期（錯誤「請選擇到期日」＋建立鈕停用）。

## 五、沒涵蓋的

- 沒量字級（B1）、沒逐一量對比（只量了 A5 與地圖玻璃）。
- 沒檢查 Increase Contrast、Reduce Motion、VoiceOver，web 沒做鍵盤、焦點、dialog 與 200% 重排；web 只跑了 chromium。
- 彈出層（sheet、dialog、picker）大多沒有場景，見 `docs/research/2026-11-04-hig-app-screen-inventory.md` 的缺口摘要。
- 「符合」與「未見明顯問題」是我目視的結論，沒有第二人複核。

## 建議順序

1. S1～S3（場景修好，之後重拍才有意義）。
2. A1、A2、A4（行為性缺陷，有程式碼證據）。
3. A5～A9、W1～W5（視覺類，先在模擬器或瀏覽器再確認一次再改）。
4. A3 與張力項目要先做決定。
