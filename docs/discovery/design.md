# Tripline Flutter Design System

> 更新：2026-07-19。唯一視覺驗收依據是 [`2026-07-17-tripline-final.html`](../design-sessions/2026-07-17-tripline-final.html)。三色系、五項 root tab、large title 與雙層行程／地圖 selector 均已退場。

## 1. 產品基準

- Apple Music 提供內容優先、玻璃浮層、帳號設定與列表密度的參考。
- Apple Human Interface Guidelines 提供導覽、sheet、menu、list、toolbar、字體與可及性規則。
- Tripline 保留暖白與柔褐品牌，不複製 Apple Music 的紅色。
- 既有程式可重寫；相同職責必須由共用元件提供，不允許各頁複製 toolbar、selector、surface 或 bottom clearance。

### Liquid Glass 套件化邊界

- 導航與控制層全面採用固定版本 `liquid_glass_widgets 0.22.1`；不得使用 caret 自動升級。升版必須重新跑視覺、實機與可及性驗收。
- App 啟動時初始化 shader，並由單一全域 `GlassThemeData` 提供暖白 Light 與中性深色 Dark；開啟 adaptive quality，遵守系統 Reduce Motion、Reduce Transparency 與 High Contrast。
- 現有共用入口保留，由內部委派套件元件：`TpGlassSurface` 使用 `GlassContainer`、`TpAppBar` 使用 `GlassAppBar`、root navigation 使用 `GlassTabBar.bottom`、scope menu 使用 `GlassMenu`、大型 sheet 使用 `GlassModalSheetScaffold`。
- 行程／地圖 selector 由共用 `TpHorizontalSelector` 提供：左側 `GlassButton` 是跨頁 action，右側只有可水平滑動的 `DAY 1...DAY N` 單選狀態；不得把跨頁 action 偽裝成 segmented selection，也不得恢復「總覽」。
- 地圖 root tab 與浮動控制必須啟用 PlatformView backdrop 相容模式；`google_navigation_flutter` 的 `GoogleMapsMapView`、路線、marker、camera 與手勢由 app-owned map adapter 負責，不啟動導航 session。
- POI dock 只建立一個折射玻璃層；內層 POI 卡使用暖色半透明內容 surface，禁止玻璃內再巢狀玻璃，避免 rim、blur 與 refraction 失真。
- AI composer 可採 `GlassTextField`，但附件、語音、送出、disabled、loading、focus 與 Dynamic Type 行為必須原樣保留。
- 設定群組、收藏 row、行程卡、表單內容與可捲動內容卡維持不透明 HIG surface；「全面置換」只指套件有責任承接的導航、浮動控制、輸入 chrome、menu、popover、sheet 與 feedback，不把整頁內容玻璃化。
- 預設使用 `GlassQuality.standard`；只有固定、不捲動且實機 profile 無掉幀的導航 chrome 才能升到 `premium`。iOS 與 Android 過熱或 GPU 預算不足時必須能自動降級。

## 2. 色彩

### Light：原始暖白色階

| Token | 色碼 | 用途 |
|---|---:|---|
| background | `#FFFBF5` | Scaffold、頁面底 |
| surfaceContainerLow | `#FAF4EA` | 群組列表、卡片 |
| surfaceContainerHigh | `#F2EAD9` | recessed／較深層表面 |
| hover / pressed | `#F9EDE0` | 短暫互動 |
| selected subtle | `#F4EDE3` | 選取 pill、active tab |
| primary | `#A97A4A` | 品牌、目前狀態、主要動作 |
| primary deep | `#8A6038` | 文字型 accent、pressed |
| onSurface | `#2A1F18` | 主文字 |
| onSurfaceVariant | `#6F5A47` | 次要文字 |
| outlineVariant | `#EADFCF` | 1pt inset separator |
| outline | `#C8B89F` | 強分隔、控制邊界 |

### Dark：中性深色＋柔褐 accent

