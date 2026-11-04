# iOS App 與 web 畫面逐項比對 Apple HIG 檢查表

研究日期：2026-11-04（Asia/Taipei）。目的：提供「逐畫面比對」時可直接勾選的條目，每條標明原文依據、能否量化成自動檢查。本文件是研究，不判定現有程式違規，也不改任何規範。

## 方法與限制

**取得原文的方式**

- HIG 網頁正文由 JavaScript 算圖，WebFetch 只拿得到標題。改用 DocC JSON：`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`（路徑沒有 `documentation/`），用腳本從 `primaryContentSections` 取出 `paragraph`、`heading`、`unorderedList`、`table` 節點的文字，再逐條閱讀。
- 下表「來源 URL」欄寫的是人可閱讀的頁面 `https://developer.apple.com/design/human-interface-guidelines/<slug>`；同 slug 的 JSON 端點是實際取文字的地方。**兩種網址都實際 curl 過，皆回 200**（2026-11-04）。
- web 面向取自 W3C 原文：WCAG 2.2 Recommendation（`https://www.w3.org/TR/WCAG22/`，以 `#<success-criterion-id>` 指到條文，條文文字已逐條自 HTML 取出核對）與 WAI-ARIA APG（dialog-modal、alertdialog、button、keyboard-interface 四頁，皆 200）。
- 數字與文字以抓取當日的頁面為準；HIG 會持續改版，引用時請複查。

**限制（必讀）**

1. **HIG 只談 Apple 平台，不談 web。** web 條目的依據是 WCAG 2.2 與 APG，不是 HIG。HIG 的單位是 pt，WCAG 的單位是 CSS px，本表不做換算；web 若套用 44 這類 HIG 數值，是專案自訂標準，要如此標註。
2. **HIG 多數用語是建議（"consider／prefer／avoid"）**，只有少數數值（44、28、17、11、4.5:1 等）可轉成自動檢查。標「不可」的條目只能靠人工審視或截圖比對。
3. **找不到一手來源的項目**（`navigation-bars`、`passwords`、`empty-states`、`error-handling` 四個 slug 的 JSON 皆 404；`navigation-and-search` 只是一頁索引，沒有條文）已在表中明確標「無一手來源」，不以部落格或二手整理代替。
4. HIG 的 **Focus 頁明寫 iOS 不支援 focus system**（僅 iPadOS／tvOS／macOS），iPhone App 的「焦點」沒有一手規範可比對，詳見條目 F1。
5. 引用保持簡短改寫，單處原文引用不超過 15 個英文字；要看完整語境請開來源頁。

**與既有研究 `docs/research/2026-10-09-apple-hig-app-guidelines.md` 的關係**

本文重新取原文核對後才寫入，**未沿用該文無註明來源的結論**。重新核對的重點數值（44／28 pt、17／11 pt、12／24 pt padding、4.5:1／3:1、Dark Mode 4.5:1／7:1、Toolbar 標題 15 字元、Sheet 按鈕位置、Alert 規則、Reduce Motion 避免 blur）與原文一致，未發現矛盾。補充兩點該文未寫、對本專案有影響的原文：

- Managing accounts 頁建議**避免在 App 內提供「開啟生物辨識」的設定**，也建議避免用 "passcode" 稱呼帳號驗證（條目 T6）。這與本專案設定頁的 biometric 開關有張力，需決策者知情，本文不下結論。
- Motion 頁本身**沒有出現 Reduce Motion 字樣**；Reduce Motion 的具體要求在 Accessibility 頁（條目 M1）。

## 檢查表

欄位：條目名稱｜HIG（或 W3C）原文要點｜一手來源 URL｜可否量化｜量化規則｜適用。

來源 URL 的 `HIG/` 是 `https://developer.apple.com/design/human-interface-guidelines/` 的縮寫，**每個 URL 都是完整網址，縮寫只為版面**；下方「來源 URL 對照」列出展開後的全部網址。

