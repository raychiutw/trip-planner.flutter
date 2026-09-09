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
| 選單 route host | 移除 App 舊 popup 定位／動畫 | 原生套件 route listener 在宣告式 Navigator build 更新時呼叫 OverlayPortal.hide，重現 persistentCallbacks 斷言；公開 root `OverlayEntry` 與 CompositedTransform link 隔離來源 route，來源換頁關閉，普通關閉等待套件 morph。items／enabled／theme／文字設定變動使 host 失效，相同項目重建則保留。不延遲業務 callback、不改套件私有 API |
| compact sheet | 舊 half／large shader recipe、93%／62% 高度、28／0 圓角、零 margin、重複預設參數 | `GlassModalSheetScaffold` 接手材質、幾何、展開與捲動交接；fixed `{large}`／resizable `{medium, large}`。App 保留 dirty／submitting／去重、內層優先返回、拒絕復位、theme child identity。PopScope 同意捨棄後等 frame 更新才返回，不用固定延遲 |
| regular sheet | 舊 Dialog 材質與陰影 | 公開 `GlassContainer` 接手材質／圓角；Dialog 只管理 route／鍵盤避讓，保留 560×720 上限及有界 Navigator。公開 `GlassSheet.show` 額外捲動與留白不適合此結構，未反推私有高度 |
| 地圖上的玻璃控制 | 共用舊 media 光學參數已於 #304 移除；不新增局部 recipe | 公開 `platformViewBackdrop` 選擇受支援共存路徑，配合媒體 scope 與暗化前景；不替換 SDK、不逐幀截圖。原生圖磚、手勢、marker／route 與其資料編碼色保留 |
| 聊天 composer | 直接承接 #304 共用預設，沒有剩餘局部 shader 可刪 | 輸入 1–4 行、附件／語音／送出、每行程草稿、Command–Return、安全區與鍵盤／tab 顯示是業務與配置契約；輸入欄使用語意內容填色，未再包玻璃 |
| 行程／外部 POI accessory | host 的局部 blur 已於 #304 移除；本次清除將 host 誤稱為可折射原生地圖的註解 | 只有 host 一層玻璃；內容卡的語意填色／選取提示不是 shader。PageView 水平瀏覽、marker 雙向同步、外部 POI 關閉復原、動態高度、map padding 與 tab clearance 為產品契約；穩定 `trip-map-poi-drawer` key 保留作既有定位，不表示具有 drawer 手勢 |
| 無障礙 | 不用 blur=0 冒充完整不透明降級 | 獨立 AppAccessibilityScope 原生 Reduce Transparency channel 保留；套件以 highContrast 近似的訊號不能取代它。任一提高對比／降低透明度都採不透明語意色、minimal 品質；邊界與 Reduce Motion 各自保留公開設定 |

### 媒體背景為何保留暗化

[DESIGN §9](../DESIGN.md)與 `tripMapColorScheme()` 的契約是圖磚維持既有日間樣式，App 深淺模式只改 controls／overlay。[媒體 scope 與前景](../lib/ui/tp_glass_surface.dart)不能單看 Theme brightness 決定圖磚前景。1.4.1 的公開 `platformViewBackdrop` 解決背景共存與裁切，並不提供原生圖磚亮度分析或替 App 選前景色；因此保留白色 bar 前景與 35% 黑色暗化，透過公開 `glassColor`／`platformViewFallbackColor`／fadeColor 傳入。35% 是現有產品取值，不宣稱 Apple 規定的通用數值，也不是重建舊 shader 外觀。

精確 1.4.1 中，`AdaptiveGlass` 的 `platformViewBackdrop` 走 live BackdropFilter 相容路徑；`PlatformViewGlassMode.passthrough` 是另一種 renderer 的無取樣區處理，不是讓 shader 取得原生地圖 texture。現有控制項已經用前者，不為採用新 API 名稱而改走後者或疊加截圖。實際圖磚黑塊、雙標籤、邊界與手勢仍必須由裝置證據確認。無障礙時上述半透明語意會被不透明 fallback 取代。

## #310 整合驗證

本票以 #309 為 fixed point，重新盤點 composer、POI accessory 與地圖控制項後，確認它們已承接共用預設，沒有為了產生 diff 而新增 production 行為。變動限於失效註解、研究基準標示及整合文件；不為文件製造無用測試。既有 HIG 十態、chat、trip map、shell、menu／sheet 及 app-owned flow 負責公開行為回歸。

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
