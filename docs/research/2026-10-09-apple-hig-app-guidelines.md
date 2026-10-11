# Apple HIG 對 iOS App 的規範：數值與規則補充（Tripline 適用性）

研究日期：2026-10-09（Asia/Taipei）。本文件補充 [2026-09-25 的 HIG 審查](2026-09-25-apple-hig-review.md)，不重複其已涵蓋的逐主題審查表；本次聚焦三件事：(1) 補上先前缺少的**具體數值與表格**，(2) **修正或限定**先前與 [DESIGN.md](../../DESIGN.md) 中容易被誤讀的說法，(3) 列出 HIG 原文與 Tripline 現行決策**有張力**之處供決策者參考。本文件是研究，不判定現有程式違規，也不改動任何規範。

## 方法與來源

HIG 網頁正文由 JavaScript 載入，本次直接讀取 Apple 官方 DocC JSON，端點格式為 `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`（路徑沒有 `documentation/`），每頁 HTTP 200 後以腳本抽出段落、清單與表格（含分頁籤內的 Dynamic Type 表）。下文每個主張都附可閱讀的官方頁面 `https://developer.apple.com/design/human-interface-guidelines/<slug>`，內容與同 slug 的 JSON 一致。不引用任何二手來源。

各頁 Change log 的最新日期（用來判斷是否過時）：Layout 2026-09-09、Tab bars 2026-06-08、Menus 2026-06-08、Search fields 2026-06-08、Sheets 2026-03-24、Toolbars 2025-12-16、Color 2025-12-16、Buttons 2025-12-16、Typography 2025-12-16、Materials 2025-09-09、Motion 2025-09-09、Accessibility 2025-06-09、Alerts 2024-02-02、Context menus 2023-12-05、Dark Mode 2024-08-06、Segmented controls／Lists and tables 2023-06-21。

規範層級沿用先前文件的三分法：**Apple 設計指引**（HIG 原文）、**App Store 規定**（本文不涉及）、**Tripline 決策**（DESIGN.md／ADR）。HIG 多數用語是 "consider／prefer／avoid"，少數是 "must"；下表會保留這個強度，不一律寫成必須。

## 摘要

