# Apple HIG 合規查核：POI 玻璃 accessory、聊天 composer、App 鎖與小型 UI 變更

研究日期：2026-10-24（Asia/Taipei）。本文件延伸 [2026-10-09 的 HIG 補充](2026-10-09-apple-hig-app-guidelines.md)（以下稱「10-09 筆記」），**不重複**其已寫的觸控目標表、Dynamic Type 表、Liquid Glass 基本規則、Segmented controls 五段上限等內容，只查核四組近期設計是否與 Apple 一手來源衝突，並更正 10-09 筆記與 [DESIGN.md](../../DESIGN.md) 中失準的引用。本文件是研究，不判定 production 程式的 bug，也沒有修改任何其他檔案。

## 方法與來源

- HIG 頁面：讀 DocC JSON `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`（路徑無 `documentation/`），以腳本抽出段落、清單、表格；下載檔放在 session scratchpad 的獨立目錄，腳本放在另一目錄，以 `python3 -I` 執行。引用的可讀網址為 `https://developer.apple.com/design/human-interface-guidelines/<slug>`。
- Apple developer documentation：同樣讀 `tutorials/data/documentation/...` 的 JSON（LocalAuthentication、`NSFaceIDUsageDescription`、SwiftUI `tabViewBottomAccessory`、Adopting Liquid Glass）。
- 不使用任何部落格、Stack Overflow 或二手整理。HIG 頁面的 change-log 日期取自 JSON `alert-date`（無此欄位者另註「頁面未標日期」）。
- 強度標籤：**must**（原文 must/required）、**should**（無 hedge 的祈使句，如 "Use…"、"Make sure…"）、**consider**、**avoid**（"avoid／don't"）。HIG 絕大多數是 should／avoid／consider，這和 DESIGN.md §1 的「HIG 必須」是兩套刻度，見 §3。
- 凡無法追溯到上述頁面者標「**未能從一手來源證實**」，不以記憶補。

### 本次實際取得的頁面與日期

| 頁面（slug） | change-log 日期 | 備註 |
|---|---|---|
| materials | 2025-09-09 | |
| color | 2025-12-16 | |
| buttons | 2025-12-16 | |
| tab-bars | 2026-06-08 | |
| scroll-views | 2026-06-08 | |
| page-controls | 2023-06-21 | |
| text-fields | 2023-06-05 | |
| virtual-keyboards | 2025-06-09 | |
| maps | 2024-12-18 | |
| accessibility | 2025-06-09 | |
| privacy | 2023-06-21 | |
| settings | 2024-06-10 | |
| onboarding | 2024-06-10 | |
| launching | 2024-06-10 | |
| alerts | 2024-02-02 | |
| segmented-controls | 2023-06-21 | |
| typography、writing | 2025-12-16 | |
| managing-accounts | 頁面未標日期 | |
| collections、right-to-left | 頁面未標日期 | |

以下 slug 回 HTTP 404，**HIG 沒有對應頁面**：`face-id-and-touch-id`、`authentication`、`biometrics`、`passkeys`、`dictation`、`voice-control`、`speech-recognition`、`chatting`、`messages`、`materials-glass`。因此 HIG 沒有獨立的「Face ID 頁」「Messages／composer 頁」「聽寫頁」，相關內容只能從 Managing accounts、Privacy、Settings 與開發者文件拼出。

## 1. 結論表

| # | 設計 | 判定 | 一句話理由 | 主導句強度 |
|---|---|---|---|---|
| 1 | 地圖 POI 單一玻璃 accessory（透明卡、無頁碼點、露出下一張） | **符合**（附一個需自行論證的邊界） | 單一玻璃面、不疊玻璃、露出下一張卡與 HIG 方向一致；省略頁碼點 HIG 只寫 "Consider"；邊界是 POI 卡含「內容」而 Materials 說玻璃不進內容層 | avoid（content layer）、consider（page control） |
| 2a | Composer 單一玻璃膠囊、無內層填色輸入框、無可見邊框 | **HIG 未規範**（無衝突） | Text fields／Text views 都沒有要求可見邊框；HIG 沒有 composer 頁 | — |
| 2b | 送出鈕：中性底＋tint 箭頭 | **有疑慮** | Color：強調主要動作時「顏色套在背景而非符號」，Tripline 剛好相反 | should |
| 2c | Placeholder 用 secondaryLabel | **有疑慮（輕）** | HIG 色彩表有專用的 `placeholderText`；用 secondaryLabel 不算已列舉的誤用，但偏離「依語意使用」 | avoid（weak） |
| 2d | 32pt 圓鈕放在 44pt 點擊區 | **符合** | Buttons：hit region 至少 44×44 pt（as a general rule） | should |
| 3 | App 鎖（設定開關＋登入後詢問一次＋鎖定畫面） | **符合**（開關有一處文字歧義，**不構成違反**） | 見 §2.3 主要發現：Managing accounts 該句為 "avoid"、限於 sign-in 脈絡，Privacy 反而建議用生物辨識保護「保持登入的 app」 | avoid／should |
| 3b | 登入後的「開啟／稍後再說」詢問框 | **有疑慮（低）** | Privacy 的 pre-alert 規則要求單一按鈕，但其範圍清單未列 Face ID，不能直接適用 | should（有範圍限制） |
| 4a | 地圖圓形玻璃定位鈕 | **符合** | 符合 Maps「控制項對地圖要有對比」與 44pt；單獨 floating control 屬 Tripline 決策 | should |
| 4b | 深色 segmented thumb 比軌道亮 | **HIG 未規範** | Segmented controls 頁沒有任何外觀／明暗描述 | — |
| 4c | `09:30 - 11:00` 半形冒號、等寬數字 | **HIG 未規範** | Typography／Writing／RTL 都沒談時間格式或 CJK 標點；tabular figures 也未提 | — |
| 4d | 鎖定畫面：置中鎖頭、標題、一個實心鈕、破壞性文字鈕 | **符合**（HIG 無鎖定畫面頁） | 一個 prominent、非破壞性；破壞性動作不當 primary，與 Buttons 一致 | should／avoid |