### A. 觸控目標與間距

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| A1 | iOS 控制項預設／最小尺寸 | Accessibility 頁表列 iOS／iPadOS 預設 44x44 pt、最小 28x28 pt；要求力求達到各平台建議的最小尺寸 | HIG/accessibility | 可 | 可點擊元素最短邊 ≥ 44 pt（預設）；任何情況不得 < 28 pt | App |
| A2 | Button hit region | Buttons 頁：一般而言 hit region 至少 44x44 pt（visionOS 為 60x60），指尖、指標、視線皆然 | HIG/buttons | 可 | 按鈕 hit region 寬、高 ≥ 44 pt（視覺大小可較小，命中區要補足） | App |
| A3 | 控制項間距 | 間距與尺寸同樣重要；有 bezel 的元素周圍約 12 pt，沒有 bezel 的約 24 pt（用語是 "works well"，屬建議值） | HIG/accessibility | 可（弱） | 相鄰可點元素間距：有邊框 ≈ 12 pt、無邊框 ≈ 24 pt；屬建議，建議只當警示不當失敗 | App |
| A4 | 手勢需有替代操作 | 核心功能要能用多於一種方式操作；例如滑動關閉 view 時也要提供按鈕；高頻互動用最簡單手勢 | HIG/accessibility | 不可 | 逐畫面列出所有僅靠手勢的動作（滑動刪除、長按、拖曳），確認有按鈕或選單等價路徑 | 兩者（web 見 WCAG 2.5.7，條目 A6） |
| A5 | web 目標尺寸（最小） | WCAG 2.5.8（AA）：指標目標至少 24x24 CSS px；例外含間距、同頁等價控制、行內文字、user agent 控制、essential | WCAG22#target-size-minimum | 可 | 互動元素 bounding box 寬、高 ≥ 24 CSS px，或以 24 px 直徑圓置中後不與其他目標的圓相交 | web |
| A6 | web 目標尺寸（加強）與拖曳替代 | WCAG 2.5.5（AAA）：目標至少 44x44 CSS px，行內文字等有例外；2.5.7（AA）：拖曳功能須有單指標非拖曳替代 | WCAG22#target-size-enhanced、WCAG22#dragging-movements | 可（2.5.5）／不可（2.5.7） | 2.5.5：互動元素 ≥ 44x44 CSS px（AAA，非必要；與 iOS 對齊時屬專案自訂標準）；2.5.7：逐一檢查拖曳排序是否有按鈕替代 | web |

### B. 字級與 Dynamic Type

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| B1 | 預設與最小字級 | Typography 頁表列 iOS／iPadOS 預設 17 pt、最小 11 pt；自訂字體與系統字體皆適用 | HIG/typography | 可 | 任何顯示文字字級 ≥ 11 pt；本文正文預設 17 pt（使用 text style 時由系統給定） | App |
| B2 | Dynamic Type 與放大 200% | Accessibility 頁：理想上讓人把文字或圖示放大至少 200%，可用自訂 UI 或 Dynamic Type | HIG/accessibility | 可 | 以 textScaler 2.0（與系統最大 Accessibility 級距）逐畫面截圖，內容不得遺失、操作不得失效 | App |
| B3 | 大字級下的版面 | Typography 頁：盡量減少截斷；捲動區避免截斷，除非可開另一頁看全文；水平受限時改堆疊；要實機開 Larger Accessibility Text Sizes 驗證 | HIG/typography | 不可（部分可：以測試找 overflow 與 ellipsis） | 大字級下 widget test 不得出現 RenderFlex overflow；截斷處人工確認有「看全文」路徑 | App |
| B4 | 重要內容優先 | 放大時不必每個字都變大（例如 tab 標題不必跟著放大），要維持文字層級的相對階層 | HIG/typography | 不可 | 人工審視：放大後標題、內文、輔助字級的相對關係仍成立 | App |
| B5 | 避免細字重 | 使用系統字體時偏好 Regular、Medium、Semibold、Bold，避免 Ultralight、Thin、Light | HIG/typography | 可 | 搜尋字重：不得出現 w100、w200、w300（FontWeight.w100 至 w300） | App |
| B6 | 自訂字體須支援輔助功能 | 自訂字體要實作與系統字體相同的 Dynamic Type 與 Bold Text 行為 | HIG/typography | 不可 | 人工：開啟 Bold Text 與大字級確認自訂字體有回應 | App |
| B7 | web 文字縮放與重排 | WCAG 1.4.4（AA）：不靠輔助技術可放大至 200% 而不失內容與功能；1.4.10（AA）：320 CSS px 寬不需雙向捲動；1.4.12（AA）：行高 1.5、段後 2、字距 0.12、詞距 0.16（倍字級）覆寫後不失內容 | WCAG22#resize-text、WCAG22#reflow、WCAG22#text-spacing | 可 | 瀏覽器 200% 縮放與 320 px 視窗截圖檢查無遺失；以覆寫 CSS 注入上述四個值後檢查無裁切、無重疊 | web |

