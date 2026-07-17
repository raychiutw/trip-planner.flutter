# 自適應 UI 設計理由：以 Apple Music 為品質基準

Tripline 對標 Apple Music 的資訊階層、內容優先與平台熟悉感，但不複製 Apple Music 的品牌、內容模型或每一個視覺效果。目標是讓旅程規劃像成熟的原生內容 app 一樣安靜、可預期，同時保留 Tripline 的柔褐三色系統與座標 App Icon。

## 問題

只使用 Flutter 預設 Material 元件會產生幾個斷點：iOS 操作看起來像 Android、重要行程動作藏得太深、寬螢幕內容被拉得過寬、載入時只剩 spinner、真正錯誤又被短暫 toast 吞掉。這些問題不是「不像 Apple」而已，它們會降低動作可發現性、閱讀效率與錯誤復原率。

## 方法

```
品牌 token / HIG 字階
          │
          ▼
AppTheme + 系統字 + Dynamic Type
          │
          ├── 平台：Cupertino / Material 自適應控制項
          ├── 寬度：compact tab bar / wide navigation rail
          ├── 狀態：skeleton / persistent error / transient notice
          └── feature：行程、時間軸、地圖、收藏、建立流程
```

Apple Music 在這裡是品質基準，不是元件庫。實作遵循四個優先順序：

1. 可用性與 accessibility。
2. iOS、Android 與寬螢幕的平台慣例。
3. Tripline 品牌與旅遊資料語意。
4. Apple Music 式的視覺節奏。

## 對標與反方意見

| 面向 | 採用的原則 | Tripline 實作 | 反方意見與結論 |
|---|---|---|---|
| 頂層導覽 | 少量、穩定、可保留分頁狀態 | 五個 branch 固定順序，一律使用浮動玻璃 `AppleRootTabBar`（2026-07-16 更正：先前記載的 `CupertinoTabBar` / `NavigationBar` / `NavigationRail` 依寬度切換**從未實作**，`AppShell` 無條件只用 `AppleRootTabBar`） | 「全部做成 Cupertino 才像 Apple Music」忽略 Android 熟悉度；改以單一玻璃 Tab bar 統一兩平台，並保留 label 與 selected semantics |
| 資訊階層 | 統一頁首、明確主動作、次要動作收斂 | inline 頁首（56pt 單行 + 最多兩個功能鍵）、空狀態 CTA、時間軸 More 選單、可見的收藏選取模式（2026-07-16 更正：large app bar 已移除） | 「所有動作都露出」會增加 chrome；主動作外露、低頻動作進 More。大標題只有部分頁面有，反而讓 app 讀起來像兩套設計 |
| 排版 | 少字型、角色清楚、尊重使用者字級 | 系統字、HIG 字階、中文零字距、Dynamic Type | 「打包 Inter 比較一致」會犧牲平台字型調校與 accessibility；因此不打包 Inter |
| 寬版閱讀 | 內容有焦點，不因螢幕變大而無限拉長 | form `720`、conversation `860`、feed `920` | 「全寬顯示資訊更多」對表單與段落反而增加視線移動；地圖等空間型內容仍可全寬 |
| 載入 | 儘快顯示接近最終版型的內容 | list/map/timeline 靜態 skeleton | 「shimmer 更有活力」只是持續動畫，沒有增加資訊；靜態 skeleton 對 reduced motion 更安全 |
| 錯誤 | 失敗必須持續可見且可恢復 | `showAppError` banner + 關閉/重試；`showAppNotice` 只放成功與低風險狀態 | 「全部用 toast 比較乾淨」會讓錯誤在使用者讀完前消失；真正錯誤不能短暫化 |
| 地圖 | 顏色與 icon 不能只傳達裝飾 | 44pt marker、POI 類型 icon、semantics、定位失敗重試 | 「Apple Music 很少用多色」不適用資料視覺化；地圖日別與 POI 分類保留必要色彩 |
| 大量收藏 | 連續瀏覽、明確進入批次操作 | lazy `SliverList`、選取/完成、批次工具列 | 「分頁比較省資源」會打斷手機掃讀；目前資料量由 lazy list 足以承擔 |
| 建立行程 | 先完成必要資訊，再逐步補充 | 漸進式表單與清楚的完成狀態 | 「一次攤開所有欄位比較透明」提高首次建立負擔；進階欄位仍可找到，但不搶主流程 |
| App Icon | 首頁圖示要獨特、簡單、跨 appearance 可辨認 | 保留圓角座標定位圖釘與中央指南針箭頭，提供 Default/Dark/Tinted | 「一起換成更像 Apple Music 的抽象圖形」會稀釋 Tripline 識別；座標 icon 是品牌資產，不是 UI chrome |

## 為什麼不做 Apple Music 複製品

Apple Music 的紅色品牌、媒體封面、播放控制與內容推薦模型不屬於旅程規劃。照抄會讓顏色失去 POI 語意，也會把旅行的時間、位置與協作資訊壓進不適合的媒體版型。

> **已過期（2026-07-16 更正）**：本節原本寫「不模擬 Apple 最新視覺材質或自製 Liquid Glass」。該決策已於 [2026-07-15 規格](superpowers/specs/2026-07-15-apple-music-ui-google-maps-parity-design.md)推翻並實作（PR #46「redesign Tripline with Liquid Glass and native maps」）。現況：根分頁採浮動玻璃 Tab bar，玻璃只用於 Tab bar、浮動 toolbar 與 sheet 等**功能層**，內容層維持標準材質，統一由 `TpGlassSurface` 集中處理 blur／tint／border／深淺模式與高對比降級。原本擔心的模糊與對比風險，靠「玻璃不鋪到內容層」與高對比降級來控管。

## Accessibility 基線

- 所有可點擊目標至少 `44×44`。
- icon-only action 必須提供 tooltip 或 semantics label。
- 文字使用系統字與 Dynamic Type；中文不加 letter spacing。
- 不只靠顏色傳達 POI 類型、選取或錯誤。
- 頁級載入提供語意標籤；真正錯誤使用 live region 並提供恢復動作。
- 新動畫用 `TpMotion.resolve` 尊重「減少動態效果」。

## 取捨

- 平台分支增加少量測試面，但換得 iOS/Android 都熟悉的操作。
- 固定內容最大寬度犧牲部分資訊密度，但提升長文字與表單可讀性。
- 靜態 skeleton 比 shimmer 低調，但耗能、干擾與 accessibility 風險更低。
- 持續錯誤 banner 佔用畫面空間，但使用者不會錯過失敗原因與重試入口。
- 系統字的跨平台字面不會完全一致，換得真正的 Dynamic Type 與本地語言 fallback。

## 參考與下一步

- [設計系統 Reference](reference-theme.md)
- [How to 新增畫面](howto-add-screen.md)
- [Tripline App Icon 設計規格](superpowers/specs/2026-07-14-tripline-app-icon-design.md)
- Apple HIG：[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)、[Typography](https://developer.apple.com/design/human-interface-guidelines/typography)、[Loading](https://developer.apple.com/design/human-interface-guidelines/loading)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