| Token | 色碼 | 用途 |
|---|---:|---|
| background / surface | `#1C1C1E` | Scaffold、sheet canvas；不大面積使用純黑 |
| surfaceContainerLow | `#2C2C2E` | 群組列表、卡片 |
| surfaceContainerHigh | `#3A3A3C` | pressed／recessed |
| primary | `#CBA06E` | 品牌、目前狀態、主要動作 |
| primary deep | `#E0BC90` | accent 文字 |
| onSurface | `#F5F5F7` | 主文字 |
| onSurfaceVariant | `#A1A1A6` | 次要文字 |
| outlineVariant | `#3A3A3C` | separator |
| outline | `#545458` | 強分隔、控制邊界 |

### 三色系退場

- sage／pink 不再代表 POI、收藏、交通、住宿或餐廳類型。
- POI、行程、收藏卡一律使用相同 system surface；只有編號、marker、route 可帶當日色。
- destructive／success／warning 等語意色保留，只用於真正的語意狀態。
- 不使用 gradient、rainbow 類型色或裝飾性陰影。

## 3. Apple HIG 語意字階

Flutter 必須以 `TextTheme` 語意樣式對應，不在 widget 內硬寫另一套固定字級。

| 角色 | HIG text style | 預設 Large 尺寸 |
|---|---|---:|
| 頁面／行程標題 | Title 3 | 20pt |
| 模態／設定標題 | Title 3 | 20pt |
| 帳號名稱 | Title 2 | 22pt |
| 設定列 | Body | 17pt |
| 景點、POI、row title | Subheadline | 15pt semibold |
| 一般正文 | Subheadline | 15pt |
| 次要資訊、selector | Footnote | 13pt |
| 時間、輔助資訊 | Caption 1 | 12pt |
| root tab label | Caption 2 | 11pt |

- 使用 SF Pro system font 與中文系統 fallback；中文 letter spacing 為 0。
- 相較初版 HIG mapping，畫面角色統一下移一個語意字階；不個別縮放單一頁面。
- 支援 Dynamic Type、Bold Text 與至少 200% 文字。
- 大字模式讓 row、卡片、sheet 自動長高與換行；禁止縮字維持固定高度。
- 時間與日期使用 tabular figures。
- 所有互動 target 至少 44×44pt；target 可大於可見膠囊，但不得增加膠囊外觀高度。

## 4. Root navigation

Root tab 固定四項：

1. 聊天
2. 行程
3. 地圖
4. 收藏

帳號不再是 tab。帳號 avatar 固定在四個主畫面右上角，以圓形按鈕開啟 `/account`。舊 `/account` deep link 必須保留。

Root tab 幾何：

- 水平 margin 16pt；四項目的地平均分配，在小螢幕與大字體下仍保留完整 label。
- 可見高度 64pt，外圓角與 active indicator 採套件 `GlassTabBar.bottom` 預設幾何；互動 target 與可見膠囊一致，不再由 feature 覆寫套件尺寸。
- 底部位移為 `max(16pt, safe area - 24pt)`，讓膠囊避開 home indicator 且保留 Apple 慣例的底部呼吸空間。
- Light glass 使用 C1 暖白配方（`rgba(255,251,245,.58)`、88% 白色亮邊）；Dark glass 使用 A 配方 `rgba(44,44,46,.68)` 與 18% 白色亮邊。共用 navigation recipe 的 opacity multiplier 固定為 `1.0`，不再二次稀釋定案 alpha；選中項使用 14% 柔褐 selected surface。
- 內容可以延伸到玻璃後方，但可操作內容、POI accessory 與輸入列必須使用相同 geometry 避讓。
- tab 不隨捲動縮小、淡出或改變標籤。
- AI chat composer 與其他 bottom accessory 使用同一 geometry，與 root tab 的可見間距固定 4pt；本次只調整位置與視覺，送出、語音、附件與既有狀態處理全部維持原功能。

## 5. 全域 toolbar