### C. 對比

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| C1 | 文字對比（Accessibility 表） | 以 WCAG AA 為依據：至多 17 pt 的文字 4.5:1；18 pt 為 3:1；粗體 3:1 | HIG/accessibility | 可 | 前景／背景對比 ≥ 4.5:1（≤ 17 pt）；≥ 3:1（18 pt 或粗體）；亮、暗兩種外觀都要算 | App |
| C2 | Dark Mode 對比 | Dark Mode 頁：任何外觀下最低不低於 4.5:1；自訂前景背景力求 7:1，尤其小字 | HIG/dark-mode | 可 | 自訂色對比 ≥ 4.5:1（硬門檻）、小字 ≥ 7:1（目標） | App |
| C3 | Increase Contrast | 若預設對比不足，至少在系統開啟 Increase Contrast 時提供更高對比方案；偏好系統色以自動取得無障礙變體 | HIG/accessibility | 部分可 | 預設色達 C1；Increase Contrast 開啟後截圖比對，人工確認有更高對比 | App |
| C4 | 別讓色彩成為唯一線索 | Color 頁：避免讓人難以辨識內容的配色，色盲使用者可能分不出某些組合 | HIG/color | 不可 | 人工：狀態（錯誤、已選、已完成）除色彩外要有文字或圖示 | App |
| C5 | web 文字對比 | WCAG 1.4.3（AA）：文字 4.5:1；大字 3:1；停用元件、純裝飾、logo 無要求 | WCAG22#contrast-minimum | 可 | 正文 ≥ 4.5:1，大字（≥ 18 pt 或 14 pt 粗體，定義見原文 large scale）≥ 3:1 | web |
| C6 | web 非文字對比與色彩 | WCAG 1.4.11（AA）：識別 UI 元件與狀態所需的視覺資訊對相鄰色 ≥ 3:1；1.4.1（A）：色彩不可是唯一視覺手段 | WCAG22#non-text-contrast、WCAG22#use-of-color | 可（1.4.11）／不可（1.4.1） | 1.4.11：輸入框邊框、圖示、focus 指示對相鄰色 ≥ 3:1；1.4.1 人工審視 | web |