1. **觸控目標有「預設」與「最小」兩個數值**：iOS／iPadOS 預設 44×44 pt、最小 28×28 pt；Buttons 頁另寫「hit region 至少 44×44 pt」。Tripline 的 44pt gate 對齊 HIG 的預設值，是合理的內部標準，但不應對外說成「Apple 規定最小 44pt」。見[§3](#3-觸控目標與間距)。
2. **Dynamic Type 有完整數值表**：預設 Large 下 Body 17pt／leading 22、Footnote 13、Caption 2 為 11；可及性級距 AX1~AX5 的 Body 為 28~53pt。HIG 建議「至少讓文字可放大 200%」。見[§2](#2-文字與-dynamic-type)。
3. **HIG 與 DESIGN.md 有五處張力**（非違規，需決策者知情）：app 內外觀切換（§5 Dark Mode）、Large Title（§4）、完成／取消用文字（§4）、menu 項目停用的呈現（§6）、不可復原刪除無 Undo（§8）。見[§11](#11-hig-原文與-tripline-決策的張力點)。
4. **玻璃與 Reduce Motion 的新細節**：HIG 對 clear Liquid Glass 建議在亮背景加 **35%** 暗化層；Reduce Motion 建議「避免動畫進出 blur」，與玻璃動畫直接相關。見[§7](#7-材質liquid-glass)、[§9](#9-motion-與-reduce-motion)。
5. **先前文件有兩處需限定的說法**：Toolbars 的「最多三組」是 groups 數量建議，不是按鈕數；「標準 Back／Close 優先用符號」是明文 "don't use a text label that says Back or Close"。見[§4](#4-navigation-bar--toolbar)。

## 1. Layout、size class 與 safe area

| 規則 | 強度 | 來源 |
|---|---|---|
| 以 size class（compact／regular）決定版面，**不要以裝置類型或方向**決定；size class 描述實際可用空間 | 原文 "Determine layout based on size classes, not device type or orientation" | [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) |
| 考慮所有 size class 組合；僅為 compact 直向設計，在 iPad regular 寬度會留白 | 建議 | 同上 |
| size class 改變時「不要改變 app 的功能」，但可改變同時可見的功能量（例如 tab bar 轉 sidebar、把 overflow menu 內的功能攤開） | 原文 "Don't change your app's functionality based on the space it occupies" | 同上 |
| 尊重 safe area、margin、layout guide，避免系統 UI（Dynamic Island 等）遮擋內容與控制項 | 原文稱 "essential" | 同上 |
| 全螢幕背景內容要延伸到 sidebar／toolbar／tab bar 底下；需要區分控制項與內容時，用 scroll edge effect，而不是在控制項下墊實色或半透明底色 | 建議 | 同上 |
| 水平相鄰的 view 在大字級可能需改為垂直堆疊；table row 要隨文字增高，單行 row 在大字級可能需多行 | 建議 | 同上 |
| 對 iPhone 的人體工學描述：中段與下段的控制項較易觸及；列表 row 要支援滑動動作與滑動返回 | 建議 | [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) |

**重要限定**：Layout 頁（含其 2026-09-09 更新）**沒有**給 iOS 的 safe area 像素數值、也沒有 compact／regular 的寬度斷點；這些必須由系統 API（size class、safe area insets）取得。Tripline 的 `regularNavigationWidth = 720.0`（ADR-0009）是產品決策，不是 Apple 數值。

## 2. 文字與 Dynamic Type

來源：[Typography](https://developer.apple.com/design/human-interface-guidelines/typography)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)。

- iOS／iPadOS 文字**預設 17pt、最小 11pt**（Typography 與 Accessibility 兩頁同一張表）。
- 避免 Ultralight／Thin／Light 字重，偏好 Regular、Medium、Semibold、Bold。
- 「至少讓人能把文字放大 200%」（Accessibility，Vision 段）。
- 大字級時：盡量減少截斷；在可捲動區域避免截斷，除非可開另一頁看全文；水平受限時改堆疊式版面；減少欄數。
- 使用者放大文字時，**並不期待每個字都變大**：例如 tab 標題不需跟著放大（Typography「Prioritize important content when responding to text-size changes」）。
- 以 text style 取字，系統自動支援 Dynamic Type 與 Bold Text；不要內嵌系統字體。

iOS／iPadOS Dynamic Type 數值（pt，size／leading；來源同 Typography 的 Specifications 分頁表）：

| Style | xSmall | Small | Medium | **Large（預設）** | xLarge | xxLarge | xxxLarge |
|---|---|---|---|---|---|---|---|
| Large Title | 31/38 | 32/39 | 33/40 | **34/41** | 36/43 | 38/46 | 40/48 |
| Title 1 | 25/31 | 26/32 | 27/33 | **28/34** | 30/37 | 32/39 | 34/41 |
| Title 2 | 19/24 | 20/25 | 21/26 | **22/28** | 24/30 | 26/32 | 28/34 |
| Title 3 | 17/22 | 18/23 | 19/24 | **20/25** | 22/28 | 24/30 | 26/32 |
| Headline（Semibold） | 14/19 | 15/20 | 16/21 | **17/22** | 19/24 | 21/26 | 23/29 |
| Body | 14/19 | 15/20 | 16/21 | **17/22** | 19/24 | 21/26 | 23/29 |
| Callout | 13/18 | 14/19 | 15/20 | **16/21** | 18/23 | 20/25 | 22/28 |
| Subhead | 12/16 | 13/18 | 14/19 | **15/20** | 17/22 | 19/24 | 21/28 |
| Footnote | 12/16 | 12/16 | 12/16 | **13/18** | 15/20 | 17/22 | 19/24 |
| Caption 1 | 11/13 | 11/13 | 11/13 | **12/16** | 14/19 | 16/21 | 18/23 |
| Caption 2 | 11/13 | 11/13 | 11/13 | **11/13** | 13/18 | 15/20 | 17/22 |

較大的可及性級距（Body／Caption 2，size／leading）：AX1 28/34、20/25；AX2 33/40、24/30；AX3 40/48、29/35；AX4 47/56、34/41；AX5 53/62、40/48。Large Title 在 AX5 為 60/70。

字距（tracking）：SF Pro 在 17pt 為 -26（1/1000 em，約 -0.43pt）、在 12pt 為 0、在 11pt 為 +6（Typography 的 tracking 表）。系統字體於執行時自動套用，Flutter 若使用 `CupertinoSystemFont`／平台字體會繼承；自行載入字體才需手動處理。

**測試含意（建議，非 HIG 條文）**：DESIGN.md 驗收用「2× 文字」與「完整系統大字級」。依上表，Large 的 Body 17pt 乘 2 ≈ 34pt，介於 AX2（33）與 AX3（40）之間，所以 2× 近似 AX2，**並未涵蓋 AX3~AX5**；若要主張「支援全部 Accessibility Sizes」，需另測至 AX5（Body 53pt，約 3.1×）。

## 3. 觸控目標與間距

來源：[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)（Mobility 段）、[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)。

| 平台 | 預設控制項尺寸 | 最小控制項尺寸 |
|---|---|---|
| iOS、iPadOS | 44×44 pt | 28×28 pt |
| visionOS | 60×60 pt | 28×28 pt |
| macOS | 28×28 pt | 20×20 pt |

- 間距與尺寸同樣重要：有 bezel（邊框／底）的元素周圍約 **12pt** padding；無 bezel 的元素約 **24pt**（Accessibility）。
- Buttons 頁另寫：「一般而言 button 的 hit region 至少 44×44 pt」；自訂 button 一律要有 **press state**。
- 對比：文字至多 17pt 需 4.5:1；18pt 為 3:1；粗體 3:1（Accessibility，WCAG AA 對照表）。Dark Mode 頁寫「最低不低於 4.5:1，自訂前景背景力求 7:1，特別是小字」（[Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)）。
- 手勢：高頻動作用最簡單的手勢；對可用手勢完成的事，**提供替代操作**（例：滑動關閉的同時提供按鈕）（Accessibility）。
- 避免倒數／計時自動消失的 UI，偏好以明確動作關閉（Accessibility，Cognitive 段）。

**限定**：Tripline 的「所有互動控制至少 44×44pt」是**比 Apple 最小值（28pt）更嚴**的內部 gate，與 Apple 的「預設 44pt」一致。報告或 PR 描述宜寫「對齊 HIG 預設 44pt」，避免被引用成 Apple 強制最小值。

## 4. Navigation bar／Toolbar

來源：[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)。補充：`navigation-bars` 在現行 HIG 不再是獨立頁（JSON 端點回 404），內容併入 Toolbars，該頁寫明「In iOS, a navigation-specific toolbar is sometimes called a navigation bar」。

| 主題 | 原文要點 | 備註 |
|---|---|---|
| 群組數 | "Minimize the number of groups... In general, aim for a maximum of three." | 單位是**群組**，不是按鈕數，先前文件寫「最多約三組」是對的，但易被誤讀成三顆按鈕 |
| 三個位置 | leading（返回、sidebar 切換、標題）、center（常用控制）、trailing（重要項目、搜尋、More menu、主要動作如 Done） | trailing 項目在所有視窗尺寸保持可見 |
| 主要動作 | 用 `.prominent` 樣式標示 Done／Submit，**只指定一個**，放 trailing | |
| 返回／關閉 | "Prefer the standard symbols for each, and don't use a text label that says Back or Close." 自訂版本必須外觀與行為一致且全 app 一致 | 與 DESIGN.md「完成／取消／儲存一律文字」有張力，見 §11 |
| 動作用符號還是文字 | "Prefer simple, recognizable symbols for items instead of text, except for actions like edit that aren't well-represented by symbols." | 符號不必加邊框（容器已提供） |
| 文字與符號並排 | 帶文字的動作要與符號動作分開，之間加固定間距，避免兩者看起來像一個複合按鈕 | 對 `GlassButtonGroup` 內混排文字與圖示時相關 |
| 背景與著色 | "Reduce the use of toolbar backgrounds and tinted controls"；內容層是彩色時，toolbar 偏好預設單色 | |
| 標題 | 簡潔，**建議少於 15 個字元**；不要用 app 名稱當標題；標題冗餘時可留空 | 這是 HIG 少見的字元數值 |
| Large title（iOS） | "Use a large title to help people stay oriented as they navigate and scroll"，捲動時過渡為標準標題 | Tripline 決策為不用，見 §11 |
| More menu（iOS） | 空間有限，只放最重要項目，其餘進 More menu；"Try to include all actions in the toolbar if possible" | |
| 避免 overflow | 不要手動加 overflow menu；避免預設就溢出的版面 | |

另：Layout 與 Color 頁都寫，Liquid Glass 控制項**不要**在下方再墊實色／半透明底（用 scroll edge effect），見 §7。

## 5. Tab bar

來源：[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)（2026-06-08 更新）。

- Tab bar 用於導覽，不放動作；**tab bar 要保持可見**，除非被 modal 覆蓋。
- "Don't disable or hide tab bar buttons, even when their content is unavailable"；若區段為空，說明為什麼沒有內容。
- 標籤盡量單字；icon 用 SF Symbols，**偏好 filled 版本**；compact 時 icon 在標籤上方，regular 時並排。
- 盡量少 tab；避免 overflow（空間不足時，最後一個 tab 變成 More，iOS 與 iPadOS）。
- Badge：紅色橢圓，白字，數字或驚嘆號；只保留給**關鍵**資訊。
- iOS：tab bar 浮在內容上方，使用 Liquid Glass 背景；搭配 accessory（如 Music 的 MiniPlayer）時，可在向下捲動時**縮小 tab bar** 並把 accessory 移到同一排；點 tab 或捲回頂端還原。
- iOS 可在 tab bar 尾端放專用 search tab（標準 tab 樣式或 button 樣式）。
- iPadOS：tab bar 在頂部，可固定或透過按鈕轉成 sidebar；自訂 tab 時預設清單**五個以下**以維持 compact／regular 的連續性。
- 內容層若顏色鮮豔，tab 標籤避免用相近的顏色（偏好單色或差異夠大的 accent）。

**限定**：此頁**沒有**給 tab bar 高度的 iOS 數值（頁面內唯一的高度 68pt／距頂 46pt 是 tvOS）。DESIGN.md 的「每個 tab 至少 44×44pt」來自 §3 的控制項尺寸，不是 tab bar 專屬規範。

## 6. 選單、Context menu、Action sheet、Alert、Sheet、Modality

### 6.1 Menus（含 iOS 版面）

來源：[Menus](https://developer.apple.com/design/human-interface-guidelines/menus)（2026-06-08 更新了 menu item icon 指引）。

- iOS／iPadOS menu 有三種版面：**Small**（上方一排四項、僅符號）、**Medium**（上方一排三項、符號在上短標籤在下）、**Large**（預設，全為清單）。有三個重要常用動作時考慮 Medium；Small 只用於緊密相關動作（粗體／斜體／底線／刪除線）。這正是 DESIGN.md §4.1 的三格快捷列所依據的形式。
- "Show people when a menu item is unavailable"：**一般 menu 的不可用項目通常變暗且不回應**，且即使全部不可用，menu 本身仍要能開啟。
- Icon：常用動作用標準 icon；"provide icons for all menu items in a group, or none of them"；找不到明確符號就不要放。
- 順序：重要或常用的在前；相關的分組並以 separator 區隔；留意長度，太長就分拆或用 submenu。
- Submenu 少用，最多**一層**，超過約五項考慮另開 menu；submenu 不可用時入口仍保留。
- 標籤：動詞開頭；需要更多資訊才能完成的動作加省略號（…）；toggle 可用「會變的標籤」（Show Map／Hide Map）或勾選標示目前狀態。

### 6.2 Context menus

來源：[Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus)（2023-12-05 加入「隱藏不可用項目」）。

- **"Always make context menu items available in the main interface, too."**（Mail 例：收件匣訊息的 context menu 項目也在訊息畫面的 toolbar）。
- 項目要少；整個 app 一致地提供；優先放最常用的；separator 分組，**建議不超過約三組**；submenu 只到一層。
- **"Hide unavailable menu items, don't dim them."**（與一般 menu 的「顯示並變暗」相反。）
- 破壞性項目放最後並標示為 destructive（紅字）。
- iOS：同一個物件提供 context menu 或 edit menu 其一，不要兩者並存；preview 要能代表被操作的對象。

### 6.3 Action sheet 與 Alert

來源：[Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets)、[Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)（2024-02-02）、[Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback)。

- Alert：標題＋可選說明＋**最多三個按鈕**；標題勿寫成「Error」；按鈕 1~2 字、動詞；不要用 OK 當預設鈕（純資訊例外）；取消鈕一律叫 "Cancel"；預設鈕在 trailing（或堆疊最上方）；有破壞性選項時要有 Cancel；**不要把 Cancel 當預設鈕**。
- "Use the destructive style... [for] a destructive action people didn't deliberately choose"：使用者**刻意**選的破壞性動作（如清空垃圾桶），確認鈕不套 destructive 樣式。
- **Alert 慎用**：只提供資訊就改用情境內顯示（Mail 的連線不可用指示）；對「常見且可復原」的破壞性動作別跳 alert；**App 啟動時避免跳 alert**，離線應改顯示快取＋不干擾的標示。
- Action sheet：用於「與一個刻意動作相關的選擇」；**不超過四個按鈕（含 Cancel）**；避免捲動；破壞性選項放最上方且為 destructive 樣式；標題單行。
- Feedback：「**預期且不可復原的資料遺失才警告**；資料遺失是預期結果時不警告」；成功預期的動作不必每次確認，重要的才確認；無法執行時要說明原因。
- Assistive Access 下：難以復原的動作（如刪除檔案）"Always ask for confirmation twice"（[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)）。

### 6.4 Sheet 與 Modality

來源：[Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)（2026-03-24 更新按鈕位置）、[Modality](https://developer.apple.com/design/human-interface-guidelines/modality)。

- 一次只顯示一個 sheet；若 sheet 內動作要開另一個，先關第一個。
- Cancel／Close 關閉不存檔；Done 完成並存檔；Back 在多步驟流程中回上一步，**不用來關閉 sheet**。提供 Done 就要配 Cancel 或 Back；**不要三者同時出現**。
- iOS：單頁 sheet 的 Cancel 在 **leading**、Done 在 **trailing**；多步驟時各步驟位置可不同（首步 Cancel、後續步驟 Back、最後一步 Done）。
- Detent：系統兩個，**large**（完整展開）與 **medium**（約一半）；預設自動支援 large；iPhone 上 medium 利於漸進揭露（分享 sheet），但編寫型 sheet（Messages、Mail 撰寫）只用 large。
- resizable sheet 要有 **grabber**，可點擊循環 detent，且與 VoiceOver 搭配。
- 支援向下滑動關閉；若有未存變更，**用 action sheet 讓人確認**。
- iPadOS 偏好 page／form sheet 樣式。
- Modality：只在有明確好處時使用；保持短而簡單；避免「app 中的 app」——modal 內若有子畫面，給單一路徑，且避免出現會被誤認為關閉鈕的按鈕；一定要給明顯的關閉方式；用標題說明 modal 的任務；有資料遺失風險時關閉前要確認。

## 7. 材質（Liquid Glass）

來源：[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)（2025-09-09）、[Color](https://developer.apple.com/design/human-interface-guidelines/color)（2025-12-16）、[Layout](https://developer.apple.com/design/human-interface-guidelines/layout)。

- Liquid Glass 是**控制與導覽的功能層**，浮在內容層上；"Don't use Liquid Glass in the content layer"，內容層用 standard materials。例外：內容層中短暫互動的控制（如 slider、toggle）被操作時會呈現玻璃。
- 自訂控制項**節制**使用玻璃，限於最重要的功能元件。
- 兩個變體：**regular**（模糊並調整背景亮度以保證易讀，多數系統元件用，文字多時如 alert、sidebar、popover 用）與 **clear**（高度透明，只用於浮在照片／影片等**視覺豐富背景**上的元件）。
- clear 變體：**背景偏亮時考慮加 35% 不透明度的暗化層**；背景夠暗則不需要。
- 玻璃預設無色，吸收背後內容的顏色；上色用於需強調的元素（主要動作），**"apply color to the background rather than to symbols or text"**（系統的 prominent button 即把 accent 套在背景），並"Refrain from adding color to the background of multiple controls"。
- 小元件（toolbar、tab bar）會隨背景自動在淺／深外觀間調整，符號與文字預設單色。
- 降低透明度、增加對比等系統設定會改變玻璃外觀，需一併測試。
- Standard materials 在 iOS：ultra-thin、thin、regular（預設）、thick 四種；在其上用系統 vibrant 色；避免依「看起來的顏色」挑 material，應依語意。

**對照提醒**：DESIGN.md §4.1 對媒體背景控制項採 **45% 黑**填色、#319 的一組 fresnel／lightIntensity 係數，均屬 Tripline 決策；HIG 只給「35% 暗化層（亮背景）」一個建議值，且是針對 clear 變體，不能當作 Tripline 係數的 Apple 依據（先前文件已有同方向的提醒，此處補上 HIG 實際的數字）。另 ADR-0004 的「選取表面中性、tint 只上前景」與 HIG「主要動作把 accent 套在背景」方向相反——前者針對 **tab／選取指示**、後者針對 **prominent button**，範疇不同，但寫文件時宜分開說。

## 8. 搜尋、輸入、日期、列表、分段、拖放

### 8.1 搜尋

來源：[Searching](https://developer.apple.com/design/human-interface-guidelines/searching)、[Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields)（2026-06-08 更新）。

- 搜尋重要就給主要位置；"Aim to make your app's content searchable through a single location"，但有清楚分區的 app 仍可有局部搜尋（Music 搜尋自己的歌曲與專輯即作為當前 view 的篩選）。
- 明確顯示當前範圍：用描述性 placeholder、scope bar 或標題。
- 輸入即搜、先給最相關結果、可顯示最近搜尋與建議；顯示搜尋歷史要留意隱私並提供清除。
- iOS 三種入口：**tab bar 內的 search tab**、**toolbar（底部或頂部）**、**inline 欄位**。inline 適合「位置本身決定範圍」或有多個搜尋欄的情況；放在列表上方時，考慮捲動時釘到頂部 toolbar。
- "Place search at the bottom if there's room"（Settings、Mail、Notes 例）；頂部適合下方有主要內容（如 Wallet 票券）時。
- Scope bar 預設較廣範圍，讓人逐步縮小。
- Text field：placeholder 輸入後消失，需另有 label；密碼欄用 secure field；**trailing 放 Clear 鈕**；欄位順序合乎邏輯（[Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)）。

### 8.2 資料輸入

來源：[Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)、[Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers)。

- 能從系統取得就不要請使用者輸入；能用選項就不要要求打字；支援貼上與拖放。
- 即時驗證，錯了立刻回饋；必填未填時「Next／Continue 不可按」。
- Date picker 四種模式：Date、Time、Date and Time、Countdown timer；四種樣式：Compact、Inline、Wheels、Automatic。空間有限用 compact（點開 modal，編輯後**點外面確認**）。
- 數值與順序跟隨裝置 locale。
- 分鐘間隔：**可調大，但必須能整除 60**（例：15 分鐘為 0/15/30/45）；Tripline 的 5 分鐘符合此條件。
- Picker 應在上下文就近顯示（欄位下方或 popover），"Avoid switching views to show a picker"。

### 8.3 列表與分段

來源：[Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)、[Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)。

- 列表偏好放文字；iOS 需進入編輯模式才能選取多列；導覽型列表持續高亮選取列、選項型列表短暫高亮後顯示 checkmark。
- 文字過長時中間省略可保留頭尾；info 鈕只用來顯示資訊，下鑽用 disclosure indicator。
- Segmented control：**iPhone 上建議不超過約五段**（寬介面五到七）；各段寬度一致；同一控制項不要混用圖與字；不要在「顯示選取」的控制項裡放動作；標籤用名詞；用於**緊密相關的子視圖**切換，區段間徹底分離的內容用 tab bar。Day selector 的長捲動設計超出此建議，DESIGN.md 已明文標為產品決策。

### 8.4 拖放

來源：[Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop)、[Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures)。

- 拖移超過約 **3pt** 就要顯示 drag image（半透明）；有效 drop target 顯示插入點或高亮、不可放置時不顯示或顯示禁止符號；失敗時回到原位或淡出。
- 容器可捲動時，拖到邊緣要自動捲動。
- 同容器放下為 move，跨容器為 copy。
- **"Prefer letting people undo a drag-and-drop operation"**，不能復原的放置則先確認。
- 提供**替代方式**完成拖放（menu 命令、accessibility API）。
- 自訂手勢只在必要時，且不得是完成重要動作的唯一方式；避免與系統手勢衝突。

## 9. Motion 與 Reduce Motion、Haptics

來源：[Motion](https://developer.apple.com/design/human-interface-guidelines/motion)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)。

- Motion 要有目的、可關閉（"Make motion optional"）、不要擋住操作、避免在高頻互動上加動畫。
- **Reduce Motion 開啟時**（Accessibility）：減少自動／重複動畫，包含縮放與周邊動態；具體做法：**收緊彈簧以減少彈跳、讓動畫直接跟隨手勢、避免動畫化 z 軸深度變化、把 x／y／z 軸轉場換成淡入淡出、避免動畫進出 blur**。
- 最後一點與玻璃直接相關：Tripline 的 menu／sheet 進出場若涉及 blur 漸變，Reduce Motion 下宜改為不含 blur 動畫的淡入淡出。DESIGN.md §11 只寫「取消 route 進出位移、吸附彈性、裝飾縮放與伸縮」，**未提 blur 轉場**，是可補的缺口（建議，非已查得的 bug）。
- Haptics：依文件定義的語意使用系統 pattern；一致、短促、搭配視覺回饋；避免濫用；**讓人可關閉**（"Make haptics optional"）。DESIGN.md §17 的「只用於 tab／Day 選取、拖拉關鍵點…」符合克制原則，但目前文件未提供關閉選項（系統層級的 System Haptics 設定會生效，HIG 此條的重點是 app 內是否另提供）。

## 10. 顏色、Dark Mode、SF Symbols、文案、載入、權限、帳號

### 10.1 Color 與 Dark Mode

來源：[Color](https://developer.apple.com/design/human-interface-guidelines/color)、[Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)。

- 用系統色與動態系統色；**"Avoid hard-coding system color values"**——文件中的色值僅供設計參考，實際值可能隨版本改變。
- 不要重新定義動態系統色的語意（例：不要把某個背景色當文字色）。
- iOS 背景有兩組：system 與 grouped，各含 primary／secondary／tertiary；**grouped table 用 grouped 組，否則用 system 組**；primary 給整體畫面、secondary 給群組、tertiary 給群組內的群組。前景用 label／secondary／tertiary／quaternary、placeholder、separator／opaque separator、link。
- 不要只靠顏色傳達資訊（紅綠、藍橘對色盲尤難）；也要留意顏色的文化意涵。
- **Dark Mode：「Avoid offering an app-specific appearance setting」**——理由是使用者得多調一處，且可能以為 app 壞了；也要在 Auto 外觀於執行中切換時正確。僅在沉浸式媒體等少數情況可考慮只用深色。
- Dark Mode 下增加對比 + 降低透明度的組合要實測，可能出現深字壓深底。
- 內容圖若白底，考慮略為調暗避免在深色環境中發光。

### 10.2 SF Symbols

來源：[SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)。

- 四種 rendering mode：monochrome、hierarchical、palette、multicolor；用系統色以自動適應無障礙與外觀。
- 自訂 symbol 要與系統符號一致的細節、字重、對位；為自訂 symbol 提供替代文字（VoiceOver）。
- 授權：下載 SF Symbols app 時需理解其條款，**禁止把符號（或易混淆的相似圖）用於 app icon、logo 或其他商標用途**；不可複製 Apple 產品圖樣，也不可客製 SF Symbols 標示為 Apple 功能／產品的符號。**本頁未討論非 Apple 平台的使用授權**（見待查項）。

### 10.3 文案

來源：[Writing](https://developer.apple.com/design/human-interface-guidelines/writing)。

- 清楚、簡潔、為所有人而寫；按鈕與連結幾乎都用動詞；用詞要一致。
- 少用所有格（"Favorites" 優於 "Your Favorites"）；用了就全 app 一致。
- 空狀態給清楚的下一步；錯誤訊息貼近問題、不責怪使用者、說明能做什麼；設定項目說明「開啟時會做什麼」。
- 選擇對的傳達管道（依緊急與重要程度）。

### 10.4 載入、進度、離線

來源：[Loading](https://developer.apple.com/design/human-interface-guidelines/loading)、[Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators)、[Launching](https://developer.apple.com/design/human-interface-guidelines/launching)。

- "Show something as soon as possible"；載入中可做別的事；超過一兩秒才用 progress indicator；可知時長用 determinate，否則 indeterminate。
- 進度指示器要持續轉動（停住會被當成當機）；不要在圓形與長條樣式間切換；位置要一致；背景作業或空間有限用 spinner；spinner 通常不加標籤。
- 取消會損失進度時，提供確認或繼續的選項。
- iOS 的 Button 可顯示 activity indicator 並更換標籤（"Checkout" → "Checking out…"）（[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)）。
- Launching：**還原先前狀態**讓人從上次離開處繼續；啟動畫面不放文字、不做品牌宣傳。
- 注意：HIG 沒有名為 "Offline" 的獨立頁（該 slug 回 404）；離線相關規則散在 Alerts（啟動時有問題顯示快取＋不干擾標示）、Feedback（說明無法執行的原因）與 Loading。

### 10.5 隱私與帳號

來源：[Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)、[Managing accounts](https://developer.apple.com/design/human-interface-guidelines/managing-accounts)。

- 只索取必要資料；"wait to request permission until people actually use an app feature that requires access"；啟動時除非功能明顯需要否則不要請求（導航 app 要定位是例外）；purpose string 寫成簡短完整的主動句，說明用途。
- 帳號：只在核心功能需要時才要求；說明好處；**盡量延後登入**；沒用 Sign in with Apple 時偏好 **passkey**；認證方式的按鈕要明說（"Sign In with Face ID"）；避免做 app 內的生物辨識開關（系統層級已設定）；避免用 "passcode" 指帳號密碼。
- 建立帳號就必須能刪除帳號（不只停用）；無法在 app 內完成時需直接連到網頁；用 Sign in with Apple 建立的帳號刪除時要撤銷 token；告知刪除何時完成並在完成時通知。

## 11. HIG 原文與 Tripline 決策的張力點

以下是**本次閱讀原文後發現、先前文件沒有逐項點出**的張力。每一項都是 Tripline 明文的產品決策，本文不主張改，只提供原文依據讓決策者知情；若決策被質疑，可引用此處。

| # | Tripline 現行決策 | HIG 原文 | 評估 |
|---|---|---|---|
| 1 | Account 提供「跟隨系統／淺色／深色」外觀設定，登出不清除（DESIGN.md §5） | Dark Mode：「Avoid offering an app-specific appearance setting」，理由是增加使用者負擔、可能被誤認為 app 壞掉 | 原文是 "avoid"（建議）而非禁止。預設跟隨系統已緩解多數風險；DESIGN.md 把它歸為 Tripline 決策是正確分類，但**不能在文件中同時宣稱這是 HIG 慣例** |
| 2 | 全 App 不使用 Large Title（DESIGN.md §4.1） | Toolbars（iOS）：用 large title 協助定向 | 先前文件已記錄。補充：原文為 "use"，不是 must；目前行程選擇器作為 inline title 的設計與 Large Title 互斥 |
| 3 | 「完成／取消／儲存」一律文字按鈕；DESIGN.md §4.1 標為 **HIG 必須** | Toolbars：標準 Back／Close 用符號，**不要用寫 "Back"／"Close" 的文字標籤**；Sheets：只規定 Cancel 在 leading、Done 在 trailing，沒規定一定要文字；Toolbars 又說「優先符號，除非像 edit 這類符號難表達的動作」 | **「HIG 必須：用文字」不是原文**；原文對 Cancel／Done 的形式沒有硬性規定，對 Back／Close 反而偏好符號。建議把該條的標記從「HIG 必須」改為「Tripline 決策」。先前文件第 51 行已提出類似提醒，此處補上 Sheets 頁（2026-03-24）也未規定文字的事實 |
| 4 | 一般動作選單項目「停用原因」（DESIGN.md §4.1、先前文件的「選單」列） | 一般 Menu：不可用項目**顯示並變暗**；Context menu：**隱藏**不可用項目 | Tripline 的「⋯」與長按共用同一份選單（§4.1 決策）。原文把兩種選單給了相反建議；Tripline 採單一做法時需擇一，建議在文件寫明選的是哪一邊與理由 |
| 5 | 所有刪除永久、不提供 Undo（ADR-0008、DESIGN.md §12） | Alerts／Feedback：對**可復原**的常見動作別跳 alert；對「uncommon destructive action that they can't undo」則**應該**跳 alert。Drag and drop：偏好可復原 | Tripline 的做法與原文一致：不可復原 ⇒ 有確認。唯一的張力是 drag-and-drop 的「偏好可 undo」，目前以「失敗完整還原＋替代 action」處理，屬合理折衷 |

另外兩個**無張力但值得標示**的對齊點：

- DESIGN.md §4.1 的「三格快捷＋清單」符合 Menus 的 **Medium** 版面（上方一排三項、符號在上短標籤在下），且 HIG 也允許 Small（四項純符號）。「破壞性獨立成組置尾端」符合 Context menus「破壞性項目放最後並標示 destructive」。
- DESIGN.md §6 的「placeholder 明確描述範圍、clear button、輸入即更新」符合 Search fields 與 Text fields。

## 12. 對 Flutter 實作的具體對照（僅依 repo 讀到的內容）

- **文字縮放測試矩陣**：DESIGN.md §19.1 以 2× 為準；依 §2 的表，2× 約等於 AX2。若要宣稱支援「全部 Accessibility Sizes」，應補測到 AX5（Body 53pt）。這是測試設計建議，不是已查得的缺陷。
- **44pt 的表述**：§3 說明 44pt 為預設值而非最小值；DESIGN.md 現行寫法「至少 44×44pt」是更嚴的內部 gate，沒有問題，但引用時請標示 Tripline gate。
- **Reduce Motion 與 blur**：HIG 明列「避免動畫進出 blur」；DESIGN.md §11、§17 的 Reduce Motion 清單未提 blur 轉場，可在驗收（§19.2 的 Reduce Motion 一項）加註檢查玻璃/blur 進出場。
- **標示 DESIGN.md §4.1 第 75 行**：「`完成`、`取消`、`儲存`等動作用文字按鈕」標為 **HIG 必須**，與 §11 第 3 項不符；不改 code，只建議之後調整標記。
- **Dark Mode 設定**：DESIGN.md §5 已標為 Tripline 決策，與 §11 第 1 項一致；先前文件第 52 行對「Android 跟隨 iOS」的處理也同樣獨立，未受影響。
- **離線文案**：HIG 沒有 Offline 專頁，CONTEXT.md「線上限定」要求「離線時必須說明原因」與 Feedback 頁「Show people when a command can't be carried out and help them understand why」一致。
- **啟動還原**：Launching 要求還原上次狀態；DESIGN.md §3.1 要求各 tab 保留 Navigation Stack、Day、篩選與捲動位置，**範圍限於 app 存活期間的 tab 切換**；本次未在 DESIGN.md 找到「程序被系統回收後冷啟動還原」的條文。這是否已實作需另查程式碼，本研究不下結論。

## 13. 未能確認／待查項

1. **navigation-bars 頁**：`.../human-interface-guidelines/navigation-bars.json` 回 HTTP 404，現行 HIG 已併入 Toolbars；因此無法引用獨立的 navigation bar 規範，也**未取得**標準 navigation bar 高度（常見的 44pt／large title 96pt 等）——HIG 文字內沒有，不採二手數字。
2. **Offline／Notifications 頁**：`offline` 同樣 404；未檢視 Notifications、Onboarding 的 iOS 細節。
3. **tab bar 的 iOS 高度**：Tab bars 頁只有 tvOS 的 68pt／46pt；iOS 數值在 HIG 文字內查無，需以 Xcode／真機量測，不能引用 HIG。
4. **safe area 數值、Dynamic Island 尺寸**：Layout 頁的裝置規格表在 JSON 中為連結資源（Apple 另提供 Device Hub／規格頁），本次抽出的文字未含數值；未驗證。
5. **Menus 的 small／medium 版面是否能在 Flutter 的 `GlassMenu` 以原生語意呈現**：這是實作問題，HIG 只定義外觀，需對照套件與真機。
6. **SF Symbols 在 Android 的使用授權**：SF Symbols 頁僅說明需遵守其條款與商標限制，未討論跨平台散布；先前文件已列同一待查項，本次一手來源仍無法回答，需讀 SF Symbols 授權條款全文。
7. **HIG 頁面的圖像內容**：圖說與 Figma 規格圖不在 JSON 文字內（表格與段落可抽出，插圖無法）；若有只在圖中呈現的數值（例如特定 spacing），本次未涵蓋。
8. **冷啟動狀態還原的實作狀況**：見 §12 最後一項，未讀程式碼驗證。
9. 所有「評估」「建議」欄為研究者依一手原文與 repo 文件做的推論，**不是已查得的實作 bug**；逐頁缺陷判定仍須合併程式碼與畫面證據。

本次僅新增本研究文件，未修改 production、DESIGN.md、ADR 或其他檔案，未 commit。