**沒有任何一項達到「違反」**。有疑慮的兩項（2b 送出鈕著色、3b 詢問框按鈕）原文強度都不是 must，屬於可由 Tripline 決策承擔的偏離，但需如實記錄為偏離。

## 2. 逐項查核

### 2.1 地圖 POI 單一玻璃 accessory

Tripline 做法（[DESIGN.md §9.2](../../DESIGN.md)、[§16.2](../../DESIGN.md)、[設計稿](../design/poi-accessory-glass.html)）：一個玻璃容器（圓角 28，與 tab bar 同心）、內部卡片透明、目前卡用中性半透明選取底、無頁碼點、水平捲動露出下一張。

**主導 HIG 句**

1. Materials（2025-09-09）— **avoid**
   > "Don't use Liquid Glass in the content layer. Liquid Glass works best when it provides a clear distinction between interactive elements and content, and including it in the content layer can result in unnecessary complexity and a confusing visual hierarchy."

   > "Use Liquid Glass effects sparingly. … Limit these effects to the most important functional elements in your app."（should）

2. Adopting Liquid Glass（developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass，頁面未標日期）— **avoid**
   > "Check for crowding or overlapping of controls. Prefer to use standard spacing metrics instead of overriding them, and avoid overcrowding or layering Liquid Glass elements on top of each other."

   這是目前唯一能查到、最接近 DESIGN.md §16.2 「避免 glass 內再巢狀 glass」的一手句子（見 §3）。

3. Tab bars（2026-06-08）— 描述性
   > "For tab bars with an attached accessory, like the MiniPlayer in Music, you can choose to minimize the tab bar and move the accessory inline with it when a person scrolls down."

   開發者文件 `tabViewBottomAccessory(content:)`（iOS 26.0）：
   > "On iPhone, the placement of the bottom accessory depends on the tab bar size: when the tab bar is normal size, the accessory appears above it; when the tab bar is collapsed, the accessory displays inline."

   證明「tab bar 上方附一個 accessory」是系統第一方模式；MiniPlayer 本身就顯示曲名等內容，所以 accessory 上放資訊不等於違規。

4. Scroll views（2026-06-08）— **should**／**consider**
   > "Make it apparent when content is scrollable. … For example, displaying partial content at the edge of a view indicates that there's more content in that direction."（露出下一張卡直接符合）

   > "Consider showing a page control when a scroll view is in page-by-page mode."（**consider**，且前提是 page-by-page 模式）

5. Page controls（2023-06-21）— 整頁**沒有**「必須顯示」的句子；與 Tripline 相關的只有
   > "Use page controls to represent movement between an ordered list of pages."
   > "Although page controls can handle any number of pages, don't display too many. More than about 10 dots are hard to count at a glance."

   POI 列是自然寬度的卡片列、不是「頁」，且一日 POI 可能超過 10 個，頁碼點本來就不是合適的工具。
6. Adopting Liquid Glass — **consider**
   > "Consider aligning the shape of controls with other rounded elements throughout the interface. … use rounded shapes that are concentric to their containers"

   Tripline 的「圓角與 tab bar 同心」符合方向。（這裡的 "concentric to their containers" 指與容器同心，Tripline 把它引申為與相鄰的 tab bar 同心，是合理延伸但非原文字面。）
7. Accessibility（2025-06-09）與 Adopting Liquid Glass
   > "If your app doesn't provide this minimum contrast by default, ensure it at least provides a higher contrast color scheme when the system setting Increase Contrast is turned on."（should）

   > "Test your interface with a variety of display and accessibility settings. … people can … turn on accessibility settings that reduce transparency or motion in the interface. … Ensure you test your app's custom elements, colors, and animations with different configurations of these settings."（should）

   文字對比表（至多 17pt 需 4.5:1、18pt 3:1、粗體 3:1）見 10-09 筆記 §3，此處不重複。
8. Maps（2024-12-18）— **should**
   > "Make sure there's enough contrast between custom controls and the map. Insufficient contrast makes controls hard to see and can cause them to blend in with the map. Consider using a thin stroke or light drop shadow to help a custom control stand out…"

   > "Clearly identify elements that people select."（此句寫在地圖元素的脈絡）

