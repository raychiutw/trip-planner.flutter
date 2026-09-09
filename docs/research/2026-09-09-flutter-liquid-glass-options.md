# Flutter Liquid Glass 套件選擇研究

> **升級前研究基準**：本文保留 `d286f6e5ea513266183a210707cca1bc76e5e66d` 的研究判斷；下文的「目前」、0.23.0、自畫 70% 選取指示與選單現況均指該基準，不代表升級後程式。後續 #303 已核准採用 1.4.1 公開預設，不再維持 70% 外觀；實作去留、驗證結果與未完成的裝置驗收見[遷移紀錄](../liquid-glass-1.4.1-migration.md)。人氣數據仍是本次查核日期的快照。

查核日期：2026-09-09。專案基準：`d286f6e5ea513266183a210707cca1bc76e5e66d`。本次是文件與原始碼研究，沒有升級 dependency、執行候選套件或做真機效能比較。以下「建議」是依本專案限制做的工程判斷，不是實測排名。

## 結論

**以本次查核候選的近 30 天下載量衡量，`liquid_glass_widgets` 第一；以累積 pub.dev likes 衡量，`liquid_glass_renderer` 第一。** 若要真正的 iOS 原生控制項，人氣與近期維護都值得比較的是 `adaptive_platform_ui` 和 `cupertino_native_better`。因此不能只以容易升級決定，也不能把「最受歡迎」與「最像 Apple」當成同一個排名。數據與來源見下一節。

本次建議的比較名單是 `liquid_glass_widgets`、`liquid_glass_easy`、`adaptive_platform_ui`、`cupertino_native_better`；`liquid_glass_renderer` 作為底層自訂路線另評。專案目前要求 iOS 16+、Android 共用 iOS 26 視覺，這會影響整合取捨，但不影響人氣數據本身。[DESIGN.md](../../DESIGN.md)、[ADR-0009](../adr/0009-universal-ios-hig-width-driven-layout.md)

## 目前誰最受歡迎