### D. 導覽列、標題、Sheet 與主要動作位置

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| D1 | 導覽列的歸屬 | Toolbars 頁寫明 iOS 的 navigation-specific toolbar 有時稱 navigation bar；`navigation-bars` 不再是獨立頁 | HIG/toolbars | 不可 | 無獨立 navigation bar 頁；`navigation-bars` slug 無一手來源（404），以 Toolbars 頁為準 | App |
| D2 | 標題簡潔、不用 App 名稱 | 為每個 view 提供有用標題；不要用 app 名稱當標題；標題少於 15 個字元；標題多餘時可留空 | HIG/toolbars | 可 | 標題長度 < 15 字元（原文以 characters 計，是否把中文字逐字計入原文未說明，建議以字元數檢查並人工複核）；標題 ≠ App 名稱 | App |
| D3 | Back／Close 用標準符號 | 用標準 Back 與 Close；偏好標準符號，不要用寫著 Back 或 Close 的文字標籤；自訂版本外觀與行為須一致 | HIG/toolbars | 可 | 搜尋導覽列 leading 的文字按鈕，標籤不得為「返回」「關閉」「Back」「Close」 | App |
| D4 | Toolbar 主要動作 | 用 .prominent 樣式標示 Done 或 Submit 等關鍵動作；只指定一個主要動作，放 toolbar trailing 側 | HIG/toolbars | 可 | 每個 toolbar 至多 1 個 prominent 動作，且位於 trailing | App |
| D5 | Toolbar 動作以符號為先 | 偏好簡單易辨識的符號，edit 等難以用符號表達的動作例外；符號不需自加邊框 | HIG/toolbars | 不可 | 人工審視：符號含義清楚；文字動作與符號動作要分開並留間距 | App |
| D6 | Large title | 用 large title 協助定位，捲動時轉為標準標題 | HIG/toolbars | 不可 | 屬 "use"，非強制；與專案決策是否使用 large title 對照即可 | App |
| D7 | Toolbar 項目與 More menu | 不要過度擁擠；盡量把動作放進 toolbar，真的需要才加 More menu；不要手動加 overflow menu | HIG/toolbars | 部分可 | toolbar 的項目群組（group）數 ≤ 3（原文 aim for a maximum of three，單位是 group，不是按鈕數） | App |
| D8 | Sheet 的 Cancel／Done 位置 | iOS 單頁 sheet：Cancel 在頂部 toolbar 的 leading 側，Done 在 trailing 側；多步驟 sheet 各步驟位置可不同 | HIG/sheets | 可 | 單頁 sheet：取消在左上、完成在右上（RTL 相反） | App |
| D9 | Done 要配 Cancel 或 Back | 提供 Done 就要配 Cancel 或 Back；避免三者同時出現；Back 用於多步驟、不用來關閉 sheet | HIG/sheets | 可 | 單一 sheet 內同時出現的 {取消, 完成, 返回} ≤ 2 種；有「完成」必有「取消」或「返回」 | App |
| D10 | Sheet 下滑關閉與未存變更 | 支援向下滑動關閉；若有未存變更，用 action sheet 讓人確認 | HIG/sheets | 部分可 | 有未存變更時下滑關閉須觸發確認（可寫 widget test 驗證） | App |
| D11 | Sheet 與 resizable、grabber | 可調整高度的 sheet 要有 grabber，可點擊循環 detent 並與 VoiceOver 搭配；系統 detent 為 large 與 medium | HIG/sheets | 部分可 | 有 medium detent 的 sheet 必有 grabber；檢查 semantics 有對應動作 | App |
| D12 | Modal 要有標題與明確關閉方式 | Modality 頁：提供標題或文字說明 modal 的任務；一定要給明顯的關閉方式；iOS 慣例是頂部 toolbar 按鈕或下滑；一次只顯示一個 modal | HIG/modality | 部分可 | 每個 modal 有非空標題、有可見的關閉或取消控制 | App |
| D13 | Modal 不要變成 App 中的 App | 少用 modality；modal 內若有子 view，給單一路徑並避免會被當成關閉鈕的按鈕 | HIG/modality | 不可 | 人工審視 modal 內的層級深度 | App |
| D14 | Navigation and search 概念頁 | `navigation-and-search` 頁只是元件索引（連到 search fields、sidebars、tab bars 等），沒有條文 | 無一手來源（頁面存在但無規範內容） | 不可 | 不適用；實際規範見 Toolbars、Tab bars、Search fields 各頁 | App |
| D15 | Tab bar 不要停用或隱藏 | Tab bars 頁：不要停用或隱藏 tab bar 按鈕，即使內容暫時不可用；區段為空時說明原因 | HIG/tab-bars | 可（部分） | 各 tab 恆為可點狀態；空內容畫面須有說明文字 | App |
| D16 | web 對話框導覽與鍵盤 | APG modal dialog：開啟時焦點移入對話框；Tab 與 Shift+Tab 在對話框內循環；Escape 關閉；關閉時焦點回到觸發元素；應有名稱（aria-labelledby 指向可見標題）；強烈建議有可見的關閉按鈕 | APG/dialog-modal | 可 | 自動化：開啟後 document.activeElement 在對話框內；Tab 循環不外溢；Esc 關閉；關閉後焦點回觸發元素；有 role=dialog、aria-modal、可存取名稱 | web |

### E. 按鈕

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| E1 | 自訂按鈕要有 press state | 自訂 button 一律要有 press state，否則會覺得沒反應 | HIG/buttons | 部分可 | 自訂可點元件須有 pressed 視覺回饋（用 InkWell／GestureDetector 時檢查是否有對應狀態） | App |
| E2 | 用 style 而非 size 區分主要選項 | 同組選項尺寸一致，用樣式（prominent 等）區分偏好項；prominent 按鈕每個 view 一到兩個 | HIG/buttons | 部分可 | 同組並列按鈕高度一致；每個 view 的 prominent 按鈕 ≤ 2 個（原文：一到兩個） | App |
| E3 | 主要角色不給破壞性動作 | 把 primary 角色給使用者最可能選的非破壞性按鈕；不要把 primary 給破壞性動作，即使它最可能被選 | HIG/buttons | 部分可 | 破壞性按鈕（刪除、清除）不得是預設或 prominent 樣式 | App |
| E4 | 標籤清楚、動詞開頭 | 圖示要對應熟悉的動作；用文字時以動詞開頭，用幾個字描述動作 | HIG/buttons | 不可 | 人工審視按鈕文案 | App |
| E5 | web 按鈕鍵盤操作 | APG button：Space 與 Enter 皆可啟動；元素需有 role=button（或用原生 button） | APG/button | 可 | 以 Tab 聚焦後，Space 與 Enter 都能觸發；自訂元素有 role=button 與 tabindex | web |

