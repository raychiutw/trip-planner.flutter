# 導覽玻璃語意組裝驗證

本紀錄對應 [#325](https://github.com/raychiutw/trip-planner.flutter/issues/325)
的帳號與定位切片 [#327](https://github.com/raychiutw/trip-planner.flutter/issues/327)。

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