**Tripline 設計與 HIG 的關係**

- 單一玻璃面、內部透明、不疊第二層玻璃：與 #2 的「avoid layering」一致。卡片的選取底是半透明填色而非玻璃材質，不構成玻璃疊玻璃。
- 露出下一張卡：直接對應 Scroll views 的 "displaying partial content at the edge"。
- 省略頁碼點：只違反 Scroll views 的 "Consider"（且僅限 page-by-page 模式），無衝突。位置資訊由 peeking、編號徽章與 semantics 承擔，是合理替代。
- 單一玻璃容器同時含 tab bar 上方的 accessory 與 tab bar 本身（兩個相鄰玻璃面）：符合 tab bar + accessory 的系統模式（#3）。「同一畫面最多一個 accessory」（DESIGN.md:151）在已取得頁面中查無原文。
- 圓角同心：方向一致（#6）。

**需要自行論證的邊界（誠實標示）**：POI 卡是「地點內容」，Materials 說玻璃不進 content layer。Tripline 的論點是「accessory 是導覽／選取控制，與地圖雙向連動」，類比 Music MiniPlayer。HIG 沒有把 accessory 明確歸類為功能層或內容層，因此這是**可辯護但非 HIG 明文背書**的解讀；若 Apple 審查或使用者覺得卡片區域像內容，風險在此。建議在 DESIGN.md §9.2 把理由寫成「Tripline 決策：accessory 屬導覽層，類比 MiniPlayer」，而不是只引 "Liquid Glass 是功能層"。

**對比疑慮（需實測，非判定）**：設計稿的深色選取底為白 16%（淺色 62%），HIG 只給文字對比數值，**沒有**選取指示器（非文字）的對比比例，因此 16% 是否足夠辨識「目前卡」無法由 HIG 判定。Maps 頁的 "Clearly identify elements that people select" 與 "enough contrast between custom controls and the map" 是最近的依據，建議以真機在亮／暗地圖上實測，並確認 Increase Contrast 下選取底有加強邊界（DESIGN.md §16.2 已有降級規則）。另外 DESIGN.md:208 寫「卡片不畫外框」，但設計稿 `.card.active` 有 `inset 0 0.5px 0` 的亮邊（poi-accessory-glass.html:51），兩者描述不一致，屬文件與稿的小落差。

**判定：符合**（附上述邊界與實測項）。

### 2.2 聊天 composer（單一玻璃膠囊）

Tripline 做法（[DESIGN.md §7.1](../../DESIGN.md)、`chat-composer.html`）：玻璃本身是輸入區、無內層填色輸入框、無可見邊框；placeholder 用次要文字色；空白時為裸麥克風圖示，有文字時變為 32pt 圓形送出鈕（中性底＋tint 箭頭）；最多長到 4 行；鈕的點擊區為 44pt（稿中 `.btn` 44×44，圓點 32×32）。

**Text fields（2023-06-05）是否要求可見邊框？沒有。** 該頁的條列是：

> "Use a text field to request a small amount of information, such as a name or an email address. To let people input larger amounts of text, use a text-views instead."（should）

> "Show a hint in a text field to help communicate its purpose. A text field can contain placeholder text — such as "Email" or "Password" — when there's no other text in the field. Because placeholder text disappears when people start typing, it can also be useful to include a separate label describing the field to remind people of its purpose."（should；placeholder 消失後需有別處說明用途）

> iOS：「Display a Clear button in the trailing end of a text field to help people erase their input.」（should）

全頁**沒有**出現 border、bezel、affordance 或「欄位必須有可見外框」的字樣（以 "border|affordance|visible" 搜尋整頁無此要求）。Clear 鈕的規則寫在 *text field*；composer 是 4 行的多行輸入，依上一句更接近 text view，Text views 頁（本次取得）也沒有 Clear 或邊框規定。因此「無可見邊框」與「無 Clear 鈕」**HIG 均未規範**。

**placeholder 說明用途**：composer 的 placeholder「輸入訊息或語音指令」一旦輸入就消失，但聊天頁本身脈絡明確，Text fields 的 "separate label" 是 "it can also be useful"（consider 級）。可。

**Placeholder 顏色**：Color（2025-12-16）色彩表有專用語意色
> "Placeholder text | Placeholder text in controls or text views. | placeholderText"（iOS UIKit 色表）

並有
> "Avoid redefining the semantic meanings of dynamic system colors. … use dynamic system colors as intended. For example, don't use the separator color as a text color, or secondarylabel color as a background color."（avoid）

Tripline 用 `secondaryLabel` 當 placeholder：這**不是**該句舉的誤用（secondaryLabel 仍用在文字上），所以不算違規，只是沒用系統為此指定的 `placeholderText`。若 Flutter 端沒有對應的系統色映射，維持 secondaryLabel 是可接受的取捨。建議在 §7.1 註明「placeholder 採 secondaryLabel 的理由（對比不低於 placeholderText）」。**不要引用數值**：本次沒有取得 placeholderText 的實際對比值，不能由一手來源比較兩者。