- Chat、行程、地圖的 title 直接顯示目前行程名稱。
- 點 title 開啟共用 HIG 近滿版 bottom sheet：固定高度 93%、不顯示暗示可調整的 drag indicator、Header 提供符合任務語意的取消／關閉、搜尋、目前項目 checkmark、最近行程；沒有 tab，也不是 dropdown。
- 收藏 title 顯示「收藏」。
- 返回、關閉、帳號與功能 action 共用同一套 44pt Liquid Glass 圓形元件，不使用各頁自製尺寸或厚 border；同一列有兩個以上圓形按鈕時固定保留 8pt 間距。一般 Root 頁最多兩個 actions；收藏因標題固定且短，可在同一膠囊內放搜尋、排序、新增與帳號，並以 200% Dynamic Type 驗證。Menu 使用右上錨定的 260pt 浮動玻璃面板、24pt 圓角、48pt 圖示列與 inset separator。
- 行程列表與行程內容頁的功能入口共用 `TpMoreMenuButton`。觸發鈕與展開面板使用同一套 `primaryContainer` 玻璃設定；Light 選項文字／圖示使用 Tripline 暖深色 `onSurface`，Dark 使用 `primary`，禁止改成純黑或脫離 Tripline 主題色。
- 筆記是行程／地圖右上角命令，不是主 selector 或 root tab。
- Account／Settings 使用 grouped list、inset separator、無 card border／shadow、system red destructive row。
- 行程功能選單中的筆記、行程資料、列印、異動紀錄、分享連結、共編設定與 AI 健檢，全部使用共用的固定 93% 高度 bottom sheet：不可顯示 resize grabber，Header 有 44pt 關閉鈕；不得以沒有出口的整頁 route 取代。只有「調整順序」留在原頁切換 reorder mode，並直接顯示「完成」。
- 調整順序模式的 Header title 改為「調整順序」，trailing 使用完整文字「完成」並保留至少 44pt 高度與可隨文字伸展的寬度；`TpRootGlassHeader` 不得把文字 action 強制塞進 44pt 正方形而顯示成「完」。完成與帳號相距 8pt。
- 每個停留點的「移到其他 Day」與拖曳排序都是列內動作：前者直接使用 `folder` 開啟 Day selection sheet，後者使用 `line_horizontal_3` 作 drag handle。兩者共用同一個 44×44pt、無額外 glass 外框的 inline action 樣式、主題 tint、pressed state、tooltip 與 semantics；只有一個動作的 ellipsis menu 退場。
- 上述 sheet 內的功能頁共用套件 `GlassAppBar`：子頁標題採 Title 3（20pt）並置中，移除重複的 system top safe-area，標題緊接 drag indicator，不留下第二段狀態列高度的空白。
- 點擊後在原位置展開內容的 accordion 共用 `TpGlassExpansionSection`，由套件 GlassContainer 承接材質；Light 使用暖白玻璃，Dark 使用中性深色玻璃，禁止各頁自行以實心 Container 包裝 ExpansionTile。

## 6. 行程與地圖單層控制

同一位置、同一高度、同一選取 DAY：

- 行程頁：`地圖 | DAY 1 | DAY 2 | …`
- 地圖頁：`行程 | DAY 1 | DAY 2 | …`

左側是 accent icon＋文字的目的地 action，點擊後互切頁面並保留 DAY；細分隔線後直接排列單選 DAY。active DAY 使用可滑動的 accent thumb；長行程整段可水平滑動並自動保持目前 DAY 可見。當前頁不重複顯示自己，也不再顯示「行程＋地圖」雙選項。

地圖頁讓地圖延伸到 selector 後方，DAY selector 浮在 toolbar 下方 8pt；行程頁仍在相同垂直位置使用同尺寸 selector。兩者完全依定版圖：外膠囊 44pt 高／22pt 圓角／4pt 內距，active thumb 34pt 高／17pt 圓角，標籤使用 12pt semibold；材質使用 22pt blur、半透明底、低陰影與 1px rim highlight。

行程往下內容必須完整包含：日期、明確標示「天氣示意」的固定展示資料、景點、交通、長按排序、新增景點、下一日；不能只套用 header。每日飯店摘要卡退場，住宿仍以一般停留點存在於行程內容，不另做重複摘要。