### F. 文字輸入、密碼與 Autofill

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| F1 | 欄位提示與獨立標籤 | Text fields 頁：可用 placeholder 說明用途；因 placeholder 輸入後消失，宜另有獨立標籤提醒 | HIG/text-fields | 部分可 | 每個輸入欄位必有常駐標籤（不可只靠 placeholder） | 兩者（web 見 WCAG 3.3.2，條目 F8） |
| F2 | 敏感資料用 secure 欄位 | 密碼等敏感資料一律用 secure text field | HIG/text-fields | 可 | 密碼欄位 obscureText=true（web：type=password） | 兩者 |
| F3 | 絕不預填密碼欄位 | Entering data 頁：不要預先填入密碼欄位；要求輸入或用生物辨識、keychain 驗證 | HIG/entering-data | 可 | 密碼欄位 controller 初始值為空 | App |
| F4 | 驗證時機 | Text fields 頁：視情境驗證；輸入 email 在切換欄位時驗證，建立使用者名稱或密碼則須在離開欄位前驗證；Entering data 頁：能即時驗證就即時回饋 | HIG/text-fields、HIG/entering-data | 部分可 | 可寫行為測試：email 欄 blur 後出現錯誤；密碼規則在輸入過程中提示 | App |
| F5 | 必填未完成時主要動作停用 | Entering data 頁：要讓人知道必須提供必要資料才能繼續；若有 Next 或 Continue，等必要資料齊備才可用 | HIG/entering-data | 可 | 必填未填齊時主要按鈕 onPressed 為 null（停用） | App |
| F6 | 鍵盤類型與 Clear 鈕 | 顯示符合內容的鍵盤類型（數字、URL 等）；iOS 欄位 trailing 端宜有 Clear 按鈕 | HIG/text-fields | 可 | email 欄 keyboardType=emailAddress、數字欄 number 等；單行欄位 trailing 有清除鈕（屬建議） | App |
| F7 | 帳號與生物辨識（含與專案張力） | Managing accounts 頁：避免在 App 內提供「開啟生物辨識」設定（系統層已設定）；驗證方式要明說（如「用 Face ID 登入」而非泛稱）；避免用 "passcode" 稱呼帳號驗證；不用 Sign in with Apple 時偏好 passkey；有建立帳號就必須能刪除帳號 | HIG/managing-accounts | 部分可 | 搜尋文案是否含 "passcode"（Apple 明示避免用於帳號驗證）；其餘人工審視。本專案設定頁有 biometric 開關，與此建議有張力，需決策 | App |
| F8 | 密碼與 Autofill 專頁 | `passwords` slug 的 JSON 回 404。HIG 對 Autofill 的僅有內容是 Managing accounts 頁一句：透過 iCloud 同步讓人用 Keychain 自動填入使用者名稱與密碼 | 無一手來源（專頁不存在；僅 HIG/managing-accounts 一句） | 不可 | 不下量化規則；Apple 平台的 autofill 屬 API（textContentType／AutofillHints）層，HIG 無規範可比對 | App |
| F9 | web 標籤與輸入目的 | WCAG 3.3.2（A）：需要輸入時提供標籤或說明；1.3.5（AA）：收集使用者資料的欄位可程式化判定用途（autocomplete）；3.3.8（AA）：驗證流程不得要求認知功能測試（如記密碼），除非有替代方式或輔助機制 | WCAG22#labels-or-instructions、WCAG22#identify-input-purpose、WCAG22#accessible-authentication-minimum | 可 | 每個 input 有 label；帳號、密碼、email 欄有正確 autocomplete 值（username、current-password、new-password、email）；密碼欄不阻擋貼上與密碼管理員 | web |