**送出鈕著色（本節的實質疑慮）**。Color 的 Liquid Glass color 段：
> "Apply color sparingly to the Liquid Glass material, and to symbols or text on the material. If you apply color, reserve it for elements that truly benefit from emphasis, such as status indicators or primary actions. **To emphasize primary actions, apply color to the background rather than to symbols or text.** For example, the system applies the app accent color to the background in prominent buttons — such as the Done button — … Refrain from adding color to the background of multiple controls."（should；後半句 avoid）

Buttons（2025-12-16）：
> "In general, use a button that has a prominent visual style for the most likely action in a view. … Keep the number of prominent buttons to one or two per view."（should）

送出鈕是 composer 唯一的主要動作。Tripline 刻意做「中性底＋tint 箭頭」，與 "apply color to the background rather than to symbols" **方向相反**。這不是 must，也有合理設計理由（ADR-0004：選取底中性、tint 只上前景、避免多個控制項各自上色，後者與 "Refrain from adding color to the background of multiple controls" 一致），但需要誠實標示：HIG 對 *primary action* 的推薦是背景上色。10-09 筆記 §7 已就 tab／選取指示與 prominent button 的範疇差異提醒過；本次補充的是**送出鈕本身就屬於 primary action 範疇**，不能再用「這是選取指示器」解釋。

建議（非必須）：(a) 維持現狀並在 DESIGN.md §7.1 寫成「Tripline 決策：送出鈕為 composer 內唯一動作，採中性底以避免玻璃上多處上色；偏離 Color 'apply color to the background'」；或 (b) 有文字時送出鈕改成 tint 背景＋白色（或反白）箭頭，空白時維持裸麥克風，這與系統 prominent 樣式一致。選哪個屬設計決策，需要真機並排看。

**麥克風鈕與系統聽寫**：Virtual keyboards（2025-06-09）有
> "Avoid duplicating system-provided keyboard features. On some devices, the Emoji/Globe key and Dictation key automatically appear beneath the keyboard, even when people are using custom keyboards. … it's likely to be confusing if you repeat them in your keyboard."（avoid）

這句寫在**自訂鍵盤（custom keyboard extension）**的脈絡，Tripline composer 並不是自訂鍵盤，所以**不直接適用**。Tripline 的麥克風是 app 自己的「語音指令」功能（DESIGN.md:164，首次啟動語音才請求麥克風權限）而非插入聽寫文字。若該按鈕實際只是把語音轉成輸入文字，使用者可能把它與系統鍵盤上的 Dictation 鍵混淆，但 HIG 沒有針對一般輸入列的明文。**HIG 未規範聽寫鈕**（`dictation` slug 404）。

**Composer 放在鍵盤上方並使用玻璃**：Virtual keyboards 同頁
> "If other views in your app use Liquid Glass, or if your view looks out of place above the keyboard, apply Liquid Glass to the view that contains your controls to maintain consistency."（should）

支持 composer 用玻璃（Tripline 做法一致）。

**點擊區**：Buttons
> "As a general rule, a button needs a hit region of at least 44x44 pt — in visionOS, 60x60 pt — to ensure that people can select it easily…"（should）

> "Always include a press state for a custom button."（should）

稿中點擊區 44×44、可見圓 32pt，符合；32pt 的「Small (32 pt)」出現在 Buttons 頁的 **visionOS** 尺寸表，**不是 iOS 規範**，不要拿它當 iOS 依據。press state 在稿裡未呈現，需在實作確認（DESIGN.md 待驗項）。

**Reduce Transparency／Increase Contrast**：見 §2.1 第 7 點；稿已列「退回 surfaceContainerHigh 不透明底」，方向正確。HIG 要求的是測試而非特定做法。

**判定**：2a 未規範、2c 輕微偏離、2d 符合、**2b 有疑慮**（強度 should）。

### 2.3 App 鎖（Face ID／Touch ID）— 最重要的發現

規格來源：GitHub issue #462（視為資料）、[DESIGN.md §5／§5.1](../../DESIGN.md)、10-09 筆記第 284 行。

#### 2.3.1 「避免 app 內生物辨識開關」的原文

**句 A — Managing accounts（頁面未標日期）— avoid（"In general"）**

> "In general, avoid offering an app-specific setting for opting in to biometric authentication. People turn on biometric authentication at the system level, so presenting an in-app setting is redundant and could be confusing."

位置：Best practices 的條列，緊接在 "Always identify the authentication method you offer…"（舉例 "Sign In with Face ID"）與 "Refer only to authentication methods that are available in the current context" 之後，整頁主題是**帳號建立與登入**。

**句 B — Settings（2024-06-10）— avoid**

> "Respect people's systemwide settings and avoid including redundant versions of them in your custom settings area. People expect to use the system-provided Settings app to manage global options like accessibility accommodations, scrolling behavior, and authentication methods, and they expect all apps and games to adhere to their choices. Including custom versions of global options in your settings area is likely to confuse people because it implies that systemwide settings may not apply to your app or game and that changing your custom version of a global setting may affect other apps and games, too."

