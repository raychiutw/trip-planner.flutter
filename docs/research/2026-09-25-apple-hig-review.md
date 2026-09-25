# Apple HIG 與 App 規範研究：Tripline 適用性

研究日期：2026-09-25（Asia/Taipei）。範圍：Apple 官方 HIG、Developer Documentation 與 App Review Guidelines；本文件是研究與修正建議，不代表已完成真機 UI 驗收或判定目前 App 違規。

## 研究方法與規範層級

HIG 網頁正文由 JavaScript 載入，本次另讀取 Apple 官方 DocC JSON（例如 [Tab bars 原始文件](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/tab-bars.json)），不以搜尋摘要代替全文。下列引用連到可閱讀的官方頁面。Layout 文件的更新紀錄包含 2026-09-09，Tab bars／Searching 包含 2026-06-08，因此不是只根據 2025 年 iOS 26 發布印象推論。來源：[Layout](https://developer.apple.com/design/human-interface-guidelines/layout)、[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)、[Searching](https://developer.apple.com/design/human-interface-guidelines/searching)。

本專案的 [DESIGN.md](../../DESIGN.md) 已區分「HIG 必須」是 Tripline 自訂 release gate，並不表示 Apple 原文每條都是 must；[CONTEXT.md](../../CONTEXT.md) 定義語彙。本研究沿用浮動 header、固定 bar、root tab bar、bottom accessory、停留點與行程 POI。架構與產品決策仍以既有 ADR 為準。

- **Apple 設計指引**：HIG 建議、平台互動慣例與系統能力，不等於逐像素審核表。
- **App Store 規定**：App Review Guidelines 有適用前提的發布要求，另列於下方。
- **Tripline 決策／研究建議**：將前兩者套用本產品後的取捨；不是 Apple 唯一指定答案。

## 可直接用於 UI／UX 審查的規則

| 主題 | Apple 官方依據 | Tripline 審查與修正建議 |
|---|---|---|
| 頂層導覽 | Tab 用於頂層區域切換，保留各區導覽狀態；不要因內容不可用而隱藏或停用 tab。iOS 底部、iPadOS 頂部，可選擇切成 sidebar。[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars) | 保留既有四分頁；空行程、離線、錯誤仍能換頁。驗證進入詳情後換 tab 再回來仍在原位置，Account 關閉後恢復原 branch。四個 tab 與 Account 不占第五格是產品決策。 |
| 自適應版面 | 以實際 size class 決定 layout，而非裝置名稱或方向；支援文字、locale、視窗縮放與 safe area。[Layout](https://developer.apple.com/design/human-interface-guidelines/layout) | 沿用 [ADR-0009](../adr/0009-universal-ios-hig-width-driven-layout.md)，驗證窄 iPad 與寬手機；不能只測 iPhone／iPad 裝置標籤。寬版使用空間呈現清單與詳情，不將卡片等比拉寬。 |
| Toolbar 與返回 | 動作按功能分組，通常最多約三組；重要動作保留 trailing，少用背景與多餘外框。標準 Back／Close 優先使用熟悉符號。[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | 保留薄共用 chrome。長行程名、大字級與文字動作不得互相覆蓋；選單收低頻動作。不要為每頁重寫寬度補償。 |
| Liquid Glass | Glass 是控制／導覽的功能層，內容用 standard materials；自訂效果節制使用，並回應透明度與對比設定。[Materials](https://developer.apple.com/design/human-interface-guidelines/materials) | 列表卡片、筆記、表單不加玻璃。先驗證內容層級、可讀性與降級，再調光學；沿用 [ADR-0001](../adr/0001-keep-liquid-glass-over-native-cupertino.md)，不因 HIG 提到 native 就重換套件。 |
| Sheet 與編輯 | Sheet 承載有限任務；避免 sheet 疊 sheet。單頁 Cancel 在 leading，Done 在 trailing；多步驟有 Back。detent 取決於內容需要。[Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) | Account 子頁沿現有 Navigator push（[ADR-0010](../adr/0010-account-as-sheet-not-fifth-tab.md)）。驗證取消、拖曳、外點、系統返回的未儲存保護一致；儲存中防重送，失敗保留內容。這些資料保護細節亦為 repo 明定契約。 |
| 選單 | 動作用清楚動詞；相關項目分組，可用分隔線；常用項靠前，符號須有意義，同組全有或全無。[Menus](https://developer.apple.com/design/human-interface-guidelines/menus) | 「⋯」與長按同物件應同一動作集；角色／分類等值選項以勾選表示。停用項要可理解原因；大字級快捷格改直列，避免只露圖示不知作用。 |
| 搜尋 | 清楚標示範圍、可隨輸入更新、結果按相關性排序；可以局部搜尋，也可以統一入口，取決於資訊架構。[Searching](https://developer.apple.com/design/human-interface-guidelines/searching)、[Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields) | 沿用行程／收藏搜尋，不新增第五個搜尋 tab。區分「沒有資料」與「查無結果」；清除查詢與重設篩選分開。地圖不設搜尋是產品決策，不能解讀為 HIG 禁止地圖搜尋。 |
| 表單 | Placeholder 輸入後消失，可另保留 label；敏感欄位用 secure field，焦點順序合理，鍵盤符合資料類型，依情境驗證輸入。[Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) | 行程、停留點、筆記、分享設定以持續 label、欄位旁錯誤、Next／Done 與鍵盤避讓為優先；不要只靠一瞬間提示告知失敗。 |
| 日期時間 | 系統 picker 支援不同樣式與日期／時間模式，值與排序依 locale；分鐘間隔可用 60 的因數。[Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers) | 五分鐘間隔、確認後才寫回是 Tripline 決策，不是 Apple 強制。驗證 12／24 小時制、日期邊界與取消不改原值。 |
| 地圖 | 保留熟悉 pan／zoom／rotate，標記選取清楚，密集點可群聚；控制項需與底圖有對比。[Maps](https://developer.apple.com/design/human-interface-guidelines/maps) | 驗證浮動 header／accessory 不攔截地圖空白區；POI 卡與 marker 選取同步，定位拒絕仍可瀏覽。Apple Maps 的 logo／legal 規則是特定圖資要求，不應直接當成 Google SDK 合約；沿用 [ADR-0011](../adr/0011-single-map-sdk-google-navigation-flutter.md)。 |
| 字級與讀屏 | 可放大文字、合理對比、不單靠顏色、VoiceOver 與不同輸入方式可操作；以 Accessibility Inspector 稽核。[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | 至少驗證 2× 文字與完整系統大字級；所有圖示按鈕具名稱、selected／expanded 狀態可讀；日期、路線用編號／語意補色彩；拖曳排序提供按鈕或 accessibility action。44×44pt 是 Apple 現行表格的 default（minimum 另列 28×28pt）；全部控制至少 44pt 為本專案既有觸控 gate，未降低。 |
| 載入與 AI 等待 | 不留空白阻止其他操作；時間已知用 determinate、未知用 indeterminate progress。[Loading](https://developer.apple.com/design/human-interface-guidelines/loading) | 保留 stale 內容背景更新。聊天工單可長時間等待，呈現持續狀態、可離開再回來，不用假百分比，不以短 timeout 假裝失敗。具體工單生命週期來自 CONTEXT.md。 |
| 錯誤與刪除 | Alert 會中斷工作，只用於有用且必要的決定；不可復原且少見的破壞性操作要確認；錯誤寫明情境與可採行動。[Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | 一般離線狀態用持續說明與重試；保留輸入。依 [ADR-0008](../adr/0008-deletion-is-irreversible.md) 的永久刪除政策，具名確認、說明連帶影響、伺服器成功才移除，不另建 Undo。 |
| 權限 | 只索取功能需要的資料，最好使用功能時才詢問，purpose string 說明用途。[Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) | 點定位／麥克風才請求；拒絕後保留無定位瀏覽／文字輸入；不把重複權限 prompt 當作錯誤回復。 |
| 帳號 | 只有核心功能需要時才要求帳號；說明必要性，盡可能先讓人理解價值；提供刪除帳號。[Managing accounts](https://developer.apple.com/design/human-interface-guidelines/managing-accounts) | Login 說明同步與共編價值，保留返回／重試與錯誤文案；公開分享的瀏覽權限依後端契約判定，不為通用 HIG 擅改認證模式。 |

## App Store 規定：需獨立確認的發布條件

以下是有條件的檢核項，**尚未對 App Store Connect、後端、隱私政策全文及實際帳號流程作合規稽核，不宣稱現有版本缺漏**。

| 條文／官方來源 | 適用條件與應核對證據 |
|---|---|
| [5.1.1(i)、5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#privacy) | App 內及商店提供可存取的隱私政策；向第三方（含 AI）分享個資前，清楚揭露並取得明確許可。核對聊天／AI 健檢實際送出的資料、接收方與同意入口，不能只憑後端工單名稱推論沒有第三方分享。 |
| [4.8 Login Services](https://developer.apple.com/app-store/review/guidelines/#login-services) | 使用第三方服務建立／驗證主要帳號時，通常須有符合條文隱私條件的等價登入選項，另有列明例外。不能把條文簡化成「任何 OAuth 都必須 Apple 登入」；核對實際 enabled provider 與例外適用性。 |
| [Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/) | 支援帳號建立時，應能從 App 發起刪除，不僅停用；若需網頁完成，直接連到刪除頁。一般產品不應要求以客服電話／郵件代替；重新驗證身分是 Apple 允許的措施，不是所有產品一律必做。使用 Sign in with Apple 時核對 token 撤銷與完成通知。 |
| [2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/#app-completeness) | 審核時後端可用、流程完整、提供有效示範帳號或合適模式；不能以 widget test 全綠代替裝置穩定性驗證。 |
| [5.1.5 Location Services](https://developer.apple.com/app-store/review/guidelines/#location-services) | 定位僅用於直接相關功能，收集／傳送／使用前告知並取得同意；確認 map-only 功能沒有意外要求背景定位。 |

## 不應被誤列成 Apple 硬性要求的既有決策

1. 固定四個 tab、Account 放 sheet、每頁帳號 icon、不使用 Large Title、全平台同 iOS 外觀：是 [DESIGN.md](../../DESIGN.md) 與 ADR 的產品決策。Apple Toolbars 反而描述 large title 可協助定向；研究不因此推翻既有 inline title。[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
2. 五分鐘間隔、地圖無搜尋、所有刪除永久且無 Undo、固定底色百分比與 shader 係數：不可對外稱為 Apple 數值規格。[Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers)、[Maps](https://developer.apple.com/design/human-interface-guidelines/maps)、[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
3. 最新工具列／sheet 指引偏好熟悉 Back／Close 符號與 primary action 形式；repo 的「完成／取消／儲存一律文字」應按內部標準執行，但後續文件維護宜清楚標成 Tripline 選擇，不能用「HIG 一律要求文字」要求別人改 code。[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)、[Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
4. Android 跟隨 iOS 視覺是 ADR-0009 決定，HIG 不替 Android 定義平台規則；SF Symbols 等 Apple 素材的跨平台使用授權需另依實際資產與授權核對，不能由「遵守 HIG」推導授權已取得。

## 建議驗收順序與證據強度

本節是研究者套用上述來源後的建議，而非已查得的實作 bug。

1. **資料與狀態**：各頁的離線、錯誤、重試、提交鎖定、未儲存關閉、權限拒絕；尤其聊天送出、刪除、共編與分享。
2. **全頁可操作性**：320pt 寬、2× 與更大系統文字、橫向、compact／regular resize、鍵盤；VoiceOver 可以完成切換行程、選 Day、加入停留點及編輯。
3. **共用 chrome**：tab state restoration、Account 子導覽、選單焦點、sheet 關閉保護；先修共用入口再驗證所有 caller，避免每頁補丁。
4. **真機材質與地圖**：Light／Dark、Reduce Motion、Increase Contrast、Reduce Transparency，實際 PlatformView／shader 的可讀性與效能。widget PNG 能證明內容和幾何，不能證明 native 地圖、GPU 材質、VoiceOver 或實際權限對話正常。

原始研究稿階段只新增研究文件，未修改 production、發布 Issues／PR 或改寫 DESIGN／ADR。後續 #388 核對另於 DESIGN 加入本研究連結，既有產品規則與 ADR 維持不變。逐頁缺陷判定必須與目前程式碼及畫面證據合併閱讀。


## #388／T56 引用歸屬核對（2026-09-25）

對應 [Issue #388](https://github.com/raychiutw/trip-planner.flutter/issues/388)、父規格 [#332](https://github.com/raychiutw/trip-planner.flutter/issues/332)。核對基準為 `b9729c171eb1d27a21f7dfc2a98cabf3512824ae` 的 DESIGN／CONTEXT／ADR，及主 worktree 原有未追蹤研究稿的副本。此節只釐清來源，不改產品決策或 production。

### 判讀方式

- **A（Apple 建議／能力）**：官方 HIG 的設計方向、平台慣例或 API 能力描述；其中命令式措辭不自動等同 App Store 條款。
- **S（商店條款）**：App Review Guidelines 有適用前提的要求；要有條號與產品事實才可判定適用。
- **T（Tripline 規則）**：DESIGN／ADR 選定的 release gate、數值、資訊架構或實作契約。即使標作「HIG 必須」，強制等級仍歸 Tripline。
- **I（推論）**：研究者從原則推導的檢查方式，不是 Apple 原文指定方案。
- **V（待驗證）**：本次沒有取得對應實作、商店設定或真機證據；不得報成已通過或已違規。V 可與前四類並存。

### 原研究稿逐列核對

下表順序對應前方 15 列 UI／UX 研究表；原表第三欄一律為 T 或 I，不可當成 A 的逐字引用。

| 原列 | 核對結論與定位 |
|---|---|
| 頂層導覽 | A：Tab bars 的 Best practices 支持頂層導覽、保留狀態、不因內容不可用藏／停用 tab；iPadOS 明說 sidebar 切換是可選。T：四分頁、Account sheet、Day 與草稿的具體保留範圍。 |
| 自適應版面 | A：Layout 的 size classes／適應視窗與 safe area。T：ADR-0009 的 Flutter 寬度分界及 Android 共用配置；不是 Apple 的裝置分類值。 |
| Toolbar 與返回 | A：Toolbars 的 Item groupings 建議通常不超過三組、重要項目 trailing；Navigation 建議熟悉 Back／Close 符號。T：inline-only title、帳號固定入口、共用套件。 |
| Liquid Glass | A：Materials 的 Liquid Glass／Standard materials 分層及 accessibility 響應。T：Flutter 套件選擇、只讓哪些表面用玻璃、各項 shader 係數。V：實際材質與效能。 |
| Sheet 與編輯 | A：Sheets 的 Best practices 建議主介面一次一張 sheet；iOS／iPadOS 說明單頁按鈕位置與 dirty swipe 確認。T：Account 內 push、所有出口一致防護、提交鎖定、560×720 等尺寸。 |
| 選單 | A：Menus 的內容標籤、分組、圖示一致性。T：所有入口共用動作集、值選項不配圖示、最多三快捷格及大字級直列 fallback。 |
| 搜尋 | A：Searching 偏好統一入口，但不同區域可局部搜尋；Search fields 支持 scope、即時結果及相關性。T：無第五 tab、地圖不搜尋、清除與篩選獨立。不能把「不提供 action」推導為禁止 search tab。 |
| 表單 | A：Text fields 建議持續 label、敏感資料 secure field、合理驗證／焦點。T：每個指定表單採用的錯誤持續方式；I：把這些排為優先工作。 |
| 日期時間 | A：Pickers 的分鐘間隔可選 60 因數、不同模式及 locale 排序。T：五分鐘與確認才寫回。V：12／24 小時及跨日期的 App 實際結果。 |
| 地圖 | A：Maps 的熟悉操作、標記／群聚與 Apple logo/legal guidance。T：Google SDK、卡片／marker 同步、無搜尋。I：用空白區手勢測遮擋；Google 圖資條款另查，Apple Maps 數值不能移植成 Google 合約。 |
| 字級與讀屏 | A：Accessibility 的大字、對比、多種輸入、Inspector；目前控制尺寸表 iOS／iPadOS default 44×44pt、minimum 28×28pt。T：每一控制至少 44pt、完整 Dynamic Type 與 release 矩陣。V：原生讀屏和輸入。 |
| 載入與 AI | A：Loading 的背景工作及 determinate／indeterminate 原則。T：stale-first、工單長等待、不得短 timeout；Apple 未定義 Tripline 工單壽命。 |
| 錯誤與刪除 | A：Alerts 建議不對常見可 Undo 動作反覆警告，對少見且不可 Undo 的破壞操作確認。T：全部刪除永久、全部確認、server success 才移除、無 Undo。 |
| 權限 | A：Privacy 的功能當下請求與具體用途說明。S：資料收集／分享及定位同意另見 5.1.1／5.1.2／5.1.5。T：按定位／麥克風才詢問與拒絕後替代路徑。 |
| 帳號 | A：Managing accounts 建議避免不必要登入、清楚價值與刪除入口。S：帳號建立時刪除要求見 5.1.1(v) 及帳號刪除支援頁。T：登入文案／分享瀏覽依現行契約；未由 HIG 推定應開放所有匿名功能。 |

### DESIGN 逐節歸屬與易誤引條文

各節中元件名、具體數值、文字、資料狀態與 callback 契約屬 T；下列沒有要求刪去原規則，也沒有放寬 release gate。

| DESIGN 節／主張 | 正確歸屬與官方核對 |
|---|---|
| §1 標記、§20 階層 | T：文件自己已定義 HIG 必須是內部強制等級，ADR 優先是 repo 治理，不是 Apple 規則。 |
| §2 平台、最低版本與系統字體 | T：全平台 iOS 視覺、iOS 16 下限、自繪模擬；A：適應 layout、系統設定。Typography 也討論自訂字體，因此「不得自訂字型」是 T。 |
| §3.1 禁止搜尋進 tab bar | T：禁止搜尋是本 App 選擇；[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars) 的 iOS 節明確允許 trailing search tab，[Searching](https://developer.apple.com/design/human-interface-guidelines/searching) 也以 Photos／Apple TV 舉例。 |
| §3.1 四個 tabs、單字與 filled、selection haptic | T：固定四個與 haptic 觸發；A：標籤盡量單字、考慮 SF Symbols、偏好 filled。Apple 未規定只有 selected 才用 filled，也未在 Tab bars 要求每次切換都 haptic。 |
| §3.2 top tab／sidebar／split view | A：iPadOS top bar 及可選 sidebar；T：本產品「必須可切 sidebar」、深層行程 split view 與 Android 跟隨策略。 |
| §4.1 leading／trailing、文字動作、帳號位置 | A：Toolbars 的熟悉導覽位置與 trailing primary action。T：「完成／取消／儲存一律文字」、每頁帳號、最多一個主要動作；官方反而偏好容易識別的 symbols，無一律文字的命令。 |
| §4.1 選單／toolbar 群組 | A：[Menus](https://developer.apple.com/design/human-interface-guidelines/menus) 允許分組分隔，Toolbars 主張依功能分組。T：toolbar 不畫分隔線、三快捷格、plain「⋯」、套件轉接及符號對照。不可把 toolbar 與 menu 混為同一禁線規則。 |
| §4.2 行程選擇器 | T：chevron、44pt、sheet、單一行程停用、固定 VoiceOver 文案、Day 與草稿規則；A：可理解的控制名稱及選取狀態、長清單搜尋的一般方向。 |
| §5 Account／Settings | A：[Settings](https://developer.apple.com/design/human-interface-guidelines/settings) 的低頻設定集中及避免重複系統偏好。T：Account 承載、grouped list、三段 appearance、本機保存及還原 branch。Sign in with Apple 的 HIG 建議須與有條件的商店 4.8 分開。 |
| §6 Search | A：scope、clear、相關性；T：哪些頁面可搜、清除不改其他狀態、點外只收鍵盤的詳細契約。 |
| §7 accessory／composer | A：Tab bars 描述 accessory 及「可選」minimization。T：最多一個、鍵盤開就藏 bar、最多四行、沒有＋、Command–Return、草稿 per-trip。 |
| §8 Day selector | A：[Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls) 建議 iPhone 約最多五項、同組型態一致。T：長行程橫向捲動、自動置中、露下一項、滑動不選、具名替代動作；不是原生 segmented control 的硬性規格。 |
| §9 地圖／POI | A：[Maps](https://developer.apple.com/design/human-interface-guidelines/maps) 的熟悉地圖操作與可讀性。T：定位獨立控制、日間底圖、POI accessory、雙向同步、卡片資訊欄位、無 detent；V：PlatformView 手勢與遮擋。 |
| §10 日期時間 | A：[Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers) 的模式與在地化。T：五分鐘、picker 類型、取消與寫回時機。 |
| §11 sheet／表單 | A：[Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) 的 leading Cancel／trailing Done、dirty swipe、一次一張。T：所有出口 guard、提交去重、成功才關、文字按鈕、套件分工；Apple 也允許先關第一張再開第二張，不只內層 push。 |
| §12 刪除 | A：[Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) 的明確動詞及危險提示。T：無 full swipe、所有刪除紅色、安全選項預設焦點、高影響操作重新驗證；Alerts 並未要求 Cancel 為 default button，甚至建議不要如此。焦點與 default activation 是不同概念，後續驗收需分辨。 |
| §12 帳號重新驗證 | Apple [刪除帳號 FAQ](https://developer.apple.com/support/offering-account-deletion-in-your-app/) 允許驗身分與確認，但反對不必要阻礙；「刪除帳號／登出全部一律 reauth」是 T，不是該頁的 S。 |
| §13 拖拉／swipe | A：可及性要求替代輸入、清楚狀態及減少動態。T：只用 drag handle、卡片不得多用途、跨 Day 完整還原、具體上下移 action 與手勢區域。 |
| §14 回饋／離線 | A：[Loading](https://developer.apple.com/design/human-interface-guidelines/loading) 及 Alerts 支持及早呈現、背景操作、避免濫用警告。T：SWR、離線佇列行為、持續離線列與指定 semantics 實作方式。 |
| §15 權限 | A：[Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) 建議在情境中請求、說明用途與用 picker 最小化資料存取；T：本產品功能入口及拒絕後復原。S 只按商店條文另查。 |
| §16.1 色彩 | A：[Color](https://developer.apple.com/design/human-interface-guidelines/color)／[Branding](https://developer.apple.com/design/human-interface-guidelines/branding) 支持可讀、適應與一致。T：暖褐唯一 tint、只前景、地圖例外、禁止自訂完整 palette；Apple 不指定本品牌色。 |
| §16.2 材質 | A：[Materials](https://developer.apple.com/design/human-interface-guidelines/materials) 的功能層／內容層與輔助設定；T：所有透明度、blur、Fresnel、edgeAbsorption 及品質 fallback。I：公式推估；V：新 build 光學與效能，不挪用 #319 舊配方結果。 |
| §16.3–4 字體／icons | A：[Typography](https://developer.apple.com/design/human-interface-guidelines/typography)／Accessibility 的可讀、Dynamic Type 及名稱；T：禁自訂字體、iOS 16 symbols 下限、所有 icon tooltip、所有控制 44pt。素材跨平台授權須另核對，HIG 並非授權書。 |
| §16.5 App icon | T：圖形、三色、Single Size／Android PNG 工作流與所有 PNG 無 alpha。[App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) 現亦涵蓋分層透明素材；不能把 repo PNG 規則推廣為所有 Icon Composer layer 都禁 alpha。 |
| §17 動畫／haptic | A：[Motion](https://developer.apple.com/design/human-interface-guidelines/motion)／[Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) 支持有目的、克制及尊重偏好。T：每種事件的白名單、一般按鈕絕不震動、精確動畫 fallback。 |
| §18 accessibility gate | A：可操作、足夠尺寸、不同輸入、不要只靠色彩。T：release-blocker 清單、Flutter 偵測方式與排除項。V：本次未核對 Flutter SDK flags 或各種原生輔助科技通過情形。 |
| §19 驗收矩陣 | T：CI 指令、140 PNG、10 態與裝置組合；V：本次未重跑且不聲稱目前仍全部通過，widget PNG 不等於 native 材質／讀屏合格。 |

### 商店五列與其適用前提

1. **S／V**：5.1.1(i) 是隱私政策入口；5.1.2(i) 是個資分享（包含第三方 AI）的揭露／事先明確許可。T：Tripline 同意 UI 的具體形式；V：實際接收者、資料、商店與後端配置。
2. **S／V**：4.8 是第三方／社群登入主要帳號時的等價登入及列明例外，不是所有 OAuth 或 PKCE 都強制 Sign in with Apple。
3. **S／V**：5.1.1(v) 與刪除帳號支援頁適用於能建立帳號的 App；不是停用代替刪除。身分確認是允許，不可製造過度阻礙。
4. **S／V**：2.1 要求送審版本完整、服務可用與審核可存取；測試全綠不等於已滿足商店審查。
5. **S／V**：5.1.5 對相關定位功能要求告知與同意；禁止背景導航不是此條對所有 App 的規定，而是本專案 map-only 範圍。

來源：[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)、[Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)。以上不構成完整雙商店合規盤點；Google Play 政策不由 Apple 文件代替。

### 同日其他研究的證據銜接

主代理另完成正式隱私頁的 Chrome hydrated 正文核對，記錄於 [#386 研究留言](https://github.com/raychiutw/trip-planner.flutter/issues/386#issuecomment-5828100007)，研究 commit `0d8f1cc`。該紀錄回報政策版本 2026-07-20、390×844 無水平溢出、`#delete-account` 與 mailto 入口可見；這不是手機真機驗證，也未點 mailto 或寄信。本次引用該獨立紀錄，不把較早抓取 403 解讀成政策不存在；同樣不能由頁面可讀推定 AI 接收者、部署內容或帳號刪除能力已符合條款。

### 重現、版本與證據邊界

先以 `git show b9729c171eb1d27a21f7dfc2a98cabf3512824ae:DESIGN.md` 固定產品規範，再讀每個官方頁。HIG 若只回 JavaScript 外殼，改抓官方 `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/{slug}.json`，核對 `primaryContentSections` 與內嵌 Change log，而非把搜尋摘要當全文。可用 `curl -fL` 儲存 JSON，接著 `shasum -a 256` 與下表比對；日後 hash 不同代表應重新閱讀，不表示曾經核對的版本失效。網頁沒有單一 HIG 版本號；日期與內容 hash 是本次來源識別。

實際已做：讀取 26 份 Apple 官方 DocC JSON、App Review Guidelines 與帳號刪除 FAQ，對照研究稿全部 15 列／5 個商店項目／4 項易誤引決策及 DESIGN 各節。原稿所列 Layout 2026-09-09、Tab bars／Searching 2026-06-08 更新日期可在 JSON Change log 重現。

未做：production 變更、Flutter analyze／test、App Store Connect／Play Console 稽核、資料流監測、登入 provider 實際設定查驗、裝置操作、材質／效能／VoiceOver／權限驗證。ADR 中的歷史量測僅保留來源，未在本次重測；新結果必須另附 build、OS、裝置、設定與擷取步驟。

| 官方 DocC slug | 本次回應 SHA-256 |
|---|---|
| `accessibility` | `be49ec0b34397f356a1e3fd8c7ad323713198515523947097913cb9c57da699b` |
| `alerts` | `ca60f14c249290f1dcebe8bbaedde16183e3759f5a53238085915795e2e4dbdc` |
| `app-icons` | `5f67bb7b1e2405ee03526ab83c3f75b63b28473ce39ebf10848655908e2712f7` |
| `branding` | `2251b5c75eeaae25282ba10257cf26a3f5c92b01fb253f39010e610bcc8fce60` |
| `buttons` | `fb450f96dd7a201a0203852782252942ee6d72978e0baaec1cb4c400568fed91` |
| `color` | `262ce33cb88d41ac0238bf1e3f59b7957e8ddb030379c41b35a6cbdb9ab11a39` |
| `layout` | `d41f32ddf76c597f0edd54eac361fa294a8736cfc4ccc627d1709fe092ed7267` |
| `loading` | `83c69df80cfafd72b1a317d82521f14dfdb415530cdf37c290462eb28673b901` |
| `managing-accounts` | `f7bdc4b8223dae5c4bfe34c89c78836d9d1effb4ddcd0bfdf87ccf44e716f597` |
| `maps` | `6dfe6a420882e08ca3e4ceba718fce1f2f7ef77c3c90c5cc81930e2fde7fa153` |
| `materials` | `597da170985715de4bd8446df12e3604595e634a790b5da0ce6673d2b2327ed5` |
| `menus` | `dff423968b85e717c175a1999897224e6157cd7ce2f5907d64bf93088532dcf1` |
| `motion` | `957268c323af4617dabb6c0449d0920248c995159d54f76c691aa180ceb72a61` |
| `pickers` | `73d7d22d7a21124a52832ff09c887f54d191e3bf2152e20f314ca3558288c5f2` |
| `playing-haptics` | `68bab380a07eff7aa471d589565891bd904d4615bea3629766d4b7a11ab5c5ba` |
| `privacy` | `9c637c45ac3a1c5414a4b7b6f606dbcd69a642fc01bf252bbdee0644fc299dd3` |
| `search-fields` | `57ad53c788667b8676c585a5c6ef7f6bdaa297dd0a206f9e6606351265045bbb` |
| `searching` | `e88879b435c2746f33924395f9992adc052177adac4bf037dd923034b1b996bd` |
| `segmented-controls` | `58316edb97f3e1b141e4c86d4671ebc994f5feb68576379f94f5f4be29537d88` |
| `settings` | `c17e9a542a806d828ef5bef1df044cee2c2c135f96e8d0c591d873c2507449cc` |
| `sheets` | `3e1a1accb148d23db5a74907b56438de35cdafdb1aafcc12722c7097d7829459` |
| `sidebars` | `5aff188db0d343d4286e15a8ed6a7baadef4cfa60565ce374be0c51aae64859d` |
| `tab-bars` | `b2f48f79d3f8a5bd00f2e3b462a19debd0a557ea0113ed8e573907bb06513f07` |
| `text-fields` | `18324cc7181a498b9324a1980231260785ee427eb9ae48f775bfa06a96153d40` |
| `toolbars` | `4f1147642ab0561dcb2d4b074be970a537e2072be41e061314d1e234b4cdc6f7` |
| `typography` | `85bf7dc78d41a6e5e16d4055f3bdadf7bac4f7d5cb2206514c8b82d5d24631ed` |