### G. Alerts、錯誤、空狀態與載入

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| G1 | Alert 慎用 | 只為提供資訊不要用 alert；常見且可復原的破壞性動作不需 alert；App 啟動時避免跳 alert（如無網路改以其他方式提示） | HIG/alerts | 部分可 | 啟動流程不得顯示 alert（可 widget test 驗證）；純資訊訊息改用內嵌提示 | App |
| G2 | Alert 結構 | 標題、可選說明文字、最多三個按鈕；標題要具體描述發生什麼事，不要寫成無資訊的 "Error" 類標題 | HIG/alerts | 可 | 按鈕數 ≤ 3；標題非空且不是單純「錯誤」 | App |
| G3 | Alert 按鈕 | 按鈕一到兩個字、以動詞為主；純資訊 alert 才可用 OK，避免 Yes／No；預設鈕在 trailing（堆疊時在最上方），Cancel 在 leading（堆疊時在最下方）；取消鈕一律叫 "Cancel" | HIG/alerts | 可 | 按鈕標題長度 ≤ 2 詞（中文約 ≤ 4 字，為換算建議）；取消鈕文案固定為「取消」；順序符合上述 | App |
| G4 | Destructive 與 Cancel | 對「使用者並非刻意選擇」的破壞性動作用 destructive 樣式；刻意選的（如清空垃圾桶）確認鈕不用；有破壞性動作就要有 Cancel；Cancel 不要當預設鈕 | HIG/alerts | 部分可 | 有 destructive 按鈕的 alert 必含 Cancel；Cancel 非預設 | App |
| G5 | 預期之外的資料遺失才警告 | Feedback 頁：警告「非預期且不可復原」的資料遺失；資料遺失是預期結果時不要警告；成功預期的動作只在重要時確認 | HIG/feedback | 不可 | 逐一檢查每個刪除與覆寫流程：可復原的不跳 alert，不可復原且非預期的才跳 | App |
| G6 | 錯誤訊息要說明原因 | Feedback 頁：命令無法執行時，要顯示並讓人理解原因；回饋應同時用多種方式（色彩、文字、聲音、觸覺）以便 VoiceOver 等使用 | HIG/feedback | 不可 | 每種錯誤狀態有文字說明（不只顏色或圖示） | App |
| G7 | 狀態回饋就近呈現 | 狀態資訊整合在介面中、靠近所描述的項目，讓人不必離開情境就能得知（如郵件 toolbar 顯示更新時間） | HIG/feedback | 不可 | 人工審視：離線、同步中、失敗等狀態是否在相關畫面內就近顯示 | App |
| G8 | web 錯誤辨識與建議 | WCAG 3.3.1（A）：自動偵測到輸入錯誤時，標出出錯項目並以文字描述；3.3.3（AA）：已知修正建議時要提供；4.1.3（AA）：狀態訊息能透過 role 或屬性被輔助技術取得而不需取得焦點 | WCAG22#error-identification、WCAG22#error-suggestion、WCAG22#status-messages | 可 | 錯誤欄位有文字訊息並以 aria-describedby 或 aria-invalid 關聯；狀態訊息容器有 role=status／alert 或 aria-live | web |
| G9 | web alert dialog | APG alertdialog：用 role=alertdialog 讓輔助技術與瀏覽器區分警示對話框；須有名稱（aria-labelledby 或 aria-label），並用 aria-describedby 指向警示訊息 | APG/alertdialog | 可 | 確認用於警示的 modal 有 role=alertdialog、可存取名稱與 aria-describedby | web |
| G10 | 空狀態專頁 | `empty-states` 與 `error-handling` 兩個 slug 的 JSON 皆 404；HIG 沒有「空狀態」專頁。僅 Tab bars 頁一句：區段為空時說明為何沒有內容（見 D15） | 無一手來源 | 不可 | 不下量化規則；不得以「HIG 規定空狀態要有插圖與動作」這類說法作結論 | 兩者 |
| G11 | 載入：盡快顯示東西 | Loading 頁：盡早顯示內容，等載入時可用佔位文字或圖形，內容到了再取代；載入時讓人可做其他事 | HIG/loading | 不可 | 人工審視：載入中不得整頁空白；可用 skeleton 或快取先顯示 | 兩者 |
| G12 | 載入：進度指示 | 載入超過片刻要用進度指示器說明仍在進行；已知時長用 determinate，未知用 indeterminate（Progress indicators 頁） | HIG/loading、HIG/progress-indicators | 部分可 | 可量化的只有「有非同步載入就有進度指示」；「超過片刻」原文沒有秒數，無一手量化門檻 | 兩者（web 無一手規範，沿用概念） |