這是 DESIGN.md §5 第 116 行「不得重複實作系統已有的 Dynamic Type、accessibility、鍵盤、捲動或**認證偏好**」的真正出處（該句把 Settings 的 "accessibility accommodations, scrolling behavior, and authentication methods" 列表改寫成中文並加上 Dynamic Type、鍵盤）。

**句 C — Privacy（2023-06-21）— should（"use"）**

> "To further protect access to apps that people keep logged in on their device, use biometric identification like Face ID, Optic ID, or Touch ID. For developer guidance, see LocalAuthentication."

同頁另有
> "Avoid inventing custom authentication schemes. If your app requires authentication, prefer system-provided features like …, sign-in-with-apple or password-autofill."

LocalAuthentication 的用法是系統提供的機制，不算「自創認證方案」。

**開發者文件（LocalAuthentication 與 `LAPolicy`）**

> "Use biometrics as a supplement to something you're already doing. Don't depend on biometrics as your only authentication option."（Logging a User into Your App with Face ID or Touch ID）

> `deviceOwnerAuthentication`：「…authenticate a user in iOS with either biometrics or a passcode … In iOS, policy evaluation fails with the error passcodeNotSet if the device passcode isn't enabled.」

#### 2.3.2 判定：App 鎖開關**不違反**這些句子

逐點說明，不含糊：

1. **強度**。A 與 B 都是 "avoid"，A 還加了 "In general"。沒有任何 must 或 "don't"。所以即使判定為偏離，也只是偏離一則建議，不是違反規定。DESIGN.md 把它標成「HIG 必須」是**過度標示**。
2. **適用範圍**。A 的理由是 "People turn on biometric authentication at the system level"，亦即**啟用生物辨識作為登入／帳號驗證方式**這件事系統已經處理（Face ID 的註冊與啟用）。B 同理：避免在 app 內重做「系統層級全域選項」。App 鎖處理的是另一件事：**這個 app 要不要在冷啟動時要求一次本機驗證**。這是 app 範疇的策略決定，不是在重做系統的 Face ID 啟用開關，也不會讓人誤以為「改這裡會影響其他 app」（B 的混淆理由）。
3. **C 直接支持目標**。Privacy 明說要保護「people keep logged in on their device」的 app 時使用生物辨識。Tripline 的 session 長期存在 secure storage，正是這個情境。C 沒有說這種保護應該預設開啟，也沒有說不能有開關；而要讓使用者能選擇是否啟用，必須有某處的開關（在系統層找不到 per-app 設定，見下）。
4. **文字上的殘餘歧義（誠實標示）**。句 A 字面是「app-specific setting for opting in to biometric authentication」，而 Tripline 的「Account → 安全性 → Face ID 解鎖」開關，字面上也是一個 app 專屬、用於 opt in 生物辨識的設定。HIG 沒有明確區分「用生物辨識登入」與「用生物辨識鎖 app」，所以不能說句 A 完全不涵蓋它。我的判斷是：**依 A 的上下文（登入方式命名）與其理由（系統層已啟用）、加上 C 的明確建議，開關屬於 HIG 容許範圍，標示為「文字有歧義、傾向符合」，不判違反。**
5. **無法由一手來源證實的前提**：「iOS 系統沒有提供 per-app 的『需要 Face ID 才能開啟』設定」這件事，本次**未能從 HIG 或所取得的開發者文件證實**（也未證實相反）。因此不能用「系統層沒有等價功能所以開關不冗餘」當論據；上面第 2、3 點的論證不依賴它。若要引用，需另讀 Apple 的支援文件，本次不在允許來源範圍內。
6. **Tripline 已採取的緩解**符合 A、B 的意旨：預設關閉（Settings：「Aim to provide default settings that give the best experience to the largest number of people」）、開關標籤用實際的驗證方式、關閉也需驗證。

**結論**：不違反；對應條文最多是「avoid（建議）」，且 C 提供正向依據。**建議修正 DESIGN.md**（不由本研究執行）：
- §5 第 116 行改為「HIG 建議（Settings、Managing accounts：avoid redundant versions of systemwide settings）」並註明適用範圍是「重做系統層設定」，不要寫成「HIG 必須」。
- §5.1 第 2 條「會與該條字面衝突」改為「字面上與 Managing accounts 的 'avoid … opting in to biometric authentication' 有歧義，依 Privacy 'use biometric identification' 與該句的 sign-in 脈絡判定為容許」，並把 Privacy 句 C 列為正面依據。
- 10-09 筆記第 284 行同樣需補上限定語，見 §3。

#### 2.3.3 App 鎖其他設計點與 HIG／開發者文件

