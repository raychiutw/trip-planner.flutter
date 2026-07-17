# Tripline Flutter Design System

> 更新：2026-07-17。唯一視覺驗收依據是 [`2026-07-17-tripline-final.html`](../design-sessions/2026-07-17-tripline-final.html)。三色系、五項 root tab、large title 與雙層行程／地圖 selector 均已退場。

## 1. 產品基準

- Apple Music 提供內容優先、玻璃浮層、帳號設定與列表密度的參考。
- Apple Human Interface Guidelines 提供導覽、sheet、menu、list、toolbar、字體與可及性規則。
- Tripline 保留暖白與柔褐品牌，不複製 Apple Music 的紅色。
- 既有程式可重寫；相同職責必須由共用元件提供，不允許各頁複製 toolbar、selector、surface 或 bottom clearance。

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
| background | `#121214` | 最深背景、地圖空白區 |
| surface | `#1C1C1E` | Scaffold、sheet canvas |
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
| 模態／設定標題 | Headline | 17pt |
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

- 水平 margin 30pt；402pt 畫面上的可見寬度 342pt，對齊定版 mockup 的 85.2%。
- 可見高度 44pt，外圓角 22pt，內層 padding 3pt；不再以 52pt 膠囊壓縮主畫面。
- 底部位移為 `max(8pt, safe area - 24pt)`，讓膠囊與 home-indicator safe area 重疊 24pt，對齊 Apple Music 的貼底位置。
- Light glass 使用暖白 `rgba(255,251,245,.68)`；Dark glass 使用 `rgba(40,40,42,.72)`；選中項顯示中性 selected surface。
- 內容可以延伸到玻璃後方，但可操作內容、POI accessory 與輸入列必須使用相同 geometry 避讓。
- tab 不隨捲動縮小、淡出或改變標籤。
- AI chat composer 與其他 bottom accessory 使用同一 geometry，與 root tab 的可見間距固定 4pt；本次只調整位置與視覺，送出、語音、附件與既有狀態處理全部維持原功能。

## 5. 全域 toolbar

- Chat、行程、地圖的 title 直接顯示目前行程名稱。
- 點 title 開啟共用 HIG 近滿版 bottom sheet：高度 93%、頂部 36×5pt drag indicator、右上 44pt 圓形關閉鈕、搜尋、目前項目 checkmark、最近行程；沒有 tab，也不是 dropdown。
- 收藏 title 顯示「收藏」。
- 右側保留 account avatar 與最多一個 context action；額外命令進水平 ellipsis menu。Toolbar action 使用 44pt target、36pt 無框圓形 system material，不使用厚 border。Menu 使用右上錨定的 260pt 浮動玻璃面板、24pt 圓角、48pt 圖示列與 inset separator。
- 筆記是行程／地圖右上角命令，不是主 selector 或 root tab。
- Account／Settings 使用 grouped list、inset separator、無 card border／shadow、system red destructive row。

## 6. 行程與地圖單層控制

同一位置、同一高度、同一選取 DAY：

- 行程頁：`地圖 | 總覽 | DAY 1 | DAY 2 | …`
- 地圖頁：`行程 | 總覽 | DAY 1 | DAY 2 | …`

左側是 accent icon＋文字的目的地 action，點擊後互切頁面並保留 DAY；細分隔線後依序是「總覽」與單選 DAY。active DAY 使用可滑動的 accent thumb；長行程整段可水平滑動並自動保持目前 DAY 可見。當前頁不重複顯示自己，也不再顯示「行程＋地圖」雙選項。

地圖頁讓地圖延伸到 selector 後方，DAY selector 浮在 toolbar 下方 8pt；行程頁仍在相同垂直位置使用同尺寸 selector。兩者完全依定版圖：外膠囊 44pt 高／22pt 圓角／4pt 內距，active thumb 34pt 高／17pt 圓角，標籤使用 12pt semibold；材質使用 22pt blur、半透明底、低陰影與 1px rim highlight。

行程往下內容必須完整包含：日期、天氣、住宿、景點、交通、長按排序、新增景點、下一日；不能只套用 header。

## 7. 地圖與 POI

- 使用既有原生 Google Maps SDK。
- 所有每日行程固定 zoom `12.0`，切 DAY 不執行全日本 bounds fit。
- 當日沒有座標時仍維持 zoom `12.0`，並使用行程第一個已知座標作為城市層級 fallback；不得 fit 全行程 bounds。
- 明確點 marker／POI 卡時使用 zoom `16.0`。
- POI dock 固定在 root tab 上方 4pt；標準高度 96pt，外層使用參考圖的 full-width glass band、28pt blur、半透明底色、1px rim highlight 與內高光；active 卡再疊一層 16pt blur 的玻璃 surface，不使用實心 group 色。無障礙文字可自動增高。
- active POI 卡固定置中，前後卡各露出一部分提示可滑動；卡片下方顯示頁碼圓點，active 頁使用 Tripline accent 的短膠囊。第一筆與最後一筆維持置中，但只顯示實際存在的相鄰卡，不循環製造假資料。
- POI 卡資訊層級參考核准圖：左側當日編號圓章；中央依序為「停留 N / 總數」、景點名、時間與類型摘要；右側為圓形導航動作。卡片與導航按鈕皆使用 Tripline accent，不引入新的分類色。
- marker、route、卡片與 camera focus 共用同一 active entry；缺座標 POI 仍留在 accessory 並顯示「尚無位置」。
- POI rail 沒有垂直拖曳、收合、detent 或 grabber。

## 8. 收藏

- 首屏包含搜尋、類型／地區篩選與最近收藏。
- 收藏 row 使用 grouped list 與 inset separator，不以三色卡片區分類型。
- 篩選使用 sheet＋checkmark；POI action 使用 action sheet。
- POI action 至少包含：加入行程、地圖查看、編輯收藏與筆記、分享、取消收藏。
- 空狀態提供清除篩選或前往 Google Maps POI 搜尋。

## 9. 新增景點

沿用既有 `EntryAddRouteScreen`，不要建立第二套搜尋或收藏 picker：

- Google Maps POI 搜尋。
- 從收藏加入。
- 自訂景點。
- 保留目前行程與 DAY。

## 10. 帳號與設定

- Account avatar 使用與行程切換相同的 93% 高度 bottom sheet，右上 close target 44pt；獨立 `/account` route 僅保留 deep link 與直接導覽相容性。
- Light group 使用 `#FAF4EA`，Dark group 使用 `#2C2C2E`；無額外 card border 或 shadow。
- row title 使用 Body／Headline 17pt，secondary 使用 Subheadline 15pt。
- separator 1pt、左右 inset 16pt；有 leading image 時從文字欄開始。
- 外觀使用 checkmark exclusive selection；通知使用 inline switch。
- 保留個人資料、外觀、通知、登入裝置、已連結應用程式、Developer App、登出。

## 11. 完成標準

- 最終 mockup、本文件、詳細 spec 與程式實作無衝突。
- Light／Dark、320×568、390×844、430×932、200% text、Bold Text、Reduce Motion 均可操作。
- Widget tests 覆蓋 4-tab、account deep link、trip sheet、單層 selector、固定 zoom、POI clearance、收藏 grouped list 與 HIG text styles。
- `dart format --output=none --set-exit-if-changed .`、`flutter analyze --no-fatal-infos`、`flutter test`、`flutter build ios --release --no-codesign` 全部通過。
- 合併至 `master` 後觸發新的 TestFlight workflow，並確認新 build 完成 Apple processing。