### H. 深色模式

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| H1 | 避免 App 內獨立外觀設定 | Dark Mode 頁：避免提供 app 專屬的外觀設定，會讓人多調一處設定，甚至以為 app 壞了；只有少數沉浸式媒體 app 才考慮固定深色 | HIG/dark-mode | 可 | 設定頁不得有獨立的淺色／深色切換（可搜尋）；若有，需記為專案決策並說明理由 | App |
| H2 | 兩種外觀都要好看 | 兩種外觀都要測；也要測 Auto 外觀運行中切換；測 Increase Contrast 與 Reduce Transparency（單獨與合併）下的可讀性 | HIG/dark-mode | 部分可 | 亮、暗各截圖一輪；執行中切換外觀不得出現殘留的錯誤色；對比用 C1、C2 的門檻 | 兩者 |
| H3 | 使用會隨外觀調整的色彩 | 用語意色或有亮暗兩版本的 color set；避免寫死的色值或不會隨外觀變化的顏色；背景用系統背景色（base 與 elevated 會自動切換） | HIG/dark-mode | 可 | 搜尋寫死的 Color(0x…) 且無暗色對應；背景是否取自主題 token | App |
| H4 | 圖片與圖示 | 全彩圖像在兩種外觀都要好看，必要時分別提供資產；白底內容圖可略為調暗避免在暗底發光 | HIG/dark-mode | 不可 | 人工審視：暗色下圖片與圖示邊緣可辨 | 兩者 |

### I. 動態與 Reduce Motion

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| I1 | Reduce Motion 的具體要求 | Accessibility 頁：系統開啟 Reduce Motion 時，要減少自動與重複的動畫（縮放、放大縮小、周邊動態）；做法含收緊彈簧以減少彈跳、讓動畫直接追隨手勢、避免動畫化 z 軸深度變化、避免動畫進出 blur | HIG/accessibility | 可 | 以 MediaQuery.disableAnimations 為真時：自訂動畫時長趨近 0 或改為淡入淡出；不得有彈簧回彈、縮放與 blur 轉場。可寫 widget test 驗證 | App |
| I2 | 動態要可選、非唯一溝通 | Motion 頁：動態要有目的；不要把動態當成傳達重要資訊的唯一方式，要搭配其他回饋；頻繁出現的 UI 互動盡量不加動態；盡量不讓人等動畫跑完才能操作 | HIG/motion | 部分可 | 人工審視；可量化的是動畫期間不得阻擋輸入，以及自訂動畫時長（原文無秒數，無一手門檻） | App |
| I3 | web 動態 | WCAG 2.2.2（A）：自動開始且超過 5 秒、與其他內容並行的移動、閃爍、捲動資訊，要有暫停、停止或隱藏機制；2.3.3（AAA）：互動觸發的動態可關閉。HIG 無 web 動態規範；`prefers-reduced-motion` 在 W3C WCAG 本文中未作為條文，故本文不引用 | WCAG22#pause-stop-hide、WCAG22#animation-from-interactions | 可（2.2.2 的 5 秒） | 自動動畫持續 > 5 秒者須有暫停或停止控制；2.3.3 為 AAA，屬加分項 | web |

### J. 焦點與鍵盤