| 設計點 | 對應一手句 | 判定 |
|---|---|---|
| 按鈕寫「使用 Face ID 解鎖」；toggle 用實際方式命名 | Managing accounts：「Always identify the authentication method you offer. For example, if you display a button for signing in to your app with Face ID, title it using a phrase like "Sign In with Face ID" instead of a generic phrase like "Sign In."」（should）；「Refer only to authentication methods that are available in the current context. For example, don't reference Face ID on a device that doesn't offer it.」；`LAContext.biometryType`：「…if the value of this property is faceID, don't refer to Touch ID in an authentication prompt.」 | 符合。僅在無法判別種類時 fallback 的「生物辨識 解鎖」較籠統，可接受 |
| 「裝置密碼 解鎖」文案 | Managing accounts：「Avoid using the term passcode to refer to account authentication. People create a passcode to unlock their device … If you use the term in your interface, people might think you're asking them to reuse their passcode in your app or game.」（avoid） | **低度疑慮**：Tripline 的「裝置密碼」確實指裝置解鎖碼，並非帳號密碼，字面上不在該句禁止範圍；但 Tripline 本身有帳號密碼登入，zh-TW 的「密碼」一詞可能與帳號密碼混淆。繁中對應 Apple 用詞「passcode」的官方譯法**未能從一手來源證實**（本次未取得 zh-TW HIG），建議用「裝置密碼（螢幕鎖定密碼）」並實機審視 |
| 自動喚起系統驗證；失敗／取消後留在鎖定畫面可重試 | LocalAuthentication：「When your app invokes Face ID, the device begins scanning the user's face right away. Users don't get a final opportunity to cancel. To accommodate this behavioral difference, you might want to provide a different UI…」（consider 級）；`localizedCancelTitle`：Face ID 只在失敗後才顯示取消鈕 | 符合；鎖定畫面本身已是「不同 UI」，可再補一行靜態說明 |
| 系統驗證失敗後可退回裝置密碼 | `deviceOwnerAuthentication`：系統處理 fallback；「Don't depend on biometrics as your only authentication option」 | 符合 |
| 裝置失去生物辨識與密碼時自動關閉 App 鎖 | `deviceOwnerAuthentication` 在 `passcodeNotSet` 時評估失敗（可偵測）；HIG 無明文 | 與文件相容；「不把人鎖在外面」屬 Tripline 決策 |
| 開／關開關需先驗證 | HIG 與所取得的文件**均無規定** | HIG 未規範（合理的安全設計） |
| 鎖定畫面「登出」 | Alerts：破壞性動作需有 Cancel、標示 destructive；Tripline 已有確認（DESIGN.md:126） | 符合 |
| iOS 需 `NSFaceIDUsageDescription` | 開發者文件：「A message that tells people why the app is requesting the ability to authenticate with Face ID.」「This key is required if your app uses APIs that access Face ID.」；Logging a User into Your App…：「The string should clearly explain why your app needs access to this authentication mechanism. The system doesn't require a comparable usage description for Touch ID.」 | 需要；Privacy 的 purpose string 規則「Aim for a brief, complete sentence that's straightforward, specific, and easy to understand. Use sentence case, avoid passive voice, and include a period at the end.」（should）適用於撰寫該字串 |

**登入後「開啟／稍後再說」詢問框（3b）**

Privacy 的 Pre-alert 段（2023-06-21）：
> "The following guidelines apply to custom views that display before system alerts that request permission to access protected data and resources, including camera, microphone, location, contact, calendar, and tracking."

> "Include only one button and make it clear that it opens the system alert. … Use a term like "Continue" or "Next" to title the single button in your custom screen or window"（should）

> "Don't include additional actions in your custom screen or window, unless needed to obtain a legal consent. For example, don't provide a way for people to leave the screen or window without viewing the system alert — like offering an option to close or cancel."（avoid）

Tripline 的詢問框有兩個按鈕（「開啟」「稍後再說」），字面上違反「單一按鈕」。但是：(1) 該規則的範圍明列為 **protected data and resources**，清單用 "including" 未列 Face ID／生物辨識，且 Face ID 的系統提示是 *authenticate* 的許可而非資料存取，**HIG 沒有明說 Face ID 屬於此範疇**；(2) 該詢問框本身是「是否啟用此功能」的選擇，不只是通往系統提示的前導畫面，「稍後再說」是對功能的合法回答。因此**不能直接判違反**，標為低度疑慮。若想保守遵守該規則，做法是：詢問框僅在使用者主動從設定開啟時才走「單一 Continue 鈕」的流程，登入後的主動詢問改為較不干擾的提示（見下），避免「leave without viewing the system alert」的疑義。

登入後主動詢問本身與以下一手句相容（均為 should／consider）：
- Privacy：
  > "Ideally, wait to request permission until people actually use an app feature that requires access."

  Face ID 的系統提示發生在使用者按「開啟」後的第一次驗證，符合 just-in-time。
- Onboarding（2024-06-10）：
  > "Postpone nonessential setup flows or customization steps. Provide reasonable default settings so most people can immediately start interacting with your app or game without performing additional configuration."（should）

  「新登入後馬上問」屬於可延後的設定步驟，會與此句形成輕度張力；Tripline 以「預設關閉＋只問一次＋可稍後」緩解。
- Onboarding 對可跳過教學的 "If you let people skip the tutorial when they first launch your app or game, don't present it again on subsequent launches"（教學脈絡，類比用）— 「每台裝置只問一次」與其精神一致。
- 離線／啟動時避免 alert 的規則（Alerts）只針對 app 啟動的 alert，登入後非啟動，不衝突。

**Android**：HIG 是 Apple 平台文件，對 Android 的生物辨識提示**不適用**；DESIGN.md §2 採「Android 使用同一套 iOS 視覺」是 Tripline 決策，需另以 Android 文件驗證，本研究不涵蓋。

