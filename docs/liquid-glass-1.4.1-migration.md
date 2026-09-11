# Liquid Glass 1.4.1 遷移紀錄

規格：[#303](https://github.com/raychiutw/trip-planner.flutter/issues/303)；整合驗收：[#310](https://github.com/raychiutw/trip-planner.flutter/issues/310)。目標固定為 `liquid_glass_widgets 1.4.1`，pub archive SHA256 為 `c61ec2959004065c6f04b2b3bc0ed108eb379f328b27c7d8bf81ca1244afe14c`。

**狀態：程式遷移與可完成的本機驗證已完成，裝置驗收尚未完成。** 自動測試與 Android emulator 不能取代新／舊 iOS 真機的材質、原生地圖與效能證據。此文件列出已移除項目、仍需保留的產品整合與未完成驗收，不以版本升級或測試全綠代表 #303／#310 全部完成。

[套件選擇研究](research/2026-09-09-flutter-liquid-glass-options.md)保留升級前 `d286f6e5ea513266183a210707cca1bc76e5e66d` 的現況與當時判斷。使用者後續已同意新版公開預設及新外觀；70% 選取膠囊不再是產品限制。

## 實作基準與驗證

每個切片使用獨立 implement context，依已核准的公開 seam 逐一 red → green，完成 analyze、完整測試及 Standards／Spec 分軸審查後才提交。下表為各切片**最後**的完整 suite；中間失敗與修正前的綠燈不當作最終證據。

| 切片 | 完成 commit | 最後完整測試 | 代表性 red → green／負向驗證 |
|---|---|---:|---|
| #304 共用材質 | `6eab83146d80298fa7d52adb7f5311adbc854b60` | 1813 | 共用表面實際像素不符公開預設；舊半透明、忽略提高對比及忽略降低透明度各自 mutation 失敗 |
| #305 root tab | `ce56212d6956e2feeb91fc11aa4a7558f3242e71` | 1827 | 指標遮罩阻止拖曳、300% 文字被壓縮、鍵盤無回呼及前景色遺失，逐一重現後修正 |
| #306 日期選擇器 | `5a4c93a6c49e9db475b7bd2b7a5a92ade9cab422` | 1841 | 同數量 Day 重排後選取離開可見區、Reduce Motion 仍置中動畫、再次選取不回當日開頭 |
| #307 導覽外框 | `6eaf9cde7a12840f5e7040f93c5deada77fcd6bf` | 1847 | 放大群組文字省略、bar 溢位、鍵盤無回呼及帶狀遮蔽像素；未裁切模糊 mutation 確實抓到上一頁污染 |
| #308 選單 | `b2873a747c3266140e7a8a0d81945fa627d9fbff` | 1854 | 語意 tap 無回呼、Esc 失效、大字／Bold Text 裁切、導航 build-phase crash、舊 items 與相同內容重建生命週期 |
| #309 sheet | `c2d267d4f6b5e8c175165270e05856ec71057bd6` | 1882 | 公開預設高度／材質／圓角差異、dirty 拖曳漏確認、真正 push 的子頁捨棄後卡住、Reduce Motion 位移 |

上述每個切片的最後 analyze 均為 `No issues found`。Standards 無未解決硬性違規、Spec 無未解決確證發現；少量測試像素／fixture 重複的非阻擋建議保留，未為此擴大重構。#310 的 review fixed point 是 #309 commit，最終整合驗證結果見下節。

## 全範圍 workaround 去留

| 範圍 | 由套件接手並移除 | 仍保留及具體理由 |
|---|---|---|
| 初始化／主題／共用表面 | 舊 thickness、blur、色散、折射率、飽和度、Fresnel、光照及主題 alpha 校準；強制 premium；accessory 的 28pt blur 覆寫 | 公開 `initialize`、`GlassThemeVariant` 預設、品牌前景、平台自適應品質。`TpGlassSurface` 只整合語意、形狀與無障礙 |
| root tab | 自畫 70% 膠囊、activeIcon 疊層、TextPainter 反推、位移、負 expansion、舊 magnification／blend／glow 校準、指標遮罩 | 四分支／reselect／狀態、compact／regular、安全區與大字 barHeight。1.4.1 tab 的 keyboard／semantics 缺啟用回呼，保留穿透指標的薄轉接，套件仍處理點選／拖曳／繪製 |
| 日期選擇器 | 自畫軌道與選取底、option 寬度量測、手算置中、App ScrollView／Row、外包玻璃 | 公開 `GlassSegmentedControl.scrollable` 的 id／center／scroll；App 保留完整 Day 語意與自然內容、header 高度、方向鍵。套件置中未尊重 Reduce Motion，公開 controller 將 animateTo 轉 jumpTo；目前範圍 reselect 以最小 tap 與具名語意 action 補足 |
| 浮動 header／固定 bar／群組 | ToolbarSlots、sideWidth／widthFor 反推、群組自畫玻璃、GestureDetector、舊縮放校準 | `GlassAppBar`／`GlassButtonGroup`／透明 `GlassButton` 接手幾何與操作。浮動 header 的返回＋標題同組、帳號另組與 safe area 是產品組裝；群組 scope 防止巢狀玻璃 |
| 帶狀遮蔽 | 六層 BackdropFilter、逐層 sigma、55% 比例及手製漸層 | 公開 `ProgressiveBlur`＋`GlassScrollEdgeEffect.soft`。App 只保留內容／控制項層級、裁切、安全區與 `IgnorePointer`；媒體暗化用公開 fadeColor，獨立不透明區保證無障礙 |
| 選單面板 | RawMenuAnchor、手畫面板、Scale／Fade 動畫、手算定位／flipUp／高度原點、舊 shader recipe | `GlassMenu` 的定位、barrier、morph 與 `GlassMenuItem` 呈現接手。保留 autoAdjustToScreen、立即派發／去重、選取／disabled 原因／destructive、自然換行高度。表單 Dropdown 是內容值編輯，不是玻璃動作選單，繼續 system surface |
| 選單可及性／生命週期 | 不重建整套玻璃材質或選取動畫 | 1.4.1 非捲動項目 clone 的 semantics／keyboard callback 實測失效，以公開 `GlassMenuLabel` 包 `GlassMenuItem` 補操作；Esc、焦點、大字與 Reduce Motion 用公開轉接。此路徑採 item hover／focus／press，沒有套件滑動選取膠囊 |
| 選單 route host | 移除 App 舊 popup 定位／動畫 | 原生套件 route listener 在宣告式 Navigator build 更新時呼叫 OverlayPortal.hide，重現 persistentCallbacks 斷言；公開 root `OverlayEntry` 與 CompositedTransform link 隔離來源 route，來源換頁關閉，普通關閉等待套件 morph。每次 open 增加 generation，使舊 close 等待在重開後失效，避免持續排幀或誤移除新選單；新的 close 仍清除 host。items／enabled／theme／文字設定變動使 host 失效，相同項目重建則保留。不延遲業務 callback、不改套件私有 API |
| compact sheet | 舊 half／large shader recipe、93%／62% 高度、28／0 圓角、零 margin、重複預設參數 | `GlassModalSheetScaffold` 接手材質、幾何、展開與捲動交接；fixed `{large}`／resizable `{medium, large}`。App 保留 dirty／submitting／去重、內層優先返回、拒絕復位、theme child identity。PopScope 同意捨棄後等 frame 更新才返回，不用固定延遲；Reduce Motion 透過公開 controller 完成套件選定目標，關閉裝飾縮放／伸縮並在新尺寸下重新定位，詳見 [ADR-0010](adr/0010-account-as-sheet-not-fifth-tab.md) |
| regular sheet | 舊 Dialog 材質與陰影 | 公開 `GlassContainer` 接手材質／圓角；Dialog 只管理 route／鍵盤避讓，保留 560×720 上限及有界 Navigator。公開 `GlassSheet.show` 額外捲動與留白不適合此結構，未反推私有高度 |
| 地圖上的玻璃控制 | 共用舊 media 光學參數已於 #304 移除；不新增局部光學 recipe | 公開 `platformViewBackdrop` 選擇受支援共存路徑，配合媒體 scope 與暗化前景；日期依 ADR-0004 維持 70% 中性底與不透明 `onSurface`；帳號與定位依後續確認採共用 45% 黑色填色與白色符號，定位原有實色 Material 已改接公開 GlassButton；定位中改用同配方共用表面與 disabled 語意，避免套件整顆 disabled 淡化破壞不透明降級。不替換 SDK、不逐幀截圖；原生圖磚、手勢、marker／route 與其資料編碼色保留 |
| 聊天 composer | 直接承接 #304 共用預設，沒有剩餘局部 shader 可刪；「＋」與附件／新增行程項目入口由 #318 移除，輸入框從 leading 起延伸 | 輸入 1–4 行、語音／送出、每行程草稿、Command–Return、安全區與鍵盤／tab 顯示是業務與配置契約；輸入欄使用語意內容填色，未再包玻璃 |
| 行程／外部 POI accessory | host 的局部 blur 已於 #304 移除；本次清除將 host 誤稱為可折射原生地圖的註解 | 只有 host 一層玻璃；內容卡的語意填色／選取提示不是 shader。PageView 水平瀏覽、marker 雙向同步、外部 POI 關閉復原、動態高度、map padding 與 tab clearance 為產品契約；穩定 `trip-map-poi-drawer` key 保留作既有定位，不表示具有 drawer 手勢 |
| 無障礙 | 不用 blur=0 冒充完整不透明降級 | 獨立 AppAccessibilityScope 原生 Reduce Transparency channel 保留；套件以 highContrast 近似的訊號不能取代它。任一提高對比／降低透明度都採不透明語意色、minimal 品質；邊界與 Reduce Motion 各自保留公開設定 |

### 媒體背景為何保留暗化

[DESIGN §9](../DESIGN.md)與 `tripMapColorScheme()` 的契約是圖磚維持既有日間樣式，App 深淺模式只改 controls／overlay。[媒體 scope 與前景](../lib/ui/tp_glass_surface.dart)不能單看 Theme brightness 決定圖磚前景。1.4.1 的公開 `platformViewBackdrop` 解決背景共存與裁切，並不提供原生圖磚亮度分析或替 App 選前景色；因此保留白色 bar 前景與 35% 黑色暗化，透過公開 `glassColor`／`platformViewFallbackColor`／fadeColor 傳入。35% 是現有產品取值，不宣稱 Apple 規定的通用數值，也不是重建舊 shader 外觀。

精確 1.4.1 中，`AdaptiveGlass` 的 `platformViewBackdrop` 走 live BackdropFilter 相容路徑；`PlatformViewGlassMode.passthrough` 是另一種 renderer 的無取樣區處理，不是讓 shader 取得原生地圖 texture。原有玻璃控制項使用前者；定位按鈕當時仍是實色 Material，直到 2026-09-10 後續透明度修正才接上公開 GlassButton，現在兩顆獨立圖示均使用前者。其餘控制項也不為採用新 API 名稱而改走後者或疊加截圖。實際圖磚黑塊、雙標籤、邊界與手勢仍必須由裝置證據確認。正常媒體表面的 bar 前景預設為白色；日期依 [ADR-0004 的 2026-09-10 更正](adr/0004-neutral-selection-surface-with-tinted-foreground.md)維持 70% `surfaceContainerLow` 與不透明 `onSurface`；後續使用者確認只取代帳號策略，帳號與定位採共用 45% 黑色填色配白色符號，其他媒體表面的 35% 暗化值不變。提高對比或降低透明度任一開啟時，不透明 fallback 已遮住媒體，bar 前景改用 `colorScheme.onSurface`，不再沿用白色。品牌選取前景仍使用既有 `primary`；遷移時新增的 tab 像素對比矩陣只量未選取文字，不代表所有選取文字或實機可讀性均已通過。

## 收尾修正與最新本機驗證

`58f47d8` 以自然失敗測試重現探索自訂地區 sheet 離場時過早釋放 `TextEditingController`，改由表單內容 state 在卸載時釋放；另補移動段 consumer 收到 409／503 後保留輸入及解除送出鎖定的測試。後者刻畫既有錯誤處理，不宣稱新增 OCC 衝突重抓或恢復能力。`b3c54f8` 修正媒體不透明降級前景與 sheet 返回圖示 tint。`7ccbc1e` 補自訂選單入口 Tooltip，並以真正時間軸的 Semantics longPress 重現關閉途中重開後持續排幀，再以 open generation 隔離舊等待。三次修正均完成 fresh implement、red → green、完整測試及提交前 Standards／Spec 兩軸審查。

前次本機驗證的程式基準為 `7ccbc1e46b4efaf9a4c1295b995a793d8ca737b8`／`0.26.3+34`：357 個追蹤 Dart 檔格式檢查零變更；`flutter analyze` **17.7 秒、No issues found**；完整 `flutter test` **1892 項通過、3 分 34 秒**；Android debug APK **39.2 秒建置成功**。整合 worktree 的 `.scratch/liquid-glass-upgrade/final-checks-result.txt` 為 PASS，對應 `final-format.log`、`final-analyze.log`、`final-tests.log`、`final-android-build.log` 及 `final-verified-head.txt`。本次文件收尾不改 production 行為；這批結果不重新標記為文件 commit 上執行。

同次 suite 產生 140 張 PNG，共 2,458,561 bytes，保留於主 worktree 的 `.scratch/liquid-glass-upgrade/after-final-7ccbc1e`；整合 worktree 的 `final-artifacts-manifest.json` 記錄 source SHA 與版本。測試字型方框與 fake map 只提供幾何證據。以下 #310 的 1882 項 suite、`c2d267d`／`0.25.8+33` Android 裝置流程及失敗嘗試保留原始歸屬；最新 APK 建置成功不表示已重新完成裝置操作或材質驗收。

`21fffb60b0632e8c9bd746681332113fa3549656` 僅修正 `test/ui/tp_app_bar_test.dart` 載入 SDK 字型時的大小寫，改為壓縮檔內實際的 `Roboto-Regular.ttf`／`Roboto-Bold.ttf`，避免 Linux 區分大小寫時找不到檔案。`release-ci-font-red.log`／`release-ci-font-green.log` 保留修正前後的精確檔名比對；真實字重、長標籤與勾號的公開測試斷言不變，且已完成 Standards／Spec 兩軸審查。

這次字型修正提交前的 **Windows 本機驗證**：357 個追蹤 Dart 檔格式檢查零變更、`git diff --check` 通過；`flutter analyze` **129.3 秒、No issues found**；完整 `flutter test` **1892 項通過、5 分 36 秒**；Android debug APK **58.8 秒建置成功**。證據位於 `.scratch/liquid-glass-upgrade/` 的 `release-ci-font-format-green.log`、`release-ci-font-diff-check.log`、`release-ci-font-analyze.log`、`release-ci-font-full.log` 與 `release-ci-font-android-build.log`。版本仍為 `0.26.3+34`；這批紀錄不代表 Linux CI、真機驗收或正式上架已完成，也不改寫上述舊 SHA 的證據歸屬。

`d9d5c42f037d8d55d994c136c857eaf864ed2287` 補齊 Reduce Motion 下慢拖放手後仍吸附彈動、觸碰縮放與上拉伸縮的缺口。App 只在公開 `progressListenable` 的 Ticker frame 以 `currentState`／`snapToState(animate: false)` 完成套件已選定目標；直接拖曳及 pointer resampling 不受介入。旋轉後等 `MediaQuery` 尺寸更新，再由公開 controller 重取目標，不自行計算 detent 或物理。一般態沿用公開建構子預設，草稿、鍵盤與關閉保護保留。

這次修正提交前的 **Windows 本機驗證**：33 項 sheet 測試通過；357 個追蹤 Dart 檔格式檢查零變更；`flutter analyze` **166.7 秒、No issues found**；完整 `flutter test --concurrency=2` **1903 項通過、6 分 9 秒**；Android debug APK **45.2 秒建置成功**。證據位於 `.scratch/liquid-glass-upgrade/` 的 `reduce-motion-fix-targeted-02.log`、`reduce-motion-fix-format-final.log`、`reduce-motion-fix-analyze-final.log`、`reduce-motion-fix-full-concurrency2.log` 與 `reduce-motion-fix-android-debug-final.log`。Standards／Spec 與跨模型增量審查沒有新增確證缺陷，見同目錄的 `reduce-motion-fix-review.md` 與 `motion-delta-claude-triage.md`。

預設並行度的完整 suite 曾有一項畫面產物案例超過原有 45 秒限制，失敗保留於 `reduce-motion-fix-full-final.log`；原案例單跑 **17 秒通過**（`reduce-motion-fix-artifact-timeout-retry.log`），再以並行度 2 完整跑綠，未放寬時間限制或斷言。版本仍為 `0.26.3+34`，以上證據歸屬於 `d9d5c42` 的程式與測試，不重標為後續文件 commit 上執行。動畫中切換設定／尺寸及一般態旋轉並未由此批測試完整驗證；既有 `7ccbc1e`、`21fffb6` 及 #310 的紀錄保持原歸屬，真機義務仍未完成。

地圖可讀性修正 `fd26a06` 與測試補強 `ef1e323` 僅調整媒體日期／帳號的底色及前景，並驗證實際元件合成像素、200% 文字、獨立不透明降級、日期操作及帳號導航。`3e04048f6453bd02c5f7386c090e18d8faf8b388`／`0.26.4+35` 發行前的 **Windows 本機驗證**：358 個追蹤 Dart 檔格式檢查零變更；`flutter analyze` 零 error／warning，7 個 info 均在未追蹤的 `build/debug-map-legibility/` 診斷檔；完整 `flutter test` **1916 項通過、9 分 25 秒**；Android debug APK **359.8 秒建置成功**。證據位於 `map-glass-legibility` worktree 的 `build/map-ship-format-batched.log`、`build/map-ship-analyze-final.log`、`build/map-ship-full-test-final.log` 與 `build/map-ship-build-final.log`。此批測試與建置不代表原生 PlatformView、Impeller 或真機材質驗收，也不改寫先前版本的證據歸屬。

## #310 整合驗證

本票以 #309 為 fixed point，重新盤點 composer、POI accessory 與地圖上的既有玻璃控制後，確認這些玻璃表面已承接共用預設，沒有為了產生 diff 而新增 production 行為。變動限於失效註解、研究基準標示及整合文件；不為文件製造無用測試。既有 HIG 十態、chat、trip map、shell、menu／sheet 及 app-owned flow 負責公開行為回歸。

2026-09-09 最終完整 `flutter test` 為 **1882 項通過，4 分 44 秒，exit 0**；suite 結束後獨立執行 `flutter analyze --no-pub`，**30.3 秒、No issues found、exit 0**。三個 Dart 檔格式化後仍只有註解差異；文件與註解沒有新增產品行為。Standards／Spec 最終增量審查已核對 logs、140 張 PNG 與 Android 結果：零新增硬性違規、零新增 smell、零確證 Spec 違反；自動證據待補項已解除，硬體驗收仍未完成。

同次 suite 重新產生 140 張 PNG，保留於主工作目錄 `.scratch/liquid-glass-upgrade/after-310`，未覆寫先前 baseline／after-304。抽查 chat compact 300% 文字及 map POI Dark 畫面，composer／accessory 與 root tab 幾何可分離；測試字型方框及 fake map 的證據限制如下，不能擴稱文字可讀或原生地圖材質通過。詳細 log 為 `310-full-final.log`、`310-analyze-verified.log`；初次 analyze 與 suite 短暫重疊後被中止的 log 也保留，不列為 PASS。所有 Flutter runner 已結束。

### Android 本機執行（2026-09-09）

**PASS：原有 `integration_test/app_smoke_test.dart` 的整套 app-owned flow**，1 項整合測試、2 分 17 秒，process exit 0。裝置為本任務新建 `Tripline_LiquidGlass_310` AVD／`sdk_gphone64_x86_64`，Android 15／API 35，APK `0.25.8+33`，執行邏輯基準為 `c2d267d4f6b5e8c175165270e05856ec71057bd6`；本票 Dart 差異只有註解。SDK 為 `C:/flutter` 3.44.7／Dart 3.12.2，debug build 156.9 秒、安裝 24.9 秒。執行旗標 `--no-enable-impeller`，emulator 使用 OpenGL SwiftShader 並停用 Vulkan；這是本次命令的 Skia 降級驗證，沒有修改 App 預設 renderer。

沿用[既有 fixture](../integration_test/support/app_flow_fixture.dart)，通過 Welcome／Login、四個 root tabs、行程／Day、筆記、地圖／時間軸切換、行程及外部 POI、Account 與外觀切換、聊天草稿、收藏分支恢復、表單、刪除確認、離線／錯誤／恢復。repositories 與 map canvas 為既有 fake，不呼叫正式服務，故此結果不證明原生圖磚。fixture 的鍵盤視窗注入是可選參數，此裝置入口未傳入，不能將此 PASS 擴稱完整鍵盤避讓驗收；該行為由既有 shell／chat／畫面矩陣測試及待完成的實機操作分別覆蓋。

前面嘗試的失敗均保留，沒有被最後的 debug PASS 抹除：

| 嘗試 | 結果與解讀 |
|---|---|
| 原 Pixel_8_API_35／debug | APK 134,913,318 bytes 建置成功；AVD 僅餘 472 MB，安裝報 `INSTALL_FAILED_INSUFFICIENT_STORAGE`，未開始測試。原 AVD 的其他 App 與資料保留 |
| 原 AVD／profile | 改用 SDK 公開 integrationDriver 執行同一 target，APK 87,868,257 bytes 成功安裝；測試剛開始 emulator 整個程序退出並產生 crash dump，driver 報 `(112) Service has disappeared`。尚未確證退出原因，不能將 Vulkan 日誌當成 root cause |
| 原 AVD／profile＋Skia | emulator 未自行退出，但登入前實際 FAIL：`app_flow_fixture.dart:435` 沒有 `MockAuthRepository.login` 呼叫，畫面仍顯示必填提示。profile 文字輸入驅動是調查線索，不宣稱產品登入缺陷；記錄失敗後停止該 AVD，後續 driver 斷線是主動停止所致 |
| 隔離 AVD／原 debug＋Skia | 保持原 fixture、不換登入流程，完整操作通過。未用 profile 失敗去修改 production 或放寬斷言 |

隔離 AVD 設定資料 3 GB／RAM 2 GB、停用 snapshot；API 35 映像實際建立 5.8 GB 稀疏資料分割區，測試期間主機仍保留逾 4 GB。兩個使用過的 emulator 均已停止，沒有清除原 AVD、調低系統儲存門檻或維修 SDK。

本機沒有 `GOOGLE_MAPS_ANDROID_API_KEY`，主／本 worktree 也沒有 `android/maps.properties`；原生 map 測試欠合法金鑰，未執行並列為待驗。全域 Patrol CLI 是 4.4.0、repo 要求 4.6.1，未覆寫全域工具；相同 app-owned fixture 已由原 integration_test 入口驗證，不為重複 coverage 另建 Patrol 環境。完整紀錄位於執行 worktree 的 `.scratch/liquid-glass-upgrade/310-*`，包含原失敗 log、裝置 JSON 與中途截圖；中途截圖不是穩定版面或 shader PASS。

### 證據邊界

- widget 像素比較使用套件公開 minimal 品質，驗證幾何、合成、選取移動與獨立不透明降級，不驗 Impeller shader 光學或效能。
- 1.4.1 在 `FLUTTER_TEST` 下以套件自身的 bare `shaders/...` 路徑初始化，consumer bundle 卻是 `packages/liquid_glass_widgets/shaders/...`。已診斷的 asset-not-found 不等於正常 App 初始化失敗；保留 production 公開 initialize，沒有路徑覆寫、私有 API 或 vendor。
- headless ProgressiveBlur 是 uniform fallback；140 張 PNG 的部分中文字與符號為測試字型方框，只能判斷幾何，不當作平台字型或 shader 驗收。
- Android emulator 的 renderer、CPU／GPU 與實機不同；操作結果不能用作 iOS 16／新 iOS 真機材質或持續捲動效能證據。

## #319 真機整合驗收（2026-09-11，iOS）

- source `a5e44f9baeea8b027d9fe02d210eeeb6da76bfe8`（tree 與 PR #320 head `e3ee862` 相同）；App 內帳號頁尾實際讀到 `0.26.6 (37)`；`liquid_glass_widgets 1.4.1`；release 模式。
- run [34573355723](https://github.com/raychiutw/trip-planner.flutter/actions/runs/34573355723)（platform=all），artifact `mobile-e2e-ios-34573355723-1`（ID 10189228441）；Firebase Test Lab iPhone 14 Pro／iOS 16.6／en_US／portrait。4 tests 全過：app-owned release flow 83.6 秒（release AOT 已通過公開 Day Semantics 讀取）、visual evidence 133.7 秒、native map smoke 33.8 秒。
- 品質時間線（`syslog.txt` 裝置時鐘）：00:27:41 premium 預熱完成；00:28:43 thermalDegradation 降 standard；00:29:01 thermalRecovery 回 premium。夾在中間的 `light/chat-draft-after-account-close`、`light+increased-contrast/*`、`light+reduce-transparency/*` 不是 premium 證據（後兩組本來就是 App 指定的 minimal）。
- 影片 1178×2556、10 fps、88 秒，PTS 與 251 秒測試 wall time 不等價；只用來取畫面，不推算動畫時長。量法沿用 ADR-0004：邊緣峰值 − 內部填色，逐像素掃四邊。

| 表面 | 情境 | 結果 |
|---|---|---|
| plain「⋯」（行程卡） | light／dark trips-list | 一般態無框、灰字符；提高對比補圓形實心邊 ✔ |
| 浮動 header 標題膠囊／bar button | light | 白底上四邊 +3～+4，無白框 ✔ |
| 同上 | dark | 四邊均一亮環 +73～+78；參考頂 +50、側 0 → **確證差異**，已改 Fresnel 0.5，待重驗 |
| root tab bar | dark | 左／上／下 +112／+112／+102；參考頂 +66、側 0 → **確證差異**，同上待重驗 |
| 選單面板 | light／dark trip-card-menu、timeline-header-menu | 三格快捷、分組線、刪除紅 ✔；面板最低亮度 1–18，後方卡片黑帶、白標題與「⋯」穿透（參考 41–42）→ **確證差異**，已改 regular 配方，待重驗 |
| 選單面板 | +increased-contrast | 不透明 ✔ 但黑面板對黑頁面無邊界（0 對 0）→ 已改 `surfaceContainerHigh` 底，待重驗 |
| 固定 bar（共編設定） | light collab-from-trip-card-menu | 返回＋標題群組、帳號另組 ✔ |
| 日期選擇器 | light timeline-day-2；light／dark map | 文字底中性選取底；媒體上 70% 底與不透明字 ✔ |
| 聊天 composer | light／dark chat-composer、draft | 無「＋」、輸入框自 leading 延伸、麥克風／送出切換、草稿保留 ✔；深色 accessory 亮環同 header（已改、待重驗） |
| 行程 POI accessory | light／dark map-day-1 | 暗化 host、內容卡實色、tint 頁點 ✔ |
| 地圖控制項（帳號／定位） | light／dark map | 45% 黑底白字符、無亮環（frosted 路徑）✔ |
| 帳號 sheet | light／dark account-sheet、map-account-sheet | 由下進場、接近全高、頂緣留狀態列溝槽、圓角、實色內容 ✔；深色底為 base `surface` 黑，對黑頁面沒有可辨識邊界，參考影片是 elevated 深灰 `#1C1C1E` → **確證差異**，已改 `AppTheme.elevated`（深色 surface 三階上移一階），待重驗 |
| 提高對比／降低透明度 | light／dark ×（trip-card-menu、map） | 導覽玻璃、地圖 chrome 皆不透明；提高對比補實心邊 ✔ |
| Reduce Motion | light／dark ×（trip-card-menu、account-sheet、map） | 畫面內容與狀態正確；動畫是否取消無法由 10 fps 影片 PTS 判定，列未驗證 |

未覆蓋（iOS 沒有畫面，不標 PASS）：列印固定 bar「⋯」、停留點卡／筆記列／共編成員／分享連結的 plain「⋯」、探索地區與分類 chip 入口、regular／橫向、2× 字級、Bold Text；輔助使用 flags 為測試 wrapper 注入，不等於 OS 設定或 VoiceOver。Android `MediumPhone.arm`／API 34 虛擬機本輪 integration 在 fixture:779 失敗、Patrol 未跑，由另一 session 處理 harness；本節不含任何 Android 結果。

上表「已改、待重驗」的三處（`tpNavigationFresnelStrength`、`tpMenuGlassSettings`、sheet 的 `AppTheme.elevated`）在本 run 都不是驗收通過，重驗結果見下節。standard 品質期間唯一的一般態情境（`light/chat-draft-after-account-close`，PTS 58.6–58.8）composer 邊緣 246–248 無描邊；PTS 58.9 起的黑色實線與全白底是 wrapper 注入 Increase Contrast 後的 minimal 降級（記錄在 00:28:49 的 `light+increased-contrast/*` 之前），不是 standard renderer 問題，`glowIntensity` 未動。

### 0.26.7 重驗與 0.26.8 待驗（run 34582660390）

- source master `30f05063a913427b1188f45ef453e064a8f45c51`（PR #321 合併）；App 內帳號頁尾實際讀到 `0.26.7 (38)`；run [34582660390](https://github.com/raychiutw/trip-planner.flutter/actions/runs/34582660390)（platform=all），同一 iPhone 14 Pro／iOS 16.6 與同一量法。`test_result_0.xml` 4 tests 全過（267.1 秒），Test Lab 外層 5 分鐘逾時由 0.26.8 的預算放寬處理（見 [mobile-e2e.md](mobile-e2e.md)）。深色一般情境多落在 thermalDegradation 後的 standard 品質窗，premium 對照只來自 reduce-motion 注入的三景。
- 改善成立：選單面板最低亮度 38～45、字形不可辨識（參考 41–42）；提高對比的選單邊界深 44 對 0、淺 230 對 255；深色帳號 sheet 底 27（`#1C1C1E`）、grouped 卡片 44，對黑頁面有邊界。淺色 header 白底維持 +0～+4。
- 未達預期：`fresnelStrength` 0.5 只讓 header 圓鈕／標題膠囊由 +73～+78 降到 +57～+65（約 −18%），root tab bar 幾乎沒變（+95～+110），仍是全周環。歸因更正與 0.26.8 新增的兩項偏離（`tpNavigationLightIntensityScale` 0.35、深色 `tpNavigationDarkEdgeAbsorption` 0.3）記錄在 `DESIGN.md` §16.2 與 [ADR-0004](adr/0004-neutral-selection-surface-with-tinted-foreground.md)「邊緣光第二次更正」；兩者仍是公式推估，**待 0.26.8 真機重量測 root tab bar 與 header 四邊峰值才算驗收**，本 run 的影像不能當作新光照通過；重驗結果見下節。
- 未覆蓋範圍與上一 run 相同（OS 設定／VoiceOver、regular／橫向、2× 字級、Bold Text、未逐入口操作的選單）；同 run 的 Android 結果只用於預算推導（見 [mobile-e2e.md](mobile-e2e.md)），不作材質證據。#303／#310 相關驗收項維持未完成。

### 0.26.8 重驗與 0.26.9 標題前景補修（run 34591742975）

- source master `816ef76fa30b030f31798f8b3cbef08207b6a57c`（PR #322 合併）；App 內帳號頁尾實際讀到 `0.26.8 (39)`；run [34591742975](https://github.com/raychiutw/trip-planner.flutter/actions/runs/34591742975)（platform=all）。iOS 同一 iPhone 14 Pro／iOS 16.6 與同一量法：attempt 1 裝置離線、底圖全白（地圖不可驗收）；attempt 2 的 8 個地圖情境都載入真實圖磚。兩次 app-owned flow 與 visual evidence 都 PASS，native map smoke 都 FAIL（`onMapClicked` 9 次但 POI callback null），失敗紀錄保留、不重跑求綠。
- 高光改善成立（iOS 實機、深色 premium 窗，PTS 69.50／69.70 兩幀一致）：header 圓鈕 +63／+65／+59／+60 → **+47／+33／+43／+32**、標題膠囊 +63／+57／+58 → **+45／+43／+30**、root tab bar +110／+110／+95 → **+71／+68／+52**（高於推估的 +58／+44，但最亮側已落到參考迷你播放器頂緣 +66 的量級）；composer accessory 左緣 +24 → +2。全周白光減弱 25～50% 並轉為主光側亮、對側暗，未退化成黑框或糊字。側邊仍有細環是套件雙向 lobe 寫死的公開能力極限，root 檢視代表幀後接受目前細邊與方向性，不再加光照修正。淺色白底 header 圓鈕 +1～+4、無新增暗框；選單、帳號 sheet、提高對比邊界與 0.26.7 相同。
- 地圖 chrome（attempt 2 真實圖磚）：帳號／定位、日期選擇器、行程 POI accessory、root tab bar 在 Light／Dark 一般態與注入的 Increase Contrast／Reduce Transparency 下可讀、無亮環、無黑框；標題膠囊的暗化材質亦同。
- **標題文字缺口（#319 補修）**：淺色主題在媒體上的標題文字是黑色 `#000000` 壓在 (63,83,90) 的暗化膠囊上，對比只有 2.56～2.60:1（PTS 50.00／50.50／64.50 靜止幀），chevron 4.5:1 正常；0.26.6／0.26.7 的同情境幀量到一致，至少 0.26.6 已存在的既有缺陷，不是 0.26.7／0.26.8 材質修正引入，也違反 `CODING_STANDARDS.md` 導覽玻璃 17pt 文字 4.5:1 的規則。root cause：`TripTitleButton` 的標題 `Text` 指定 `textTheme.titleLarge`，該字階自帶 `onSurface`，蓋掉 `TpBarForeground` 往下傳的媒體前景；深色只因 `onSurface` 是白才看不出來。0.26.9 改為明確帶回 bar 前景，回歸測試讀 `RenderParagraph` 的有效文字色驗證淺色媒體白字、單一行程停用切換仍白、深色白、Reduce Transparency／Increase Contrast 回 `onSurface`、非媒體 header 仍 `onSurface`（`test/ui/tp_map_controls_legibility_test.dart`、`test/features/trips/trip_title_button_test.dart`）。**0.26.9 尚無真機影像**：白字對暗化底 ≥ 4.5:1 待 PR 合併後以同 source 重跑 iOS 取證，本節不宣稱已實測；widget test 只證明渲染文字色，不代替材質合成驗收。
- Android（`MediumPhone.arm`／API 34 虛擬裝置、Patrol debug，非實機）：integration 與 Patrol app-owned／visual evidence PASS；native map FAIL 於 `native_map_smoke_test.dart:119`（`nativeMapDoubleTapObserved` 15 秒未出現；logcat 兩次 `ACTION_DOWN` 相距 303ms、地圖收到兩次單擊，推論是測試橋接的同步點擊落在辨識邊界，記錄在 #310，不因本次 UI 發布宣稱 Android E2E 通過）。adaptive quality 在 04:47:25 以 p75 452ms 由 premium 降到 minimal，之後所有深色情境的 rim 構造上為 0，不能驗證 `lightIntensity`／`edgeAbsorption`。已載入圖磚上的媒體 chrome 可讀、無黑框；選單最低亮度 58 無穿透；帳號 sheet 底 27／卡片 44；提高對比邊界 43～46 對 0。早期淺色 map 情境底圖空白，不作媒體證據。
- 未覆蓋不變：Reduce Motion 動畫（10 fps／4 fps 影片不可判定）、OS 真實輔助設定／VoiceOver／TalkBack（flags 為 wrapper 注入）、regular／橫向、2× 字級、Bold Text、列印固定 bar 與各 plain「⋯」入口；原生地圖手勢／POI callback 兩平台皆保留失敗，#303／#310 相關驗收項維持未完成。

## 尚未完成的裝置驗收

以下仍需針對同一可追溯 source SHA、版本／build，記錄裝置、OS、設定、步驟、實際觀察與證據位置；不以過往 master build 代替本次 feature build。[完整人工報告格式與必要 case](mobile-e2e.md)維持原契約。

| 場景 | 裝置／操作 | 通過條件 |
|---|---|---|
| 材質與首次顯示 | 新 iOS 真機、iOS 16 舊版降級、Android；冷啟動與四個 root tabs | 無首次 shader 空白／黑塊，標籤不重複，材質／降級可讀；需明確區分 emulator 與實體裝置 |
| 地圖原生共存 | Light／Dark，行程／總覽地圖，開選單及 sheet、返回／重建 | pan、pinch、rotate、double-tap 與空白觸控正常；控制項不被模糊或遮擋，圖磚與標籤無黑塊／重影 |
| composer 與 accessory | 鍵盤開關、切 tab／行程、開 Account、外部 POI／關閉 | 草稿與分支狀態保留，composer 在鍵盤上方，POI 水平與 marker 同步，safe area／tab 不重疊 |
| 文字與可及性 | compact／landscape／regular／split；大字、Bold Text、VoiceOver、鍵盤等 | 文字／符號可讀、44pt 操作區、焦點順序正確，必要操作無裁切；獨立切換 Contrast／Transparency／Motion |
| 持續操作效能 | 同裝置升級前／後對照，持續列表／地圖捲動及 menu／sheet 切換 | 記錄實際 raster／frame 表現與可觀察卡頓，不能用 host 測試耗時推論效能 |

本機 Windows 沒有 iOS runner。既有 `mobile-e2e` Test Lab workflow 保持 master-only，不削弱限制來替 feature branch 取證；商店流程不在本次驗證中觸發。取得必要硬體證據前，#303／#310 的相關驗收項維持未完成。

### 選單入口覆蓋清單（#314／#316）

#314 要求以使用者提供的 Apple Music 參考圖對照全 App 一般動作選單。下表是 #315／#316 完成後的全部入口；widget test 只證明幾何、內容、可及性與回呼，**每一列的材質、透明／模糊層級、白框、邊緣高光與展開動畫都尚未以真機比對**。驗收時逐列記錄 build／commit、裝置、OS、明暗與無障礙設定，並保留修改前後畫面。

| 入口 | 觸發器 | 內容 | 真機比對重點 |
|---|---|---|---|
| 行程清單 header「⋯」 | 浮動 header bar button（玻璃） | 新增行程、匯入 JSON；排序值選項勾選 | bar button 高光、面板材質、勾選對齊 |
| 行程卡「⋯」／長按 | 內容卡 plain「⋯」 | 上排分享／共編／AI 健檢，匯出 JSON，分組刪除 | 無白框、三格並排、刪除紅 |
| 收藏 header 排序篩選 | 浮動 header bar button（玻璃） | 排序值選項勾選，篩選條件，窄寬大字時新增景點 | 同上 |
| 收藏卡「⋯」／長按 | 內容列 plain「⋯」（heart 之後） | 加入行程、選取，分組刪除 | 無白框、與 heart 並置的間距、刪除紅 |
| 探索地區 | 內容文字入口（`TextButton.icon`） | 地區值選項勾選，分組「自訂地區…」 | 從文字入口附近展開、勾選對齊 |
| 探索「更多」分類 | 內容 chip（`ChoiceChip`） | 分類值選項勾選，含數量 | 從 chip 附近展開、選中 chip 狀態 |
| 新增停留點地區 | 內容文字入口 | 地區值選項勾選 | 同探索地區 |
| 時間軸 header「⋯」 | 浮動 header bar button（玻璃） | 調整順序、筆記；行程資料、列印、異動紀錄、分享連結、共編設定、AI 健檢 | 圖示與行程卡同字符 |
| 停留點卡「⋯」／長按 | 內容卡 plain「⋯」 | 重新排序、換景點；編輯、移動；複製；分組刪除 | 無白框、四組分隔線、停用原因 |
| 筆記列「⋯」／長按 | 內容列 plain「⋯」（只在可交還 AI 的列） | 交還 AI 維護 | 無白框、與拖曳把手並置 |
| 列印「⋯」 | 固定 bar bar button（玻璃） | 匯出 PDF | bar button 高光、進行中 spinner |
| 共編成員「⋯」 | 內容列 plain「⋯」 | 角色值選項勾選，分組移除成員 | 無白框、移除紅 |
| 分享連結「⋯」 | 內容列 plain「⋯」 | 編輯、重新產生；分組撤銷、刪除 | 無白框、破壞性組 |

聊天 composer 的「＋」與加入內容選單由 #318 移除，不在清單內。破壞性確認、表單值欄位、日期／時間 picker 與 OS 分享／檔案介面維持原本的 sheet／alert，不屬於一般動作選單。
