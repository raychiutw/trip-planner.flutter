# Tripline Flutter iOS HIG 規範

> 狀態：Accepted
>
> 更新：2026-07-23
>
> 適用：iOS、Android、iPhone、iPad 與 Android tablet
> 決策背景：[ADR-0009 全平台採用 iOS HIG，導覽配置由可用寬度決定](docs/adr/0009-universal-ios-hig-width-driven-layout.md)

根目錄的 `/design.md` 是 Tripline App UI／UX 的規範來源。較早的設計 session、spec 與 plan 已隨舊工作流文件一併歸檔，只在 git history 保留決策脈絡；難以逆轉的決策另記於 [`docs/adr/`](docs/adr)。實作尚未完成的項目是 migration target，不得以現況反向修改本規範。

## 1. 規範標記

- **HIG 必須**：Tripline 將明確的平台慣例、系統設定與 accessibility 要求視為 release blocker。
- **HIG 建議**：Apple 建議且 Tripline 採用的預設；偏離時必須補一筆 Tripline 決策與理由。
- **Tripline 決策**：HIG 沒有指定唯一答案，由產品選定且必須維持一致的行為。

HIG 是設計指引，不是逐像素的認證規格。本文件使用「HIG 必須」代表 Tripline 的內部強制等級，不表示 Apple 原文全部使用 must。

## 2. 平台與相容基準

- **Tripline 決策**：iOS 與 Android 使用同一套 iOS 26 system-app 視覺與互動，不另外建立 Material 版本。
- **Tripline 決策**：最低 iOS 版本維持 16.0。iOS 16–25 與 Android 使用共用 Flutter 元件模擬 iOS 26 的層級、材質與降級行為。
- **HIG 必須**：layout 依 compact／regular width 自適應，不把 iPhone 畫面等比例拉寬成 tablet 畫面。
- **HIG 必須**：支援直向、橫向、safe area、鍵盤、pointer、外接鍵盤與 iPad multitasking。
- **HIG 必須**：使用系統字體、Dynamic Type、動態系統色與系統 accessibility 設定。

## 3. 頂層資訊架構

### 3.1 Root tabs

iPhone 固定四個 root tabs：

| 順序 | 標籤 | SF Symbol | Selected |
|---:|---|---|---|
| 1 | 聊天 | `bubble.left` | `bubble.left.fill` |
| 2 | 行程 | `suitcase` | `suitcase.fill` |
| 3 | 地圖 | `map` | `map.fill` |
| 4 | 收藏 | `heart` | `heart.fill` |

- **HIG 必須**：tab bar 只負責頂層導覽，不放搜尋、輸入、POI、建立或其他動作。
- **HIG 必須**：四個 tab 永遠存在，不因載入、空狀態、權限或目前頁面隱藏、停用或換位置。
- **HIG 必須**：使用單字 label 與 SF Symbols；selected 使用可用的 filled variant。
- **HIG 必須**：切換 tab 時保留各 branch 的 Navigation Stack、Day、篩選與捲動位置。
- **Tripline 決策**：再次點擊目前 tab 時，詳情頁回到該 branch 根畫面；已在根畫面時捲回頂端。不得清除搜尋條件或重新載入資料。
- **HIG 建議**：成功切換時使用輕量 selection haptic。

### 3.2 iPad 與 regular width

- **HIG 必須**：iPad／regular width 使用頂部 tab bar，並可轉換為 sidebar。
- **HIG 必須**：深層行程結構使用 split view；sidebar、內容清單與 detail 各自保留選取狀態。
- **Tripline 決策**：Android tablet 依相同 width 規則呈現 iPad 型態，而不是 Android navigation rail。
- **HIG 必須**：compact resize 時回到 iPhone tab bar，內容與選取不得遺失。

參考：[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)、[Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)。

## 4. Header 與 toolbar

### 4.1 共通結構

```text
[返回／取消]      [Inline Title]      [主要動作] […] [帳號]
```