**App switcher 截圖**：issue #462 User Story 14 要求「app switcher snapshot where practical」隱藏內容，DESIGN.md:132 卻寫「不遮蔽 App 切換器截圖」。HIG 與所取得文件**均無此議題的明文**（未規範）；但兩份規格互相矛盾，且若不遮蔽，鎖定畫面對「別人拿起已解鎖手機」的威脅模型保護有限。見 §3。

### 2.4 小型 UI 變更

**(a) 圓形玻璃定位鈕（地圖 floating control）— 符合**

- Maps：
  > "Make sure there's enough contrast between custom controls and the map."（should）；DESIGN.md:73 的 45% 黑底＋白符號且對合成背景 3:1，方向一致。
- Materials：
  > "Only use clear Liquid Glass for components that appear over visually rich backgrounds."
  > "If the underlying content is bright, consider adding a dark dimming layer of 35% opacity."（consider）

  Tripline 用 45% 是自訂數值，**不是 Apple 數值**（10-09 筆記 §7 已寫，此處不重複）。
- Buttons：hit region 至少 44×44 pt（見 §2.2）。
- 「定位必須是獨立 floating control」（DESIGN.md:189 標 HIG 必須）：本次取得的 HIG 頁面（含 Maps、Privacy）**查無此句**；Privacy 只有 "Location button" 的段落（Core Location 的臨時授權按鈕）。屬 Tripline 決策，見 §3。

**(b) 深色 segmented control：選取 thumb 比軌道亮 — HIG 未規範**

Segmented controls（2023-06-21）全頁只談段數、寬度、內容一致、noun 標籤、與 tab bar 的分工，**沒有**任何關於選取 thumb 與軌道明暗、深色外觀或顏色的敘述。Dark Mode 與 Color 的一般規則（對比、使用系統色）仍適用但沒有針對此控制項的句子。因此「thumb 比軌道亮」無從判定合規或違規；視覺是否符合 iOS 系統 segmented control 需要真機對照 Apple 自家 app，**未能從一手來源證實**。

**(c) `09:30 - 11:00`：半形冒號＋等寬數字 — HIG 未規範**

在 Typography、Writing、Right-to-left、Layout、Inclusion 全部搜尋 time／colon／punctuation／CJK／tabular／monospaced digit：

- Typography 沒有 tabular（等寬）數字的敘述；唯一的 "monospaced" 是 `userFixedPitchFont` 等 macOS 字型 API 列表。
- Layout 與 Inclusion 只有一般性句子：
  > "Locale-based internationalization features like left-to-right/right-to-left layout direction, date/time/number formatting, font variation, and text length"（Layout，列為要考慮的 internationalization 項目）

  > "People expect to customize their device by choosing a language for text and a region for formatting values like date, time, and money."（Inclusion）

  這兩句只說時間格式應隨 locale／region，**沒有**說明 zh-Hant 應使用半形還是全形冒號。
- Right-to-left 只談數字順序不翻轉（"Don't reverse the order of numerals in a specific number"），與時間標點無關。

所以 Tripline 的「半形冒號」HIG 無明文可證其對或錯；「zh-TW 系統格式化出的時間冒號是哪一種」未能從一手來源證實（建議以 `DateFormat`／`NSDateFormatter` 在 zh_TW locale 的實際輸出對照，這是 API 行為不是 HIG）。DESIGN.md:345 的 tabular figures 見 §3。

**(d) 鎖定畫面：置中鎖頭、標題、一個實心鈕、破壞性文字鈕 — 符合（無專頁）**

HIG 沒有 lock screen／authentication 頁（404）。可援引的是 Buttons：
> "Assign the primary role to the button people are most likely to choose."
> "Don't assign the primary role to a button that performs a destructive action, even if that action is the most likely choice. Because of its visual prominence, people sometimes choose a primary button without reading it first."（avoid）

> "Use style — not size — to visually distinguish the preferred choice among multiple options."

實心鈕是「使用 Face ID 解鎖」（非破壞性、一個 prominent），登出是破壞性文字鈕（紅字，樣式而非尺寸區分），與上述一致。Managing accounts 的 tvOS 段落 "Avoid displaying a sign-out option when people are signed in at the system level" 針對 TV provider，**不適用**。鎖定畫面「不得使用 emoji、使用系統語意色」屬 Tripline 決策。

## 3. 與既有文件的衝突或過時之處