2026-09-09 直接查詢 pub.dev search 的 `liquid glass` 前四頁，再補入原生與近期候選，共 44 個去重套件；這是有界市場盤點，不宣稱涵蓋全部 pub.dev。下載量採 score API 的 `downloadCount30Days`，likes 採 `likeCount`；GitHub stars 另由 repository API 查詢。頁面快取與 live API 可能相差少量數字，以下固定採同一輪 API 快照。[搜尋 API](https://pub.dev/api/search?q=liquid%20glass)

| 下載排名 | 套件 | 近 30 天下載 | pub.dev likes | GitHub stars | 最新發布版本 |
|---:|---|---:|---:|---:|---|
| 1 | liquid_glass_widgets | 56,213 | 261 | 579 | 1.4.1 |
| 2 | liquid_glass_renderer | 24,062 | 886 | 440 | 0.2.0-dev.4 |
| 3 | liquid_glass_easy | 10,789 | 255 | 113 | 4.2.0 |
| 4 | adaptive_platform_ui | 10,299 | 386 | 239 | 0.1.111 |
| 5 | cupertino_native_better | 7,206 | 81 | 42 | 1.6.0 |
| 6 | cupertino_native | 3,217 | 343 | 171 | 0.1.1 |
| 7 | native_liquid_glass | 1,741 | 11 | 未查 | 0.2.15 |
| 8 | cupertino_native_plus | 1,097 | 15 | 未查 | 0.0.11 |

下載／likes 一手來源：[widgets](https://pub.dev/api/packages/liquid_glass_widgets/score)、[renderer](https://pub.dev/api/packages/liquid_glass_renderer/score)、[easy](https://pub.dev/api/packages/liquid_glass_easy/score)、[adaptive](https://pub.dev/api/packages/adaptive_platform_ui/score)、[native_better](https://pub.dev/api/packages/cupertino_native_better/score)、[native](https://pub.dev/api/packages/cupertino_native/score)、[native_liquid_glass](https://pub.dev/api/packages/native_liquid_glass/score)、[native_plus](https://pub.dev/api/packages/cupertino_native_plus/score)。GitHub stars 一手來源：[widgets](https://api.github.com/repos/sdegenaar/liquid_glass_widgets)、[renderer](https://api.github.com/repos/whynotmake-it/flutter_liquid_glass)、[easy](https://api.github.com/repos/AhmeedGamil/liquid_glass_easy)、[adaptive](https://api.github.com/repos/berkaycatak/adaptive_platform_ui)、[native_better](https://api.github.com/repos/gunumdogdu/cupertino_native_better)、[native](https://api.github.com/repos/serverpod/cupertino_native)。版本由各套件 `/api/packages/<name>` 的 `latest.version` 查核。

解讀時採三個分開的指標：下載是近期套件取得次數，不是獨立 App／開發者數，也沒有在此拆出 CI 與間接依賴；likes 與 stars 是累積關注，不是近期成長率；pub points 是套件檢查分數，不拿來當人氣分數。沒有歷史時間序列，不能聲稱誰「成長最快」。不同套件的功能廣度也不同，例如 adaptive 的下載不全是為了玻璃材質。

在這些限制下，現有 `liquid_glass_widgets` 本身就是近期下載最多、且上述六個主要 repository 中 stars 最多的選擇。`renderer` 則有最強的累積 pub.dev likes。這兩個結論來自資料，與遷移難易無關。

### 維護訊號

同輪 GitHub API 顯示上述六個 repo 均未封存；`pushed_at` 分別為 renderer 9 月 9 日、widgets 9 月 8 日、native_better 9 月 2 日、easy 8 月 25 日、adaptive 7 月 25 日、native 2 月 5 日。這只表示 repository 有 push，可能涉及其他 branch，不能當成修復已發布。尤其 renderer 最新 pub artifact 雖停在 2025-11-13，repo 仍有近期 push，不能說已停止維護。日期與狀態來源為上一段 GitHub API。

### 熱門替代方案的真正差異

**`liquid_glass_easy 4.2.0`：值得與現有方案正面比較的跨平台 shader 選擇。** 它已提供 lens、scaffold、tab bar 等元件；Impeller 使用 live backdrop，Skia 使用 capture 路徑，獨立 tab bar 也提供 `.withImpeller`。其優勢是不同的材質與背景取樣設計，不應只因現有套件較容易升級就排除；但作者的高幀率宣稱未在 Tripline 實測。[作者文件](https://pub.dev/packages/liquid_glass_easy)、[發布 metadata](https://pub.dev/api/packages/liquid_glass_easy)

**`cupertino_native_better 1.6.0`：值得優先實驗的原生控制項候選。** 在本次專注原生 iOS／macOS 的候選中，它的近 30 天下載高於 native、native_plus 與 native_liquid_glass，且 8 月 27 日仍有新版本。它透過 Platform Views 提供 tab bar、button、menu 等原生元件，要求整合 `CNTabBarRouteObserver`；sheet 另有 geometry probe，部分遮蓋情境會銷毀／重建底層 PlatformView。這些整合行為必須與現有 go_router、sheet、地圖一起驗證。README 對其他套件的負面比較是作者立場，本研究未將其當成競品今日必現缺陷。[作者文件](https://pub.dev/packages/cupertino_native_better)、[發布 metadata](https://pub.dev/api/packages/cupertino_native_better)

**`adaptive_platform_ui`：近期下載與累積 likes 都較高的整套自適應 UI 選擇。** 若願意採 Android Material、iOS 原生外觀，它比單一玻璃 renderer 更接近完整平台元件方案；在 Tripline 現有全平台 iOS HIG 決策下，則需明確處理平台策略差異。這是產品取捨，不是人氣不足。[作者文件](https://pub.dev/packages/adaptive_platform_ui)

其他新候選也有納入下載盤點：`just_liquid_glass` 340、`real_liquid_glass` 318、`ios_liquid_glass` 264、`liquid_glass_native` 184、`native_liquid_glass_flutter` 32。它們不是本次數據中的主流領先者，但低下載也不等於品質不好。[just score](https://pub.dev/api/packages/just_liquid_glass/score)、[real score](https://pub.dev/api/packages/real_liquid_glass/score)、[ios score](https://pub.dev/api/packages/ios_liquid_glass/score)、[liquid_native score](https://pub.dev/api/packages/liquid_glass_native/score)、[native_flutter score](https://pub.dev/api/packages/native_liquid_glass_flutter/score)

## 本專案目前實際使用方式

`pubspec.yaml` 與 lock 均固定 `liquid_glass_widgets 0.23.0`；主程式初始化套件、設定 premium，並開啟 adaptive quality。玻璃 recipe 已使用 premium 與 `fresnelStrength: 0`，一般／媒體背景光強度分別為 0.20／0.16；提高對比與降低透明度時有專案自己的不透明 fallback。**不能把 ADR-0004 當年 standard shader 邊光過強，當成當前仍未處理的問題。** [pubspec.yaml](../../pubspec.yaml)、[pubspec.lock](../../pubspec.lock)、[main.dart](../../lib/main.dart)、[tp_glass_surface.dart](../../lib/ui/tp_glass_surface.dart)、[ADR-0004](../adr/0004-neutral-selection-surface-with-tinted-foreground.md)

root tab bar 保留自畫的靜止中性選取指示，寬度為欄位的 70%；地圖分頁另帶 PlatformView backdrop。選單目前使用 `MenuAnchor` 配合自訂 `TpGlassSurface`，不是全部使用套件的 `GlassMenu`；sheet 使用 `GlassModalSheetScaffold`。因此「新版選單動畫更完整」本身不等於本專案立即受益。[apple_root_tab_bar.dart](../../lib/features/shell/apple_root_tab_bar.dart)、[tp_app_bar.dart](../../lib/ui/tp_app_bar.dart)、[adaptive.dart](../../lib/app/adaptive.dart)

## 候選比較

版本與日期直接查 pub.dev API 的 `latest` 與 `published`，日期以 UTC 表示；不採用頁面「幾個月前」文字。發布日期只表示最新已發布 artifact，不等於完整維護活躍度，也不能推論專案已停止維護。

| 候選 | 最新發布版本／日期 | 技術與適用範圍 | 對 Tripline 的判斷 |
|---|---|---|---|
| `liquid_glass_widgets` | 1.4.1／2026-09-08 | Flutter shader 模擬；iOS、Android 與桌面／Web；MIT | 優先驗證原套件升級。已有高階導航與控制元件，最接近現有架構。 |
| `liquid_glass_easy` | 4.2.0／2026-08-25 | 跨平台 shader、Impeller backdrop／Skia capture；MIT | 熱門的獨立 shader 替代路線，應納入同場比較。 |
| `cupertino_native_better` | 1.6.0／2026-08-27 | iOS／macOS 原生 Platform Views，其他平台 fallback | 專注原生控制項且近期發布活躍，應優先驗證 tab bar／sheet 整合。 |
| `liquid_glass_renderer` | 0.2.0-dev.4／2025-11-13 | 底層 renderer；作者要求 Impeller，列 iOS／Android／macOS；MIT | 不構成高階 widgets 的直接替代；需要自行維護導航、互動與 fallback。 |
| `native_liquid_glass` | 0.2.15／2026-08-18 | `UiKitView` 包 UIKit；iOS 26 真正系統材質，舊版／其他平台 fallback；MIT | 原生材質候選，但 overlay 與同 route 切 tab 限制直接涉及本專案。 |
| `cupertino_native` | 0.1.1／2025-09-08 | UIKit／AppKit Platform Views＋method channels；其他平台 Flutter fallback；BSD-3-Clause | 作者仍定位 proof of concept；不宜承接全 App chrome。 |
| `adaptive_platform_ui` | 0.1.111／2026-07-25 | iOS 26 原生樣式、舊 iOS Cupertino、Android Material；MIT | 預設跨平台策略與 ADR-0009 不符，整套遷移理由不足。 |

版本來源：[widgets API](https://pub.dev/api/packages/liquid_glass_widgets)、[renderer API](https://pub.dev/api/packages/liquid_glass_renderer)、[native API](https://pub.dev/api/packages/native_liquid_glass)、[cupertino API](https://pub.dev/api/packages/cupertino_native)、[adaptive API](https://pub.dev/api/packages/adaptive_platform_ui)。技術、平台與授權來源：[widgets 作者文件](https://pub.dev/packages/liquid_glass_widgets)、[renderer 作者文件](https://pub.dev/packages/liquid_glass_renderer)、[native 作者文件](https://pub.dev/packages/native_liquid_glass)、[cupertino 作者文件](https://pub.dev/packages/cupertino_native)、[adaptive 作者文件](https://pub.dev/packages/adaptive_platform_ui)。

## 為何先評估原套件升級

### 可驗證的新能力

- **地圖共存：** 1.2.0 加入 `PlatformViewGlassMode.passthrough` 與 tab bar 的 `passthroughOverPlatformView`。這是避免不可取樣背景造成黑底的路徑，不是讓 Flutter shader 能折射原生地圖。
- **材質分層：** 1.4.0 的 `backgroundQuality` 可將 bar 背景與指示器的品質分開，另有 `GlassBodyMode.clear`。它們值得比較現有 recipe，但不是直接照新版預設取代專案語意。
- **降級路徑邊光：** 0.23.0 的 Fresnel 控制原先針對 premium；後續 changelog 記錄跨路徑一致化。目前 upstream shader 已有 `uFresnelStrength` 並乘入 rim 計算。這有助於評估 adaptive quality 降到 standard 時的行為，不代表現有 premium 配方一定會改善。

上述版本變化來自作者的 [changelog](https://pub.dev/packages/liquid_glass_widgets/changelog)；標準 shader 的實作核對於 [upstream commit 357402e](https://github.com/sdegenaar/liquid_glass_widgets/blob/357402e9314ed4f3df3db4e1d6176b0ef060b046/shaders/lightweight_glass.frag)。此 source snapshot 是查核時的 main，不冒充已下載並驗證過的 1.4.1 artifact。

### 不是只改版本號

已找到會影響現有程式的具體 API 變更：`tp_app_bar.dart` 兩處使用 `GlassAppBar(preferredSize: ...)`，0.24.0 起改成 `toolbarHeight`。官方 1.0 migration guide 只涵蓋 0.30.x → 1.0.0，不能單靠它保證 0.23.0 的遷移完整。後續 1.3.0 也調整按鈕預設互動，須做操作回歸。[現有 app bar](../../lib/ui/tp_app_bar.dart)、[changelog](https://pub.dev/packages/liquid_glass_widgets/changelog)、[0.x → 1.0 migration guide](https://github.com/sdegenaar/liquid_glass_widgets/blob/357402e9314ed4f3df3db4e1d6176b0ef060b046/docs/MIGRATION_0.x_TO_1.0.md)

最新公開 `GlassTabBar` source 仍提供 `indicatorExpansion`，本次未找到可直接保證「70% 欄寬、靜止中性選取底」的專用 builder／比例 API；不能承諾升級就能刪除自畫指示器。應先保留現有公開行為，再以新版元件做獨立對照。[GlassTabBar source](https://github.com/sdegenaar/liquid_glass_widgets/blob/357402e9314ed4f3df3db4e1d6176b0ef060b046/lib/widgets/surfaces/glass_tab_bar.dart)、[現有 root tab bar](../../lib/features/shell/apple_root_tab_bar.dart)

1.4.1 的 metadata 要求 Flutter ≥3.41、Dart ≥3.5；符合 SDK 下限不代表所有整合都通過。作者宣稱全平台支援，且仍將 adaptive quality 標為 experimental。README 說 Reduce Transparency 以 Increase Contrast 近似，因此**不能刪掉本專案獨立的 `AppAccessibilityScope`**，也不能將作者的 WCAG／幀率宣稱當本專案驗收結果。[套件 metadata](https://pub.dev/api/packages/liquid_glass_widgets)、[套件 README](https://pub.dev/packages/liquid_glass_widgets)、[DESIGN 無障礙 gate](../../DESIGN.md)

## 其他候選的整合取捨

`liquid_glass_renderer` 是原料級 renderer，作者明示 experimental、Impeller-only，並列出 shape blending 上限與效能限制；`liquid_glass_widgets` 也明確說自己的 renderer 源自該專案的 vendored work。因此換回 renderer 不能假定會更像 Apple 或更快，反而需要接手高階元件。README 的歷史 Flutter bug 描述未在本次逐條重現，不把它們當今日必現缺陷。[renderer 文件](https://pub.dev/packages/liquid_glass_renderer)、[widgets credits](https://pub.dev/packages/liquid_glass_widgets)

`native_liquid_glass 0.2.15` 已不是 ADR-0001 當年「發布未滿一週」的狀態，也不是沒有其他原生候選。可是最新 README 仍寫明：非當前 route 時自動隱藏玻璃；自訂 overlay 須手動 suppress；同一 route 的 `IndexedStack`／`TabBarView` 切換可能閃過平面暗色。這些限制正好碰到 root tabs、sheet、選單與地圖；值得局部實驗，尚不適合全面替換。[native overlay suppression](https://pub.dev/packages/native_liquid_glass#overlay-suppression)、[歷史 ADR-0001](../adr/0001-keep-liquid-glass-over-native-cupertino.md)

`cupertino_native` 作者仍稱 proof of concept，列出 scroll view 整合與 API 整理待辦，且 macOS Liquid Glass 尚未測試。其 README 仍提 Xcode 26 beta，代表安裝文字須對照目前 toolchain，不能照抄為今日必要條件。[作者 README](https://pub.dev/packages/cupertino_native)

另查 `cupertino_native_plus 0.0.11`（2026-05-19 發布）：它提供 iOS／macOS 原生元件、glass unioning、tab bar 與標籤樣式等較廣 API，也仍使用 Platform Views。作者特別警告不要在長捲動列表大量放 `LiquidGlassContainer`，建議靜態 header／導航等用途。它應納入原生候選，但這些新功能尚不能直接證明地圖＋overlay＋root tab 整合優於其他候選。[版本 API](https://pub.dev/api/packages/cupertino_native_plus)、[作者文件](https://pub.dev/packages/cupertino_native_plus)

`adaptive_platform_ui` 提供較完整的平台元件，但 Android Material 分流不符合本專案方向。另須精確區分：作者「不要用於 production」的警告是 **`IOS26NativeSearchTabBar` 這個 experimental 功能**，因它替換 root controller，可能影響 Navigator 與 Riverpod 等生命週期；不應擴大說成整個套件都不能上線。[平台策略與 experimental 功能說明](https://pub.dev/packages/adaptive_platform_ui)

## Flutter 與 Apple 官方現況

Flutter 於 2026-08-12 發布的 3.47 公告已推出可選用的 `material_ui`／`cupertino_ui` 獨立套件；官方公告同時說初始拆出的 libraries 就是既有版本。官方 iOS 支援頁仍將 Liquid Glass 列為尚未完整實作項目，issue #170310 查核時仍 open。**拆分完成不能等同官方 Liquid Glass 已可替換第三方套件**；也不再沿用舊 ADR 的「等待下半年拆分」時程當今日事實。[Flutter 3.47 公告](https://flutter.dev/blog/whats-new-in-flutter-3-47)、[最新 iOS 支援狀態](https://docs.flutter.dev/platform-integration/ios/ios-latest)、[追蹤 issue](https://github.com/flutter/flutter/issues/170310)

Apple 的真正材質由 UIKit 的 `UIGlassEffect` 等 API 提供；HIG 把 Liquid Glass 放在導航／控制功能層，要求克制使用，內容區仍採一般材質。`clear` 適用於視覺豐富背景，不代表所有背景都應用透明 recipe。Apple 原生材質會回應降低透明度、提高對比與降低動態效果；Flutter 自畫 shader 需要自行實現對應行為。[UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect)、[Materials HIG](https://developer.apple.com/design/human-interface-guidelines/materials)、[WWDC25 Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)

Flutter 官方指出 iOS Platform Views 使用 hybrid composition，把原生 UIView 加入 hierarchy；因此原生候選不是「換皮不換整合模型」。widget test 能驗證 Dart 端公開行為，但實際 UIKit 合成、shader 材質、地圖遮擋與效能仍需裝置驗證。[Flutter Platform Views](https://docs.flutter.dev/platform-integration/ios/platform-views)、[專案驗收矩陣](../../DESIGN.md)

## 建議後續驗證範圍

建議以同一個 root tab bar＋地圖背景＋sheet 場景，正面比較 `liquid_glass_widgets 1.4.1`、`liquid_glass_easy 4.2.0` 與 `cupertino_native_better 1.6.0`；若考慮平台外觀分流，再加入 `adaptive_platform_ui`。現有 0.23.0 作為基準，而不是預設原套件一定勝出。固定相同背景、亮暗模式與裝置，涵蓋地圖控制與 POI accessory、選單、鍵盤出入。測試 seam 以既有 widget 公開行為與 HIG 十態矩陣為主，依 repo 工作流先確認範圍再實作。

視覺驗收用 iOS 26 真機，另覆蓋 iOS 16 與 Android；量測邊緣光、背景可讀性、首次出現、捲動／切 tab 的 raster frame time、記憶體與持續操作發熱。地圖特別檢查 passthrough 是否犧牲預期模糊、overlay 是否遮擋正確；無障礙獨立切換 Reduce Transparency／Increase Contrast／Reduce Motion。沿用 ADR-0004 教訓，不能用模擬器材質結果代替真機結論。[專案驗收規範](../../DESIGN.md)、[材質量測教訓](../adr/0004-neutral-selection-surface-with-tinted-foreground.md)

人氣盤點已能回答「目前誰最受歡迎」；上述同場比較才足以進一步回答「哪個在 Tripline 真機上更好」。本研究未執行升級或原型，不宣稱任何候選效能已勝出。
