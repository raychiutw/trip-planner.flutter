# 五條跨畫面流程與 iPad 狀態連續性驗證（#387）

日期：2026-11-05。母票 #332。這是**驗證票**：只回報指定 build 的實際結果，沒有修改任何 production 行為。依使用者決議**不要求真機**；與 [#330](https://github.com/raychiutw/trip-planner.flutter/issues/330) 的 glass 自動化驗收互相引用（#330 驗控制項材質與語意 scope，本票驗跨畫面的狀態連續性；本票不以 App Store 上傳為前置條件）。

## 驗證對象與環境

| 項目 | 值 |
|---|---|
| Build SHA | `43c966197f47d2a400af7fd83d5d0e682c61b708`（origin/master，PR #575 合併後；以下每條流程都以此為準） |
| 與 master 的差異 | 僅新增測試：`test/flows/cross_flow_continuity_test.dart`、`test/app/router_test.dart` 一則、`integration_test/support/app_flow_fixture.dart` 兩個測試用欄位。`lib/` 無任何改動 |
| Host runner | macOS 27.2（Darwin 27.2.0）、Flutter 3.47.9（stable）、`flutter test` 的 flutter_tester（widget test，非真機、非模擬器） |
| Viewport | compact `390×844`、regular `1024×768`（devicePixelRatio 1，與 `CODING_STANDARDS.md` 的標準尺寸一致） |
| 字級 | 預設 1.0（所有新測試與重跑的測試；大字級另有既有專屬測試，本票未重跑） |
| iOS 模擬器 | iPhone 17（UDID `EFCB7551-19D0-450C-B557-BCA1531A3C5B`）、iOS 27.0。**兩次執行 `integration_test/app_smoke_test.dart` 都沒跑起來**：Xcode build 成功並安裝，但 `flutter test` 等不到 debug 連線（第一次卡 20 分鐘以上手動中止；第二次 `timeout 420`，輸出 `Error waiting for a debug connection: The log reader failed unexpectedly`、`No tests ran`）。所以本票**沒有任何 iOS 模擬器通過的證據** |
| iPad 機型 | `xcrun simctl list devices available` 只有 iPhone 17 與一台無關的裝置，沒有 iPad 模擬器，iPad 一律以 widget test 的 tester.view 尺寸切換驗證 |

## 總表

結果欄：通過＝以當前 master 實際執行且斷言通過；缺陷＝找到問題；無法驗證＝做不到並寫明原因。證據代號見各節。

| 流程 | 步驟 | 結果 | 證據 |
|---|---|---|---|
| 1 認證邀請與 Account 返回 | 1.1 未登入開邀請連結看到邀請頁、保留 redirect | 通過 | R1、R2 |
| | 1.2 登入後回到同一邀請 | 通過 | R1 |
| | 1.3 接受邀請進受邀行程時間軸 | 通過 | R1 |
| | 1.4 開 Account → 關閉，仍在受邀行程 | 通過 | R1 |
| | 1.5 Account 設定子頁（外觀）→ 返回 → 關閉，行程與 Day 選擇保留 | 通過 | N1 |
| | 1.6 帳號不符、邀請失效、暫時失敗的出口 | 通過 | R2（既有元件測試） |
| | 1.7 真機 Universal Link 冷啟動開啟邀請 | 無法驗證：使用者決議不做真機；host 測試以 `router.go` 模擬 | — |
| 2 時間軸編輯與衝突 | 2.1 編輯停留點輸入草稿、儲存撞 409 `STALE_ENTRY` | 通過 | R3 |
| | 2.2 協作者新版進來，草稿與欄位仍在 | 通過 | R3 |
| | 2.3 「保留你的版本？」選「繼續編輯」不重送、選「保留我的版本」以新 version 重送恰好一次，sheet 關閉仍在原時間軸 | 通過 | R3 |
| | 2.4 離線佇列重送撞 409 → 同步衝突橫幅 → 衝突解決 sheet → 保留我的版本 → 以新 version 重送、衝突清除、仍在原行程原日 | 通過 | N2 |
| | 2.5 解決 sheet 只選未套用就取消：不呼叫 API、衝突保留 | 通過 | R4 |
| | 2.6 真實後端的離線→重連時序、兩位真實協作者同時編輯 | 無法驗證：後端回應為 mock；真實時序需真後端與兩台裝置 | 見 `2026-11-04-hig-verification-gaps.md` §1 |
| 3 原生地圖 | 3.1 行程 → 地圖 root tab，帶入時間軸 Day | 通過（假畫布） | N3 |
| | 3.2 點地圖 Google POI → accessory → 關閉，Day 還原 | 通過（假畫布） | N3、R5 |
| | 3.3 地圖改選 Day → 回行程，時間軸同一天；再回地圖仍同一天 | 通過（假畫布） | N3、R5 |
| | 3.4 Day／marker／卡片索引在 days 重新載入、切行程時的保留規則 | 通過（既有元件測試） | R5 |
| | 3.5 真實原生 Google 地圖的建立、pan／pinch／rotate／double-tap、原生 POI callback | **無法驗證** | 見〈地圖限制〉 |
| 4 公開分享登入複製列印 | 4.1 未登入開 `/s/:token`，可列印 | 通過 | R1 |
| | 4.2 點複製 → 登入頁帶 `redirect_after`，尚未複製 | 通過 | R1、N4 |
| | 4.3 登入後回同一分享頁，仍可列印（登入狀態） | 通過 | N4 |
| | 4.4 複製成功，導向複製出的行程 | 通過 | R1、N4 |
| | 4.5 在複製出的行程進列印頁並列印 | 通過 | N4 |
| | 4.6 失敗、逾時、失效連結、大字級三動作 | 通過（既有元件測試） | R6 |
| | 4.7 真實列印／PDF 系統對話框 | 無法驗證：`TripPrintActions` 在測試中是替身；系統列印面板需真機或模擬器互動 | — |
| 5 iPad resize | 5.1 compact → regular：改走分欄、網址不變、Day 2 仍選取、側欄標出目前行程 | 通過 | N5 |
| | 5.2 regular → compact：分欄消失、網址與 Day 不變、返回仍回行程列表（導覽堆疊未重置） | 通過 | N5 |
| | 5.3 停留點編輯 sheet 的未送出草稿跨 regular／compact 四次切換不重置 | 通過 | N6 |
| | 5.4 聊天未送出草稿跨尺寸不重置 | 通過 | N7 |
| | 5.5 側欄捲動位置、detail 捲動位置、Day、深層 branch stack、系統返回 | 通過（既有元件測試） | R7 |
| | 5.6 真 iPad 或 iPadOS Split View／Stage Manager 的實際視窗尺寸變動 | 無法驗證：無 iPad 模擬器、不做真機；以 tester.view 尺寸切換代替，不等於系統實際行為 | — |

