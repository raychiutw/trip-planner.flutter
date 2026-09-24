# 導覽玻璃語意組裝驗證

本紀錄對應 [#325](https://github.com/raychiutw/trip-planner.flutter/issues/325)
的帳號與定位切片 [#327](https://github.com/raychiutw/trip-planner.flutter/issues/327)，
以及浮動 header／固定 bar 切片 [#328](https://github.com/raychiutw/trip-planner.flutter/issues/328)、
root tab bar／日期選擇器切片 [#329](https://github.com/raychiutw/trip-planner.flutter/issues/329)。

## 版本與範圍

- 切片起點：`b9729c171eb1d27a21f7dfc2a98cabf3512824ae`，`0.26.10+41`。
- 本切片保持版本號，限於 `TpAccountAvatarButton`、`TripMapLocateButton`
  與共用導覽玻璃的組裝責任，不調整任何光學數值、套件或 shader。
- 母票開工基準已確認 `flutter analyze` 無問題、完整 widget／unit suite
  1990 項通過；這些結果只代表起點，不替代本切片的檢查。
- 基準裝置 run [35953925642](https://github.com/raychiutw/trip-planner.flutter/actions/runs/35953925642)
  已成功：iOS release／iPhone 14 Pro／iOS 16.6，以及 Android debug／shiba／API 34。
  此 run 是修改前證據，不能當作本切片的真機材質後驗。

## Interface 與相容性

`TpNavigationGlassButton` 只收 production 角色、內容、動作及忙碌狀態。
`barButton` 保留帳號的圓形幾何，`floatingControl` 保留定位的既有圓角。
同一 module 從既有 `TpMediaBackdropScope` 取得媒體情境，成套決定材質、
quality、前景、提高對比邊界及不透明降級。非媒體帳號入口也由 module
提供完整前景，不再依賴外層另外包 `TpBarForeground`。

忙碌狀態由 module 顯示進度與不可操作語意，使用既有 `TpGlassSurface`；
不把整片不透明底交給套件 disabled 淡化。一般停用動作仍保留套件原有呈現。
定位服務、帳號導覽與 feature provider 都留在原有責任層。

`TpToolbarGlassButton`、`TpGlassSurface`、光學設定函式與媒體 scope 的舊入口
均保留，供 [#328](https://github.com/raychiutw/trip-planner.flutter/issues/328)
及 [#329](https://github.com/raychiutw/trip-planner.flutter/issues/329) 逐步接續；
本切片不遷移浮動 header、固定 bar、root tab bar、日期選擇器或選單。

## Red → green 證據

測試使用真實 App 控制項與既有媒體／無障礙 scope；行程地圖仍只在既有
`mapBuilder` seam 替換底圖。沒有新增測試專用 provider 或渲染 interface。

- 非媒體前景：新測試讀最終 `RenderParagraph` 色彩，先得到帳號 alpha
  `0.8667`，未達完整 `onSurface` 的 `1`；改由 module 成套提供後通過。
  原正式 header 已提供同一前景，因此不改變其既有外觀。
- 媒體 mutation：暫把共用圖示填色由 `45%` 改為 `70%`，帳號與定位
  的背景透出均降至 `29.8%`，兩項公開像素測試失敗。還原後兩項通過，
  透出 `54.9%`，亮底圖示對比 `3.363:1`；明暗主題結果相同。
- 操作 mutation：暫移除按鈕 callback，鍵盤啟用的呼叫數由預期 `1`
  變為 `0`，測試失敗。還原後，媒體與非媒體的 Tab／Enter／Space
  及讀屏 tap 均各派發一次。
- 聚焦驗證：`tp_map_icon_transparency_test.dart`、
  `tp_map_controls_legibility_test.dart`、`tp_glass_surface_test.dart`
  共 37 項通過；包含亮暗背景、提高對比／降低透明度各自生效、定位忙碌
  不可重入與不透明、44pt、放大字級、帳號導覽及真實地圖畫面組裝。
- `flutter analyze --no-pub`：No issues found，零 error／warning。
- 第一輪完整測試為 1991 項通過、1 項失敗，原因是新組裝漏帶帳號既有的
  `tp-toolbar-glass-button` key。保留該識別後，原帳號回歸案例單點通過；
  沒有為了讓測試通過而改寫既有入口契約。
- 修正後完整 `flutter test --no-pub --concurrency 2 --reporter expanded`
  為 **1992 項全數通過**（15 分 28 秒），包含 HIG 十態與畫面證據集。
  修正後再跑 `flutter analyze --no-pub`，仍為 No issues found。

## 真機驗證交接

以上 headless 證據只涵蓋 App 自有填色、前景、幾何、語意與操作。
Impeller 折射、原生圖磚與玻璃共存、邊緣光、thermal 降級與 raster jank
均交由 [#330](https://github.com/raychiutw/trip-planner.flutter/issues/330)
在所有玻璃切片整合後以當前版本真機重驗，並與上述基準版本分別標記。

## 浮動 header 與固定 bar（#328）

固定起點為 `250482339d94e2f6f573d5e9e9547a19b84b92ab`。標題膠囊、
動作群組與 bar button 的語意組裝收進 `tp_glass_surface.dart`，與帳號、
定位共用同一組媒體／材質／前景／quality／邊界決策。呼叫端保留內容、
操作與角色；浮動 header 只傳標題組合與留白，不再配對 recipe 和前景。
固定 bar 繼續由 `GlassAppBar` 量測幾何，sheet 返回與關閉的 tint 保留在
原有動作內容上，未更動 route host、導覽或關閉保護。

`TpHeaderTitle`、`TpToolbarActionGroup`、`TpToolbarGlassButton` 仍可從
原 `tp_app_bar.dart` 入口使用。`TpGlassSurface`、原設定函式及媒體 scope
仍保留，root tab bar 與日期選擇器在下一切片接續。選單仍採獨立
`tpMenuGlassSettings`，本票沒有改面板、模糊、底色或開關 adapter。

一般 `Text` 標題的公開測試另抓到既有漏接：`headlineSmall` 自帶的
`onSurface` 蓋掉外層媒體前景，淺色地圖上最終文字變成黑色。現在標題
字階與語意前景一起由 module 提供；自然寬度、省略與字級維持原契約。

### 本切片 red → green

- 暫時讓原浮動 header 忽略媒體 scope，真行程地圖測試得到
  `Expected white / Actual black`；還原後明暗主題兩項測試通過。
- 一般標題測試自然失敗，同樣為 `Expected white / Actual black`。
  只接回標題字階的語意前景後通過，確認不是 scope 遺失或套件改色。
- 暫將共用媒體暗化 `35%` 改為 `70%`，真標題與動作群組的背景透出
  測試得到 `Expected 0.65 +/- 0.02 / Actual 0.298`。還原後通過；
  明暗主題與提高對比／降低透明度各自檢查最終前景和實際背景像素。
- 新操作案例透過真浮動 header 與固定 bar，在 `390×844`、`1024×768`
  及兩倍字級驗證 safe area、44pt、返回／分享／列印／帳號的鍵盤啟用，
  群組與帳號的讀屏 tap 各派發一次。既有測試持續守住返回路由、sheet
  tint、選單、長標題與動作自然寬度。
- 操作 mutation 暫時移除 bar button 回呼，鍵盤走到分享後仍只收到返回，
  測試為 `Expected 分享 / Actual 返回`；還原後上述操作案例通過。
- 最終聚焦驗證共 **128 項通過**，涵蓋本票公開語意、固定 bar、浮動
  header、選單、帶狀遮蔽、帳號／定位與共用材質。
- `flutter analyze --no-pub`：**No issues found**，零 error／warning／info。
  首次程序停留在啟動階段，停止該程序後重跑才取得分析；其後移除搬移
  所留下的兩個多餘 import，再次分析通過。格式與 `git diff --check` 通過。
- 首次完整測試（並行度 2）在 19 分 31 秒以 1989 項通過、4 項失敗收尾：
  畫面證據集第一個 landscape 案例超過既有 45 秒時限，後續出現
  `runAsync` 重入等連鎖失敗。單獨重跑原證據檔，在相同時限下 11 項
  全數通過；這不能代替完整測試，也不足以判定逾時原因。
- 第二次完整測試（並行度 1）在 32 分 13 秒以 1993 項通過、2 項失敗
  收尾：證據集第一個 compact-light 案例超時，另有手動證據驗證案例
  因執行環境找不到 `jq` 失敗。降低並行度沒有消除逾時；未放寬時限、
  刪除案例或改動斷言。兩次失敗的畫面、雜湊與測試日誌保留於本機
  `build/spec-328-*-failure-artifacts` 與 `build/spec-328-*-test.log`。
- 調查時發現全域 Pub cache 缺少既有 lockfile 所需的套件。以工作樹
  `build/spec-328-pub-cache` 作程序專用 cache，執行
  `flutter pub get --enforce-lockfile` 復原；`pubspec.yaml` 與
  `pubspec.lock` 雜湊不變。另於忽略的 `build/spec-325-tools` 放置經
  發行檔雜湊核對的 `jq`，只調整測試程序的 `PATH`，沒有更改系統設定。
  原失敗的 workflow 案例單獨通過，證據檔在原 45 秒時限下 11 項
  全數通過，並輸出 140 張 PNG。診斷副本將首個 compact-light 流程
  分段計時，三次均約 21–23 秒通過；先前逾時的根因仍未證實。
- 環境復原後，以同一份程式碼執行完整
  `flutter test --no-pub --concurrency 1 --reporter expanded`，
  **1995 項全數通過**（14 分 49 秒）。執行日誌保留於本機
  `build/spec-328-full-restored.log`；此結果與前述聚焦測試、分析共同
  構成本切片的提交前驗證。

這些是 App 自有填色、前景、幾何與操作證據。真機材質後驗仍依上一節
交給 #330，未將舊 run 或 headless 像素解讀為本票真機驗收。

## Root tab bar 與日期選擇器（#329）

固定起點為 `56daeb3e2ec64e039f07fc4213970f39a5248447`。
`TpNavigationGlassTabBar` 與 `TpNavigationGlassSelector` 將材質、前景、
選取底與無障礙降級收進同一導覽玻璃 module；呼叫端只提供分頁／日期
內容、選取與操作。兩者沿用既有光學設定入口，不共用錯誤的角色配方：
root tab 的媒體暗化仍為 35%，日期仍為 70% 中性底搭配完整 `onSurface`，
非媒體日期仍用 `onSurfaceVariant`，品牌 tint 只標示選取內容。

root tab 的 inline／bottom 幾何、分支內容及套件 tap／drag 保留。
原本補足套件缺口的指標穿透鍵盤／讀屏區域、選取後焦點回復仍在
`AppleRootTabBar`。日期仍保留方向鍵／Enter／Space、焦點、目前 Day
再次點選與具名讀屏 action；水平拖曳只瀏覽，不派發選取。Reduce Motion
仍由原 ScrollController adapter 將動畫改為直接定位；未修改 Day 同步模型。
舊 helper、scope 與其他導覽入口保持相容。

### 本切片 red → green

- 新 root tab 公開像素案例先記錄原行為，再暫時忽略媒體 scope，得到
  `Expected white / Actual black`；還原後通過，再遷移語意組裝。
  案例涵蓋 inline／bottom、明暗主題、白黑媒體背景，以及提高對比與
  降低透明度各自生效；檢查最終文字色與實際背景像素。
- 日期沿用真實 `TpHorizontalSelector` 的對比案例。暫將中性底從
  70% 改成 35%，得到 `Expected >= 4.5 / Actual 2.16873306642071`；
  還原後通過，再將中性底與前景配對收進共用 module。
- 操作 mutation 暫時移除目前 Day 的 tap callback，既有公開案例得到
  `Expected 1 / Actual 0`；還原後同一案例通過。它也守住拖曳不回呼、
  具名讀屏啟用、沒有空白按鈕節點，以及 Enter／Space 再次選取。
- root tab 與 shell 聚焦驗證 40 項通過；日期、真地圖可讀性與新 root tab
  案例合計 47 項通過。這些測試直接操作 App 控制項與既有畫面 seam，
  沒有新增測試專用介面；原始碼守門只檢查呼叫端未重新拼接設定。
- 最終 12 檔聚焦驗證 **321 項全數通過**（2 分 23 秒），包含完整
  HIG 十態矩陣、shell、timeline／map、日期操作、帳號／定位與共用玻璃。
  日誌保留於本機 `build/spec-329-focused-final.log`。
- 完整 `flutter test --no-pub --concurrency 1 --reporter expanded`
  為 **1996 項全數通過**（13 分 46 秒），包含畫面證據集的原 11 項案例
  及 HIG 十態矩陣。畫面案例仍使用原 45 秒時限，沒有跳過測試或放寬
  斷言；完整日誌保留於本機 `build/spec-329-full-final.log`。格式檢查
  與 `git diff --check` 通過。這些結果只代表 headless 驗證，真機材質
  後驗仍交由 #330，不以像素測試或歷史 build 代替。

### 隔離環境診斷

首次 `flutter analyze --no-pub` 在 492.2 秒後回報 18,496 個診斷；實際
路徑落在工作樹內 `build/spec-328-pub-cache/hosted` 的套件原始碼、測試
及 example，例如 `win32` 的 `package:checks/checks.dart` 缺失。過程中
language server 的 CPU 持續增加，未將等待誤判為停止進展，也未終止程序。

保留原始日誌後，將同一份 195 個 hosted 套件的隔離 cache 搬到工作樹外
專用 Temp 路徑，再以程序專用 helper 更新 `PUB_CACHE`，執行
`flutter pub get --enforce-lockfile`。`pubspec.yaml` 與 `pubspec.lock`
雜湊皆不變，生成的 package config 指向新 cache。沒有刪除舊驗證證據、
改全域環境、放寬測試時限或新增 analyzer 排除規則。

搬移後第二次 analyze 在 162.2 秒收尾，只剩 #328 忽略的計時診斷副本
`build/spec-328-diagnostics/app_owned_release_flow_artifacts_test.dart`
一個 `avoid_print` info。再將該診斷資料夾的兩份原件完整搬出工作樹到
專用 Temp 路徑保存，沒有修改副本內容或正式測試。

第三次 `flutter analyze --no-pub` 為 **No issues found**（23.0 秒），
零 error／warning／info；結果保留於本機 `build/spec-329-analyze-final.log`。