| 位置 | 現文 | 問題 | 建議 |
|---|---|---|---|
| [10-09 筆記 第 284 行](2026-10-09-apple-hig-app-guidelines.md) | 「避免做 app 內的生物辨識開關（系統層級已設定）」 | 原文是 "In general, avoid offering an app-specific setting for opting in to biometric authentication"，**漏掉 "In general"、"opting in" 與登入脈絡**；同頁 Privacy 另有「To further protect access to apps that people keep logged in … use biometric identification」，未提及，使讀者誤以為 HIG 反對 app 鎖 | 補上限定語與 Privacy 句；強度標 avoid |
| [DESIGN.md:116](../../DESIGN.md) | 「**HIG 必須**：不得重複實作系統已有的 Dynamic Type、accessibility、鍵盤、捲動或認證偏好」 | 出處為 Settings 的 "avoid including redundant versions of [systemwide settings]"，強度 **avoid**，不是 must；「Dynamic Type、鍵盤」兩項非原文列舉（原文列：accessibility accommodations、scrolling behavior、authentication methods） | 改標「HIG 建議」並引 Settings 句，列舉項照原文 |
| [DESIGN.md:124（§5.1 第二條）](../../DESIGN.md) | 「因為會與該條字面衝突，所以預設關閉…」 | 衝突程度被高估；見 §2.3.2。原文且不含「預設關閉」要求，預設關閉是 Tripline 合理決策 | 改成「字面有歧義，依 Privacy 判定容許」並列出 Privacy 句 |
| [DESIGN.md:333](../../DESIGN.md) | 「**HIG 必須**：避免 glass 內再巢狀 glass」 | 在 Materials、Color、Layout、Tab bars、Toolbars 與 Applying Liquid Glass 頁**查無此句**；最接近的是 Adopting Liquid Glass 的 "avoid overcrowding or layering Liquid Glass elements on top of each other"（avoid）。「內容卡不得重複 blur 或 refraction」也無原文 | 改標「HIG 建議（Adopting Liquid Glass）」並引該句；或明寫為 Tripline 決策 |
| [DESIGN.md:151](../../DESIGN.md) | 「**HIG 必須**：同一畫面同時最多一個 bottom accessory」 | Tab bars 頁只描述單一 accessory 的情境，未有「最多一個」條文 | 改標 Tripline 決策 |
| [DESIGN.md:189](../../DESIGN.md) | 「**HIG 必須**：定位使用獨立 floating control，首次點擊才請求位置權限」 | 後半（just-in-time）有 Privacy 依據；「獨立 floating control」查無原文 | 拆成兩條，前者標 Tripline 決策 |
| [DESIGN.md:345](../../DESIGN.md) | 「**HIG 必須**：時間、數量與日期需要對齊時**可**使用 tabular figures」 | 文字本身是「可」，不是必須；HIG Typography 完全沒有 tabular figures 的敘述 | 改標 Tripline 決策 |
| [DESIGN.md:132](../../DESIGN.md) vs issue #462 User Story 14 | 前者「不遮蔽 App 切換器截圖」，後者「app switcher snapshot where practical 隱藏」 | 兩份規格互相矛盾；HIG 未規範 | 在實作前由產品決策擇一；若不遮蔽，需在 DESIGN.md 說明對威脅模型的限制 |
| [DESIGN.md:77](../../DESIGN.md) | 「完成／取消／儲存」文字按鈕標 HIG 必須 | 10-09 筆記 §11 第 3 項已指出，本次無新發現 | 見 10-09 筆記 |

DESIGN.md §1 自己聲明「『HIG 必須』代表 Tripline 的內部強制等級，不表示 Apple 原文全部使用 must」，所以上述多為**標示與可追溯性**問題，而非行為錯誤；但在 PR 或審查中被引用成「Apple 規定」時會失真。

## 4. 未能證實／需真機或 Apple 工程資源確認

1. **iOS 是否提供 per-app 的「需要 Face ID 才能開啟」系統設定**：HIG 與所取得開發者文件均未提及，不能作為「開關是否冗餘」的論據；需另查 Apple 支援文件（本次不在來源範圍）。
2. **Face ID 是否屬於 Privacy pre-alert 規則的 "protected data and resources"**：原文清單用 "including" 未列；需 App Review 實務或 Apple 說明，無法由 HIG 判定。
3. **Managing accounts 該句的作者意圖是否涵蓋 App 鎖**：頁面無範例也無 change-log；只能依上下文推論（見 §2.3.2）。
4. **選取指示器（非文字）的對比標準**：Accessibility 只給文字對比表；POI 選取底 16%／62%、segmented thumb 明暗是否足夠，需真機與 Accessibility Inspector 實測。
5. **深色 segmented thumb 比軌道亮是否與 iOS 系統控制項一致**：HIG 無描述；需與 Apple 第一方 app 並排實機比對。
6. **zh-TW 時間冒號全／半形與 passcode 的官方中文用詞**：HIG 英文頁未涉及；需 Apple 的本地化資源（zh-TW 版 HIG 或系統字串）。
7. **placeholderText 與 secondaryLabel 的實際對比值**：HIG 只給語意名稱，未給數值；不可由 HIG 比較。
8. **press state、Reduce Transparency／Increase Contrast 下玻璃是否維持可讀**：HIG 只要求測試；composer 與 POI accessory 的降級需在實作與真機驗證（DESIGN.md §16.2、§18、§19.2 已列）。
9. **Android 生物辨識與 Material 規範**：HIG 不適用，本研究不涵蓋。
10. **圖像內容**：HIG 頁面插圖與圖說不在 JSON 文字內；若某些規則只出現在圖中（例如 accessory 的尺寸或間距），本次未涵蓋。

本次僅新增本研究文件，未修改 production、DESIGN.md、ADR 或其他檔案，未 commit。