| ID | 條目名稱 | 原文要點 | 來源 URL | 可否量化 | 量化規則 | 適用 |
|---|---|---|---|---|---|---|
| J1 | iOS 的 focus system | Focus and selection 頁：該 focus system 在 iOS 與 watchOS **不支援**；iPadOS、tvOS、macOS 才有。因此 iPhone App 的「焦點環」沒有 HIG 規範可比對 | HIG/focus-and-selection | 不可 | iPhone：無（不得以 focus ring 為 iPhone App 的檢查項）。iPad 外接鍵盤：須顯示焦點、不得無預警移動焦點 | App |
| J2 | 不要擅自改變焦點 | 不要在人沒有互動時改變焦點；用平台一致的方式呈現焦點；文字與搜尋欄偏好 focus ring，列表偏好整列高亮 | HIG/focus-and-selection | 不可 | 人工審視：非使用者觸發的畫面更新（輪詢、SWR 重繪）不得搶走焦點 | App（iPadOS 為主） |
| J3 | Full Keyboard Access | Keyboards 頁：盡可能支援 Full Keyboard Access（iOS、iPadOS、macOS、visionOS），用系統設定開啟後測試；iPadOS 對按鈕、分段控制、開關不要自行做鍵盤導覽，交給 Full Keyboard Access | HIG/keyboards | 不可 | 人工：外接鍵盤開啟 Full Keyboard Access 後，所有控制項可到達並可啟動 | App |
| J4 | 標準鍵盤快捷鍵 | 不要把標準快捷鍵挪作他用；自訂動作另設快捷鍵 | HIG/keyboards | 部分可 | 搜尋 Shortcuts 綁定，是否覆蓋 Cmd+C、V、Z 等標準鍵 | App（有硬體鍵盤時） |
| J5 | web 鍵盤操作 | WCAG 2.1.1（A）：所有功能可用鍵盤操作；2.1.2（A）：焦點可移進就必須能移出，且不得有鍵盤陷阱 | WCAG22#keyboard、WCAG22#no-keyboard-trap | 可 | 僅用 Tab、Shift+Tab、Enter、Space、方向鍵走完所有流程；任一元件不得讓 Tab 卡住 | web |
| J6 | web 焦點可見與不被遮 | WCAG 2.4.7（AA）：鍵盤焦點指示可見；2.4.11（AA）：取得焦點的元件不得被作者建立的內容完全遮住（例如固定頁首、固定底欄）；2.4.13（AAA）另有焦點外觀面積與對比要求 | WCAG22#focus-visible、WCAG22#focus-not-obscured-minimum | 可 | 逐一 Tab 並截圖，確認焦點外框可見；固定頁首與底欄下的元件被聚焦時須捲入可見區 | web |

## 來源 URL 對照

HIG（皆為頁面與同 slug JSON 兩種網址，2026-11-04 curl 皆 200）：

- `HIG/accessibility` = https://developer.apple.com/design/human-interface-guidelines/accessibility
- `HIG/typography` = https://developer.apple.com/design/human-interface-guidelines/typography
- `HIG/color` = https://developer.apple.com/design/human-interface-guidelines/color
- `HIG/buttons` = https://developer.apple.com/design/human-interface-guidelines/buttons
- `HIG/toolbars` = https://developer.apple.com/design/human-interface-guidelines/toolbars
- `HIG/sheets` = https://developer.apple.com/design/human-interface-guidelines/sheets
- `HIG/modality` = https://developer.apple.com/design/human-interface-guidelines/modality
- `HIG/tab-bars` = https://developer.apple.com/design/human-interface-guidelines/tab-bars
- `HIG/text-fields` = https://developer.apple.com/design/human-interface-guidelines/text-fields
- `HIG/entering-data` = https://developer.apple.com/design/human-interface-guidelines/entering-data
- `HIG/managing-accounts` = https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- `HIG/alerts` = https://developer.apple.com/design/human-interface-guidelines/alerts
- `HIG/feedback` = https://developer.apple.com/design/human-interface-guidelines/feedback
- `HIG/loading` = https://developer.apple.com/design/human-interface-guidelines/loading
- `HIG/progress-indicators` = https://developer.apple.com/design/human-interface-guidelines/progress-indicators
- `HIG/dark-mode` = https://developer.apple.com/design/human-interface-guidelines/dark-mode
- `HIG/motion` = https://developer.apple.com/design/human-interface-guidelines/motion
- `HIG/keyboards` = https://developer.apple.com/design/human-interface-guidelines/keyboards
- `HIG/focus-and-selection` = https://developer.apple.com/design/human-interface-guidelines/focus-and-selection
- 對應 JSON 端點：把上列 `design/human-interface-guidelines/<slug>` 換成 `tutorials/data/design/human-interface-guidelines/<slug>.json`

W3C（皆 200）：

- `WCAG22#<id>` = https://www.w3.org/TR/WCAG22/#`<id>`（id 即各條文的 anchor，例如 `#target-size-minimum`）；文件本體 https://www.w3.org/TR/WCAG22/
- `APG/dialog-modal` = https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- `APG/alertdialog` = https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- `APG/button` = https://www.w3.org/WAI/ARIA/apg/patterns/button/
- 備查（未被條目引用）：https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/

回 404 的 slug（已確認不存在，因此相關條目標「無一手來源」）：`navigation-bars`、`passwords`、`empty-states`、`error-handling`。