缺陷：**本輪沒有找到缺陷，所以沒有開修正票。**

## 證據

### 重跑的既有測試（當前 master，host runner，字級 1.0）

| 代號 | 指令 | 通過數 | 涵蓋 |
|---|---|---|---|
| R1 | `flutter test test/app/router_test.dart` | 51/51（新增 N4 後為 52/52） | 「邀請登入後接受並從 Account 返回受邀行程」「未登入可進入邀請確認頁 /invite?token」「公開分享可列印，登入後返回同一連結並複製行程」 |
| R2 | `flutter test test/features/invite/invite_screen_test.dart` | 19/19 | 邀請頁登入／帳號不符／失效／暫時失敗／AX 字級 |
| R3 | `flutter test test/flows/trip_browsing_flow_test.dart` | 3/3 | 「時間軸編輯撞 409 後保留草稿，確認新版才儲存並返回原行程」（2.1～2.3） |
| R4 | `flutter test test/features/offline/conflict_resolve_sheet_test.dart`、`offline_status_banner_test.dart` | 1/1、10/10 | 解決 sheet 取消與選擇；衝突橫幅 |
| R5 | `flutter test test/features/trip_detail/trip_map_screen_test.dart` | 72/72 | 例如「地圖與時間軸來回兩次仍一致」「Google POI 關閉後還原 Day、卡片索引與 marker 聚焦」「同一地圖切換行程時不沿用舊行程的 Day 和 marker」 |
| R6 | `flutter test test/features/share/public_share_screen_test.dart` | 25/25 | 公開分享的複製、列印、失效、逾時、大字級 |
| R7 | `flutter test test/features/shell/app_shell_test.dart` | 27/27 | 「compact／regular resize 保留 branch 與未送出內容」「regular width 行程 detail 使用保留選取的 split view」「resize 保留深層 branch stack，系統返回仍回上一層」。注意這幾則用探針路由而非真實行程畫面，所以另補 N5～N7 |
| — | `flutter test test/flows/app_owned_release_flow_test.dart`／`app_owned_visual_evidence_flow_test.dart`／`app_owned_release_flow_artifacts_test.dart`／`test/features/trip_detail/trip_print_screen_test.dart` | 2/2、3/3、11/11、24/24 | release 流程（登入→行程→地圖→帳號→聊天→收藏）、Day 在筆記與帳號開關後保留（visual evidence flow） |

### 新增的驗證測試

放在 `test/flows/cross_flow_continuity_test.dart`（走正式 `TriplineApp`、正式 router 與 provider 鏈，只替換網路與平台邊界），N4 放在 `router_test.dart` 緊鄰既有同型案例。

| 代號 | 測試名稱 |
|---|---|
| N1 | 流程1-尾端 進入 Account 設定子頁再返回：行程與 Day 選擇保留 |
| N2 | 流程2-離線 離線寫入重送撞 409 → 衝突橫幅與解決 sheet，保留我的版本後仍在原行程原日（真的 `ApiClient`＋`InMemoryCacheStore`＋dio mock adapter，衝突由 `flushQueue` 真實產生，不是直接寫進 store；以 dio interceptor 記錄實際送出的 `expectedVersion` 為 `[0, 1]`） |
| N3 | 流程3 地圖往返：Day 與選取狀態在行程↔地圖之間保留（假地圖畫布） |
| N4 | 公開分享登入複製後，在複製出的行程列印並保留登入身分（#387 流程4） |
| N5 | 流程5-a iPad resize：Trip／Day 選擇與導覽堆疊不重置 |
| N6 | 流程5-b iPad resize：停留點編輯 sheet 的未送出草稿不重置 |
| N7 | 流程5-c iPad resize：聊天未送出草稿不重置 |