Timeline 在所有 Dynamic Type 尺寸都使用 D1 單一結構：左側固定 32pt rail，右側依序堆疊時間與景點卡；交通列沿用相同 rail 與內容起點。時間使用 tabular figures 單行顯示 `09：30 - 11：00`，不得拆行；VoiceOver 仍讀為「09:30 到 11:00」。停留點圓點 22pt，圓點頂端與該停留點時間第一行頂端對齊，連線穿過前後交通列且不得把 1／2 圓點下推；rail 與內容間距 10pt、卡片圓角 18pt／內距 16pt、交通列最低 64pt，放大字體只增加垂直高度，不改變水平欄位。

AI 聊天訊息與行程 Timeline 不能把整個 body 固定 padding 到 Header 下方。和收藏清單相同，唯一垂直捲動面先提供初始 top inset，之後讓內容從固定 Root Glass Header 下方通過；聊天 composer 與 Root Tab 仍固定在底部並共用 clearance。

AI 聊天每一則非系統訊息都顯示發話者名稱。自己的訊息優先使用目前帳號 display name，沒有名稱時使用 email `@` 前的 local part，最後才顯示「你」；協作者訊息優先使用訊息內的 collaborator display name，沒有名稱時同樣 fallback 到該 email local part，最後才顯示「協作者」。Tripline AI 固定顯示「Tripline AI」。自己的訊息維持 Tripline 柔褐 accent，AI 使用中性 surface；協作者只使用 HIG dynamic system Indigo（Light `#5856D6`、Dark `#5E5CE6`）作名稱與低透明度 bubble tint，作為單一作者識別色，不恢復已退場的三色分類系統。

## 7. 地圖與 POI

- Mobile 使用 `google_navigation_flutter 0.10.x` 的 map-only `GoogleMapsMapView`；Web 只提供外開 Google Maps，不保留第二套 embedded SDK。
- Google 地圖在 Light／Dark App appearance 下都固定使用 `MapColorScheme.light` 日間底圖；Dark appearance 只改變上層 Header、selector、POI dock 與 root tab 的中性深色 Glass。
- Google 原生 POI 保持可見與可點擊；選取後暫時取代底部 accessory，使用者按「在 Google 地圖開啟」才以 Universal URL 外開 App 或 Web，不寫入 Tripline 行程資料。
- 預設進入、切換行程、切換 Day 與點選 Tripline POI 都固定 zoom `13.0`，不執行全日本 bounds fit。
- 當日沒有座標時仍維持 zoom `13.0`，並使用行程第一個已知座標作為城市層級 fallback；不得 fit 全行程 bounds。
- 明確點 marker／POI 卡時使用 zoom `16.0`。
- POI dock 固定在 root tab 上方 4pt；標準高度 96pt，外層使用參考圖的 full-width glass band、28pt blur、半透明底色、1px rim highlight 與內高光；active 卡再疊一層 16pt blur 的玻璃 surface，不使用實心 group 色。無障礙文字可自動增高。
- POI PageView 的卡片寬度固定為可視軌道的 80%。第一筆靠左，下一張露出約 25% 提示可滑動；滑動後仍由左側對齊目前卡，最後一筆不循環製造假資料。卡片下方顯示頁碼圓點，active 頁使用 Tripline accent 的短膠囊。
- POI 卡資訊層級參考核准圖：左側當日編號圓章；中央依序為「停留 N / 總數」、景點名、時間與類型摘要；右側為圓形導航動作。卡片與導航按鈕皆使用 Tripline accent，不引入新的分類色。
- marker、route、卡片與 camera focus 共用同一 active entry；缺座標 POI 仍留在 accessory 並顯示「尚無位置」。
- POI rail 沒有垂直拖曳、收合、detent 或 grabber。

## 8. 收藏