- **Tripline 決策**：全 App 不使用 Large Title；標題一律 inline 呈現。標題由 `TpRootScaffold`／`TpAppBar` 自繪，不使用 `CupertinoNavigationBar`（見 [ADR-0001](docs/adr/0001-keep-liquid-glass-over-native-cupertino.md)）。
- **HIG 必須**：返回、關閉或取消位於 leading；頁面動作與帳號位於 trailing。
- **Tripline 決策**：每個 App 內容頁右上角固定顯示 `person.crop.circle`，不顯示照片、姓名縮寫或自訂頭像。
- **Tripline 決策**：Account sheet 本身、登入／註冊流程與系統 modal 不重複顯示帳號 icon。
- **HIG 必須**：帳號 icon 的可點區至少 44×44pt，VoiceOver label 為「帳號」。
- **Tripline 決策**：帳號左側最多直接顯示一個當頁主要動作；其他動作進入 system `…` menu。
- **HIG 必須**：`完成`、`取消`、`儲存`等動作用文字按鈕；只有語意明確的動作使用 SF Symbol。
- **HIG 必須**：disabled action 保留位置並降低強調，不造成 toolbar 跳動。
- **HIG 必須**：destructive action 使用 system destructive role，放在 menu 尾端或確認流程。

參考：[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)、[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)、[Menus](https://developer.apple.com/design/human-interface-guidelines/menus)。

### 4.2 目前行程選擇器

聊天、行程時間軸與地圖的 inline title 是「目前行程」選擇器：

```text
[目前行程名稱⌄]
```

- **Tripline 決策**：收藏、編輯、POI 詳情、表單與 Account sheet 使用自己的頁面標題，不顯示行程選擇器。
- **HIG 必須**：顯示目前行程名稱與 `chevron.down`，不加自訂背景；整體 tap target 至少 44pt。
- **Tripline 決策**：點擊後開啟 system selection sheet「切換行程」。目前行程以 checkmark 標示，選取後立即關閉。
- **HIG 建議**：行程清單較長時，selection sheet 提供搜尋；這是選擇器內搜尋，不是地圖或 Day 搜尋。
- **HIG 必須**：Header 可截斷過長名稱；selection sheet 顯示完整名稱。
- **HIG 必須**：VoiceOver 讀出「目前行程，{名稱}，按兩下切換行程」與 button／menu 語意。
- **Tripline 決策**：只有一個行程時隱藏 chevron 並停用切換；沒有行程時顯示「尚無行程」與建立入口。
- **Tripline 決策**：切換後維持目前 section。原 Day 在新行程存在時保留，否則選 Day 1；舊 POI 選取與 sheet 必須關閉。
- **Tripline 決策**：聊天草稿屬於行程；切換行程後保存舊草稿，切回時恢復，避免把內容送到錯誤行程。

## 5. Account 與 Settings

- **Tripline 決策**：Account 不是 root tab。每個內容頁的 `person.crop.circle` 開啟帶 Navigation Stack 的 Account sheet。
- **HIG 建議**：iPhone 使用可展開至全高的 system sheet；iPad 使用 form sheet 或 popover，空間不足時自適應為全高。
- **HIG 必須**：Account 使用 grouped list、inset separator、system controls 與標準 navigation。
- **HIG 必須**：一般、低頻設定集中在 Account；只影響目前任務的選項留在相關畫面。
- **HIG 必須**：不得重複實作系統已有的 Dynamic Type、accessibility、鍵盤、捲動或認證偏好。
- **Tripline 決策**：App appearance 跟隨系統；只有真正屬於 Tripline 的外觀選項才可留在 Account。
- **HIG 建議**：需要帳號時優先提供 Sign in with Apple，並清楚說明用途與權益。
- **HIG 必須**：關閉 Account sheet 後回到原頁，保留 Day、捲動位置、表單與未送出的聊天草稿。

參考：[Settings](https://developer.apple.com/design/human-interface-guidelines/settings)、[Managing accounts](https://developer.apple.com/design/human-interface-guidelines/managing-accounts)、[Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)。

## 6. Search

- **Tripline 決策**：行程列表與收藏列表使用內容頂部的 inline search field。
- **Tripline 決策**：地圖、Day／行程時間軸、聊天與 Account 不提供頁面搜尋。
- **Tripline 決策**：新增行程 POI 的 scoped task 可保留自己的搜尋；它不等於地圖頁搜尋。
- **HIG 必須**：placeholder 明確描述範圍，例如「搜尋行程」或「搜尋收藏」。
- **HIG 建議**：本地資料隨輸入即時更新，提供 clear button，先顯示最相關結果。
- **HIG 必須**：取消或清除搜尋不得改變其他篩選、選取或捲動狀態。
- **HIG 必須**：鍵盤 Search action 可執行搜尋；點欄位外或拖曳列表只收鍵盤，不清除查詢。

參考：[Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields)、[Searching](https://developer.apple.com/design/human-interface-guidelines/searching)。

## 7. Bottom accessory

- **HIG 必須**：bottom accessory 與 root tab bar 是兩個層級；展開時允許形成兩排。
- **HIG 必須**：同一畫面同時最多一個 bottom accessory。
- **HIG 建議**：有可捲動內容時，可依系統 tab-bar minimization 在向下捲動後把目前 tab 與 accessory 移到同一排；捲回頂端或點目前 tab 時恢復。
- **Tripline 決策**：不得因畫面存在一般表單欄位就縮小 tab bar。
- **HIG 必須**：鍵盤開啟後，輸入 accessory 移到鍵盤上方；root tab bar 隱藏。
- **HIG 必須**：accessory 遵守 home indicator、safe area、Dynamic Type 與 Reduce Motion。

### 7.1 聊天 composer

- **Tripline 決策**：composer 是聊天頁持續存在的 bottom accessory。
- **Tripline 決策**：左側 `＋` 開啟附件與行程功能；中間輸入框由 1 行長到最多 4 行，之後內部捲動。
- **Tripline 決策**：空白時右側顯示麥克風；有文字時切換為送出。
- **Tripline 決策**：Return 換行；外接鍵盤使用 Command–Return 送出。
- **HIG 必須**：切換 tab、開啟 Account 或暫時離開 App 時保留草稿。
- **HIG 必須**：首次啟動語音時才請求麥克風權限。

## 8. Day selector

- **Tripline 決策**：行程時間軸顯示 `Day 1…Day N`；地圖顯示 `全部、Day 1…Day N`。
- **Tripline 決策**：Day selector 固定在 inline Header 下方的內容頂部，不進入 root tab bar 或 bottom accessory。
- **Tripline 決策**：它是可水平捲動的 Day selector，採 system segmented appearance；不得宣稱為原生可捲動 segmented control。
- **HIG 建議**：所有選項維持同一視覺分組，選中項清楚，避免同時混入地圖／行程切換等 action。
- **HIG 必須**：選中 Day 自動保持可見並盡量置中；邊緣露出部分下一項，提示可捲動。
- **HIG 必須**：每個選項至少 44pt 高，寬度隨 Dynamic Type 增加，不縮字。
- **HIG 必須**：水平滑動只瀏覽選項，點擊才切換 Day；內容區不支援左右滑動切 Day，避免和 edge-back 衝突。
- **HIG 必須**：VoiceOver 讀出「第 {n} 天，共 {total} 天，已選取」；外接鍵盤可用左右方向鍵移動。
- **HIG 必須**：Reduce Motion 開啟時取消自動捲動動畫。

Apple 建議 iPhone segmented control 約不超過五項；Tripline 為了長行程保留連續 Day 瀏覽，因此把此組合明確列為產品決策。參考：[Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)。

## 9. 地圖與 POI

### 9.1 地圖

- **Tripline 決策**：地圖頁不提供搜尋。
- **HIG 必須**：保留地圖原生 pan、pinch zoom、rotate、double-tap 與 POI 手勢；上層控制不得攔截地圖空白區。
- **HIG 必須**：定位使用獨立 floating control，首次點擊才請求位置權限。
- **HIG 必須**：地圖 appearance 在 provider 支援時跟隨系統 Light／Dark，並維持標記與文字對比。
- **Tripline 決策**：切換 `全部／Day` 同步更新標記、路線與行程 POI accessory。
- **HIG 必須**：marker、route 不只靠顏色區分；需搭配編號、線型、選取狀態與 semantics。

### 9.2 行程 POI accessory

```text
[目前範圍的行程 POI 橫向卡片列]
[聊天　行程　地圖　收藏]
```

- **Tripline 決策**：目前範圍有行程 POI 時，卡片列持續顯示在 tab bar 上方；沒有 POI 時隱藏 accessory，改在地圖內顯示簡短空狀態。
- **Tripline 決策**：點行程 marker 時，卡片列捲到對應 POI；滑動卡片時，地圖聚焦對應 marker。
- **Tripline 決策**：卡片列水平滑動，不循環、不製造假資料，並露出下一張卡作為滑動提示。
- **Tripline 決策**：行程 POI accessory 沒有垂直拖曳、detent 或 grabber。
- **Tripline 決策**：選取外部 POI 時，以外部 POI compact card 暫時取代行程 POI 列；關閉後恢復原本 Day、卡片位置與 marker 狀態。
- **HIG 必須**：卡片需顯示名稱、時間與本地化類型；缺位置時明確顯示「尚無位置」。
- **HIG 必須**：卡片高度隨 Dynamic Type 增加，不裁切必要內容。
- **HIG 必須**：外部 POI 不經明確加入流程就不得寫入目前行程。

## 10. 日期與時間輸入

### 10.1 日期

- **HIG 必須**：點擊日期欄位後開啟 system calendar date picker，不自行製作月曆。
- **HIG 必須**：年月日順序、每週首日、月份與星期文字跟隨裝置 locale。
- **HIG 必須**：欄位顯示本地化完整日期；資料層仍使用既定 date-only 格式。
- **HIG 必須**：停用不合法日期，例如結束日早於開始日或超出業務允許範圍。
- **HIG 必須**：取消不改值；使用者確認後才寫回表單。
- **HIG 必須**：VoiceOver 讀出完整日期與選取狀態。

### 10.2 單獨時間

- **HIG 必須**：只選擇時與分時使用 system time picker，不混入日期或秒。
- **Tripline 決策**：分鐘間隔固定為 5 分鐘。
- **HIG 必須**：12／24 小時顯示跟隨系統 locale 與偏好，不強制 24 小時制。
- **HIG 必須**：取消不改值；確認後才寫回。
- **HIG 必須**：起訖時間分開選擇，錯誤顯示在相關欄位附近；不得靜默改寫使用者選擇。
- **HIG 必須**：VoiceOver 讀出本地化時間，例如「下午三點二十五分」。

參考：[Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers)。

## 11. 表單與 sheet

- **HIG 建議**：短而單一任務的新增／編輯使用 system sheet；較長、多步驟或需要完整上下文的流程使用 push navigation。
- **HIG 必須**：sheet 左側使用「取消」，右側使用「完成／儲存」，並使用文字按鈕。
- **HIG 必須**：沒有變更時可直接關閉；有未儲存內容時，返回、取消或拖曳關閉都先詢問是否捨棄。
- **HIG 必須**：儲存期間阻止重複提交並顯示 progress；成功後才關閉。
- **HIG 必須**：儲存失敗時保留全部輸入，錯誤顯示在相關欄位或持續性頁面狀態。
- **HIG 必須**：鍵盤 Next／Done、焦點順序與 Full Keyboard Access 順序一致。
- **HIG 必須**：同時只呈現一個 sheet；第二個 scoped task 應在現有 Navigation Stack 中 push。

## 12. 刪除動線

所有刪除都是不可復原的 Tripline 產品決策。

### 12.1 入口

- **Tripline 決策**：swipe action、`…` menu、context menu 與詳情頁可提供刪除入口，但全部導向同一確認流程。
- **HIG 必須**：swipe 只揭露紅色「刪除」；停用 full swipe 直接執行。
- **HIG 必須**：menu 中的刪除放在尾端、與其他動作分隔並標示 destructive role。
- **HIG 必須**：所有刪除入口使用相同名稱、結果與 accessibility label。

### 12.2 確認

- **HIG 必須**：確認畫面顯示對象名稱、影響與「無法復原」。
- **HIG 必須**：安全選項為預設焦點；破壞性按鈕明確寫「刪除」，不用「確定」。
- **HIG 必須**：刪除按鈕使用 system red；不得只靠顏色表達危險。
- **HIG 必須**：刪除帳號、登出所有裝置等高影響操作需重新驗證身分。

### 12.3 執行結果

- **HIG 必須**：執行中鎖定重複提交並顯示 progress。
- **Tripline 決策**：伺服器成功後才從畫面移除資料；失敗時保留原資料與選取狀態並提供重試。
- **Tripline 決策**：不提供 Undo、垃圾桶、復原期限或 restore API 動線。
- **HIG 必須**：完成後焦點移到合理的下一個項目或頁面標題，VoiceOver 宣告結果。

本節覆蓋舊的收藏 Undo／restore 設計與後端交付文件。

## 13. 拖拉與滑動

- **HIG 必須**：保留 iOS leading-edge 返回手勢，不在內容區配置會衝突的整頁水平手勢。
- **HIG 必須**：可排序列表使用明確 drag handle；整張卡片不得同時兼任 tap、context menu 與拖曳入口。
- **Tripline 決策**：行程項目可在同 Day 排序或拖到另一 Day；drop 成功後一次同步來源與目的 Day，失敗則完整還原。
- **HIG 建議**：拿起、跨越有效 drop target 與放下時使用克制的 haptic，並支援邊緣自動捲動。
- **HIG 必須**：拖曳中的 preview、插入位置與不可放置狀態必須可見，不能只靠顏色。
- **HIG 必須**：VoiceOver、Switch Control 與 Full Keyboard Access 提供「上移／下移／移至其他 Day」替代 action。
- **HIG 必須**：列表 swipe 只揭露動作；不可復原刪除必須再確認。
- **Tripline 決策**：Day selector 與 POI carousel 使用水平滑動；bottom sheet 使用垂直拖拉切換 detent；兩者的 hit region 不重疊。
- **HIG 必須**：Reduce Motion 開啟時，拖曳後的重新排列不用彈性或長距離動畫。

## 14. 載入、回饋、離線與錯誤

- **HIG 建議**：首次載入使用 system progress indicator 或接近最終版型的靜態 skeleton，不顯示空白畫面。
- **HIG 必須**：更新既有資料時保留舊內容，只顯示低干擾更新狀態。
- **Tripline 決策**：行程與收藏列表支援 pull to refresh。
- **HIG 必須**：成功時優先直接更新畫面，不為每個成功動作顯示 modal 或提示。
- **HIG 必須**：欄位錯誤顯示在欄位附近；頁面錯誤使用持續可見、可重試的狀態；只有阻斷流程或需要立即決定時使用 Alert。
- **HIG 必須**：離線時保留可用快取並顯示持續性離線狀態。無法離線執行的動作仍可被理解，點擊後說明原因。
- **HIG 必須**：Root tabs 不因離線、空狀態或錯誤消失。
- **HIG 必須**：載入、錯誤與完成狀態需透過 live region 或等效 semantics 對 assistive technology 宣告。

## 15. 系統權限

- **HIG 必須**：所有權限 just-in-time 請求，不在首次啟動集中索取。
- **Tripline 決策**：首次使用定位、麥克風、通知、行事曆或附件功能時才請求相應權限。
- **HIG 建議**：照片與檔案優先使用 system picker，能避免永久權限時不索取。
- **HIG 必須**：權限前文案說明具體用途與價值，不使用泛稱。
- **HIG 必須**：拒絕後不反覆跳系統 prompt；在功能位置說明影響，必要時提供前往系統設定。
- **HIG 必須**：權限不足不得導致資料遺失、無限 loading 或沒有出口的畫面。

## 16. 視覺系統

### 16.1 Color

- **HIG 必須**：背景、surface、文字、separator、disabled 與語意狀態使用 dynamic system colors，不維護暖白／暖褐完整自訂 palette。
- **Tripline 決策**：保留一個可適應 Light、Dark 與 Increased Contrast 的暖褐 app tint，只用於選取、link 與主要動作。
- **HIG 必須**：destructive、warning、success 使用系統語意色，不套品牌 tint。
- **Tripline 決策**：地圖 Day marker／route 可使用資料編碼色，但必須搭配編號或線型。
- **Tripline 決策**：App Icon 保留現有座標圖釘識別。
- **HIG 必須**：不使用顏色作為唯一資訊來源。

參考：[Color](https://developer.apple.com/design/human-interface-guidelines/color)、[Branding](https://developer.apple.com/design/human-interface-guidelines/branding)。

### 16.2 Liquid Glass

- **HIG 必須**：Liquid Glass 是功能層，不是內容層。
- **Tripline 決策**：tab bar、toolbar、menu、sheet、floating controls、composer 與 POI accessory 可使用 Glass；列表、表單、卡片與主要內容使用 system surface。
- **HIG 必須**：避免 glass 內再巢狀 glass；內容卡不得重複 blur 或 refraction。
- **HIG 必須**：Reduce Transparency 使用不透明 system fallback；Increase Contrast 提高邊界與文字對比。
- **HIG 建議**：Glass 一般不著色，只在選取或主要強調使用暖褐 tint。

參考：[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)。

### 16.3 Typography

- **HIG 必須**：全 App 使用 San Francisco／平台系統字與 system text styles，不載入自訂字型。
- **HIG 必須**：支援全部 Dynamic Type 尺寸，包括 Accessibility Sizes 與 Bold Text。
- **HIG 必須**：一般內容可換行；只有 toolbar、tab label 與短識別文字可合理截斷。
- **HIG 必須**：POI 卡、表單、聊天訊息與設定 row 隨文字增高，不以固定高度裁切。
- **HIG 必須**：時間、數量與日期需要對齊時可使用 tabular figures。
- **Tripline 決策**：不使用 Large Title。

### 16.4 Icons 與 touch target

- **HIG 必須**：優先使用 iOS 16 已支援的 SF Symbols；自訂 icon 只有在沒有合適 system symbol 時使用。
- **HIG 必須**：symbol-only control 提供 tooltip、VoiceOver label 與至少 44×44pt 點擊區域。
- **HIG 必須**：icon 的 selected、disabled、loading 與 destructive 狀態使用系統慣例。

### 16.5 App Icon

圖形是圓角定位圖釘外框，中央為實心指南針箭頭。三種外觀維持**完全相同的輪廓與比例**，只換配色。

| 外觀 | 背景 | 圖形 |
|---|---|---|
| Default | 木棕 `#A97A4A` | 奶油白 `#FFFBF5` |
| Dark | 棕黑 `#1A140F` | 木棕 `#A97A4A` |
| Tinted | 等亮度灰 `#818181` | 白色（供系統著色） |

- **Tripline 決策**：不預先裁圓角，由系統套用遮罩。
- **Tripline 決策**：主圖保留足夠安全邊距，確保 20pt 小尺寸仍可辨識。
- **Tripline 決策**：iOS 沿用 `Assets.xcassets/AppIcon.appiconset` 的 Single Size 格式，提供 Default／Dark／Tinted 三個 1024×1024 主檔，各尺寸由 Xcode 產生。
- **Tripline 決策**：Android 沿用既有 `mipmap-*/ic_launcher.png`，以 Default 版本縮放覆蓋，不引入額外的啟動圖示框架。
- 所有 PNG 必須是正方形、正確像素尺寸且**不含 alpha**。

木棕 `#A97A4A` 就是 CONTEXT.md 定義的 tint（品牌柔褐）；App Icon 是它唯一以「大面積填色」出現的地方，App 內一律只上前景。

## 17. Motion 與 haptics

- **HIG 必須**：navigation、sheet、menu、tab 與鍵盤使用系統節奏。
- **Tripline 決策**：自訂動畫只用於 Day、POI、內容狀態與排序回饋。
- **HIG 必須**：Reduce Motion 開啟時取消位移、縮放與彈性動畫，改為直接切換或短淡入淡出。
- **Tripline 決策**：haptic 只用於 tab／Day 選取、拖拉關鍵點、送出完成、警告與 destructive confirmation。
- **HIG 必須**：一般按鈕、捲動與每次輸入不觸發 haptic。
- **HIG 必須**：動畫不得阻擋操作，也不得作為唯一狀態提示。

## 18. Accessibility release gate

以下任一失敗都阻擋 release：

- 全部互動控制至少 44×44pt，並有足夠間距。
- VoiceOver reading order、label、value、hint、selected、expanded 與 destructive 語意正確。
- Voice Control 名稱可對應可見 label。
- Switch Control、Full Keyboard Access、外接鍵盤與 pointer 可完成核心流程。
- 支援 Dynamic Type、Bold Text、Increase Contrast、Reduce Motion（`MediaQuery` 均可偵測），以及 Reduce Transparency（**Flutter 沒有這個 flag**，一律走 `AppAccessibilityScope.reduceTransparencyOf(context)`；用 `MediaQuery` 找它 = 違反）。
  Differentiate Without Color 與 Button Shapes **Flutter 偵測不到**（`MediaQueryData` 只有 `accessibleNavigation`／`invertColors`／`highContrast`／`onOffSwitchLabels`／`disableAnimations`／`boldText`），因此不列為可稽核項；等效要求由下面「不只靠顏色」那條承擔。
- focus 不被固定 Header、鍵盤、tab bar、sheet 或 POI accessory 遮住。
- 拖拉與 swipe 都有不依賴手勢的替代 action。
- 地圖標記、Day、路線、錯誤與選取不只靠顏色。

參考：[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)。

## 19. 驗收矩陣

### 19.1 自動驗收

與 CI（`.github/workflows/mobile.yml`）一致，逐項對得上：

- 格式：`git ls-files -z '*.dart' ':!:patrol_test/test_bundle.dart' | xargs -0 dart format --output=none --set-exit-if-changed`（`:58`）。**不要簡寫成 `dart format .`** —— 會撞到 `build/` 的 Gradle 產物，且 `patrol_test/test_bundle.dart` 由 `patrol build` 重新產生、格式不受控，CI 已排除它。
- `flutter analyze --no-fatal-infos` 零 error／warning（`:61`）
- `flutter test` 全綠 —— 跑**整個** `test/`，不挑檔（`:69`）
- HIG 十態矩陣：`test/flows/hig_regression_matrix_test.dart` 的 Light／Dark ×（一般字級、2× 字級、Reduce Motion、Increased Contrast、Reduce Transparency），於 390×844 驗證幾何與行為。**新增 chrome 元件要進這支測試。**
- 畫面證據集：`test/flows/app_owned_release_flow_artifacts_test.dart` 產出 14 畫面 × 10 態 = 140 張 PNG 到 `build/test-artifacts/app-owned`，供人眼比對。**repo 裡沒有 golden 基準檔**（無 `matchesGoldenFile`），所以 golden regression 不是必過項；新增 root 畫面要進 `expected` 集合。
- 新畫面的 widget test 至少覆蓋 320×568 與 `TextScaler.linear(2)` 以上（範圍分散在各畫面測試，不集中於單一支）

### 19.2 手動驗收

- iPhone compact、iPhone landscape、iPad regular、iPad split view。
- Android phone 與 Android tablet 使用相同 iOS HIG 視覺。
- Light／Dark、Increase Contrast、Reduce Transparency、Reduce Motion、Bold Text。
- VoiceOver、Voice Control、Switch Control、Full Keyboard Access、pointer 與外接鍵盤。
- 鍵盤、safe area、旋轉、sheet、tab state restoration、edge-back。
- 聊天、切換行程、Day、日期／時間 picker、拖拉排序、地圖、POI、收藏、Account 與全部不可復原刪除流程。
- 真機或 simulator 驗證 Liquid Glass、PlatformView、效能與 raster jank。

## 20. 來源階層與實作落差

UI 規範的來源階層，由高到低：

1. [`docs/adr/`](docs/adr) —— ADR 記錄的是決策當下的取捨與被拒方案，且會標註更正史。與本文件衝突時**以 ADR 為準**（例：導覽 chrome 的膠囊分組見 [ADR-0004](docs/adr/0004-neutral-selection-surface-with-tinted-foreground.md)）。
2. 本文件。
3. [CONTEXT.md](CONTEXT.md) —— 只定義語彙，不定義規範；但本文件用到的名稱必須與它一致。

`code-review` 的 Standards 軸同時讀 [`CODING_STANDARDS.md`](CODING_STANDARDS.md) 與本文件。**UI 條文不重複維護**：刪除動線（§12）、Accessibility release gate（§18）、驗收矩陣（§19）只寫在本文件，`CODING_STANDARDS.md` §UI 規範不複述，只記兩件本文件沒有或說錯的事 —— 動作動詞的圖示與顏色對照表（本文件沒寫），以及本文件的失效與誤導條文清單（照抄會報假陽性或誤判）。

若實作或測試與本文件衝突，以本文件為準並建立 migration work，不得靜默保留舊規則 —— 除非該項已有 ADR 明文推翻。