`flutter test test/flows/cross_flow_continuity_test.dart`：6/6 通過。

### Mutation 驗證（每項都先確認轉紅、再還原）

| 目標 | 改動 | 結果 |
|---|---|---|
| N7 | `chat_screen.dart` 在寬度 ≥ 720 時清空輸入 | N7 紅 |
| N6 | `entry_edit_sheet.dart` 在寬度 ≥ 720 時清空說明欄 | N6 紅 |
| N5 | `app_shell.dart` 側欄不標選取（`selected = false`） | N5 紅 |
| N5 | 測試斷言把 resize 後的 Day 改期望 1 | N5 紅 |
| N3 | `trip_map_screen.dart` 地圖選 Day 不寫入共用選取日 | N3 紅 |
| N2 | `offline_sync_engine.dart` 解決成功後不移除衝突紀錄 | N2 紅 |
| N2 | `resolveConflictKeepOurs` 以版本 0 重送 | N2 紅 |
| N1 | 測試斷言把返回後的 Day 改期望 1 | N1 紅 |
| N4 | `public_share_screen.dart` 複製後導去 `/trips` | N4 紅 |
| N4 | 已登入時列印不執行 | N4 紅 |

**一則無效的 mutation，如實記錄**：把 `app_shell.dart` 的 `app-shell-detail` key 綁上 `regular`（想模擬「resize 時整棵內容重建」）後 N5～N7 仍全綠。原因是 go_router 的 branch Navigator 用 GlobalKey，重建會搬移而不是丟棄 state，所以這不是有效的「重置」突變，不能拿來證明測試能抓重置；因此改用上表的直接清空草稿突變。另外 N5 的「Day 被重置」只做了斷言層突變，沒有找到乾淨的 production 突變點。

### 完整套件

`flutter analyze`：No issues found。完整 `flutter test`（整個 `test/`，只在最後跑一次）：2958 通過、280 跳過（既有的 skip）、0 失敗。

## 地圖限制（照實寫，不冒稱）

- N3、R5 與 release 流程用的是**假地圖畫布**（畫面寫著 Google Map fixture）。它只能驗證 App 自己的狀態（Day、marker／卡片選取、accessory、root tab 往返），**不能證明原生地圖手勢、圖磚、marker 渲染**。
- 原生地圖手勢的正確測試 seam 是 `patrol_test/native_map_smoke_test.dart` 與 ADR-0012。本機沒有 Patrol CLI（`which patrol` 找不到），本票未執行。
- 歷史已知限制（非本 build 的證據，僅供理解缺口）：iOS 的 Flutter semantics 不進 XCUITest 的 accessibility tree，所以手勢注入改走 Patrol server extension；Android 的通過紀錄來自虛擬機（`MediumPhone.arm`），不是實體裝置；`docs/mobile-e2e.md` 記錄過 iOS native map smoke 的 POI callback 為 null、Android double-tap 橋接時序問題（#310）。Firebase Test Lab 授權已於 2026-11-02 移除，這些外部裝置路徑現在也無法重跑。
- iOS 模擬器：本票兩次嘗試皆沒跑起來（見上方環境表），所以連「假畫布的跨頁流程在 iOS 模擬器可執行」也沒有這次 build 的證據。

## 誠實的缺口

1. 沒有任何真機證據（使用者決議）；沒有任何 iOS 模擬器通過證據（執行環境問題，非產品問題，原因未定位）。
2. 所有結果都是 host runner 的 widget test；網路皆為 mock，真實後端時序（離線重連、同時編輯）未驗。
3. iPad 行為以尺寸切換模擬，沒有真實 iPadOS 視窗行為。
4. 字級只驗預設 1.0；大字級由既有元件測試負責（例如 R2、R6 內的 AX 案例），本票未重跑整個矩陣。
5. 暗色、減少動態效果、提高對比等情境屬 #330 的矩陣，本票未重複。

## 新發現

無缺陷，未開新票。一個測試面的發現：`app_shell_test.dart` 的 resize 案例使用探針路由，不能證明真實行程畫面的 Trip／Day／草稿在 resize 時保留，本票以 N5～N7 補上，且已由突變證明會抓到清空草稿與側欄選取遺失；Day 狀態的保護僅由斷言層突變證明。

## 與 #330 的關係

[#330](https://github.com/raychiutw/trip-planner.flutter/issues/330)（導覽玻璃收斂與跨畫面驗收）驗控制項語意 scope、十態矩陣與 PlatformView 共存；本票驗使用者流程的狀態連續性。兩者互補，共用 `app_owned_release_flow` 的 fixture，都不以 App Store 上傳為前置條件。