- Root Header 一般狀態為 `收藏｜搜尋｜排序｜新增｜帳號`，所有動作都在同一條 glass 膠囊內；搜尋用 `search`、排序用無外圈的 `line_horizontal_3_decrease`、新增用 `plus`、帳號固定最右。
- 點搜尋後，Header 標題區原地轉成自動聚焦的 `搜尋收藏` 欄位；排序、結束搜尋與帳號維持可見，新增暫時隱藏。結束搜尋會清空查詢並恢復一般狀態，頁內不再放第二條搜尋欄。
- 搜尋狀態使用清楚的文字「取消」結束，不以語意不明的 `×` 取代。清單捲動會收起鍵盤，鍵盤 Search 仍可立即送出。
- 本地收藏結果每輸入一字即時更新；名稱、地址與備註中的符合字串使用較深 `onSurface`＋Semibold，其餘文字維持次要色，不用大面積 accent 標記。
- 排序使用 `TpMoreMenuButton` 錨定選單，提供最近加入、最早加入、名稱、地區；目前排序顯示 checkmark。separator 下方的「篩選條件」沿用既有類型／地區篩選 Sheet，不新增沒有產品需求的顯示方式選單。
- `plus` 開啟既有 Google POI 探索／收藏流程；新增不是搜尋，因此不得使用放大鏡代表新增。
- 收藏 row 使用 grouped list 與 inset separator，不以三色卡片區分類型。
- 篩選使用 sheet＋checkmark；POI action 使用 action sheet。
- POI action 至少包含：加入行程、地圖查看、編輯收藏與筆記、分享、取消收藏。
- 單筆取消收藏與復原改用後端 `POST /api/poi-favorites/:id/restore`；完整後端交付契約見 `docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`。
- 空狀態提供清除篩選或前往 Google Maps POI 搜尋。

## 9. 新增景點

沿用既有 `EntryAddRouteScreen`，不要建立第二套搜尋或收藏 picker：

- Google Maps POI 搜尋。
- 從收藏加入。
- 自訂景點。
- 保留目前行程與 DAY。
- 遠端 POI 搜尋在輸入至少 2 個字元後以 300ms debounce 即時更新；清空立即還原，過期 request 不得覆蓋新結果，鍵盤 Search 可略過等待立即送出。

## 10. 帳號與設定

- Account avatar 顯示帳號／顯示名稱第一個字元，使用與其他 toolbar action 相同的 44pt Liquid Glass 圓形元件；點擊後開啟與行程切換相同的 93% 高度 bottom sheet，右上 close target 44pt。獨立 `/account` route 僅保留 deep link 與直接導覽相容性。
- Light group 使用 `#FAF4EA`，Dark group 使用 `#2C2C2E`；無額外 card border 或 shadow。
- row title 使用 Body／Headline 17pt，secondary 使用 Subheadline 15pt。
- separator 1pt、左右 inset 16pt；有 leading image 時從文字欄開始。
- 外觀使用 checkmark exclusive selection；通知使用 inline switch。
- 保留個人資料、外觀、通知、登入裝置、已連結應用程式、Developer App、登出。

## 11. 完成標準

- 最終 mockup、本文件、詳細 spec 與程式實作無衝突。
- Light／Dark、320×568、390×844、430×932、200% text、Bold Text、Reduce Motion 均可操作。
- Reduce Transparency／High Contrast 必須使用套件 fallback，所有文字、選取狀態與操作仍可辨識。
- iOS 與 Android 實機必須驗證 Google Maps PlatformView 上的 root tab、DAY selector、POI dock、marker 點擊、地圖拖曳與 tab 點擊不凍結，並以 profile mode 檢查 raster jank。
- Widget tests 覆蓋 4-tab、account deep link、trip sheet、單層 selector、固定 zoom、POI clearance、聊天／Timeline full-bleed 捲動、聊天自己／協作者名稱 fallback 與協作者 dynamic Indigo tint、收藏 Header 搜尋狀態、排序 checkmark、plus 導覽、grouped list 與 HIG text styles。
- `dart format --output=none --set-exit-if-changed .`、`flutter analyze --no-fatal-infos`、`flutter test`、`flutter build ios --release --no-codesign` 全部通過。
- 合併至 `master` 後觸發新的 TestFlight workflow，並確認新 build 完成 Apple processing。
