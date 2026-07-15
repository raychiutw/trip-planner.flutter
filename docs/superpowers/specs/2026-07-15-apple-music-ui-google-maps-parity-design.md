# Tripline Flutter Apple Music UI/UX 與 Google Maps 對齊設計

日期：2026-07-15

狀態：已核准，依 2026-07-15 第二意見與 Liquid Glass 決策修訂

## 目標

把 2026-07-14 UI/UX 稽核報告中的前端問題全部落地，並將 Flutter 的地圖引擎與互動對齊 Web。Apple Music 是導覽、內容層級、材質、動效與可及性的基準，不複製音樂產品的內容模型。

同時支援 iOS 與 Android。Flutter 使用現有 API 完成所有可行項目；只有現有 API 無法支援的 AI 動作預覽或資料欄位，才在 `/Users/ray/Projects/trip-planner` 的獨立 worktree 修改後端，驗證後合併。Web UI 不在本次範圍。

## 已確認決策

- 使用 `google_maps_flutter` 取代 `flutter_map`、OpenStreetMap、OpenTopoMap 與 Esri tile。
- iOS 與 Android 同步完成原生 SDK、金鑰注入與 CI 設定。
- 保留 Riverpod、GoRouter與現有資料模型；既有 design tokens 可演進成新的 Tripline UI 系統，舊元件只有在符合新層級與可及性規則時才保留。
- 採同一 Flutter 功能分支、分批提交、最後建立一個 PR；Web 後端使用獨立 worktree。
- `/map` 對齊 Web 的目前行程地圖，不再以收藏色點作為主要模型。
- 不建立雙地圖引擎、provider abstraction 或 OSM fallback。
- 不為了 Apple Music 相似度改變 Tripline 的木棕品牌識別。
- Mockup C 原有青綠配色只作版型參考；production 採 V3 中性 dark canvas `#121214`、surface `#1C1C1E`、elevated surface `#2C2C2E`、foreground `#F5F5F7`、muted `#A1A1A6`，並以柔褐 `#CBA06E` 作為唯一 chrome accent。sage／pink 僅保留分類與語意用途。
- 根分頁採 iOS 26 Apple 式浮動 Tab Bar 與 Liquid Glass 功能層；Flutter 實作等效視覺、捲動縮減、語意與降級，不宣稱使用原生 SwiftUI `TabView`。

## 交付切片

### 1. UI 基礎、Root Shell 與 P0 狀態

建立一套精簡且單一來源的 Tripline UI 系統；直接演進既有 tokens，不讓新舊兩套長期並存：

- `TpGlassSurface`：Tab bar、浮動 toolbar 與短暫控制的共用玻璃容器，集中處理 blur、tint、border、shadow、深淺模式與高對比降級。
- `TpRootScrollScaffold`：根頁 large title、inline title、safe area、可縮減 Tab 通知與底部內容 inset。
- `TpContentSurface`：只在卡片本身就是互動或語意群組時使用的標準內容材質，不使用玻璃。
- `TpSettingsGroup`：帳號、通知、外觀與安全頁的 inset grouped row、divider、disclosure 與 destructive hierarchy。
- `TpStateView`：loading、empty、no result、offline、permission 與 error 的統一結構與動作位置。
- 新元件依 4pt spacing、44pt 最小觸控、Dynamic Type 與語意 label 建立；禁止畫面自行硬編 blur、陰影、圓角與底部 inset。

- `content canvas` 保留暖奶油底。
- `content surface` 用於卡片、表單、空狀態，以細微明度差取代厚重邊框。
- `functional material` 用於 Tab bar、toolbar、sheet，採 Liquid Glass 等效半透明材質；內容卡片與頁面背景維持標準 material，不把玻璃鋪滿內容層。
- 木棕只用於品牌與主要動作；一般文字改用高對比中性色，錯誤、成功、協作與收藏使用語意色。
- 根頁統一 large title，捲動後收為 inline title；次層頁固定 inline title。
- 底部 Tab 改成浮在內容上方的 Apple 式玻璃功能層，內容可在其下方滑過；正常狀態顯示一致 icon + 單字 label，選取以填滿 icon、字重與品牌 accent 辨識，不使用厚重的 Material 選取膠囊。
- 根 Tab 切換不做水平 push 動畫；Tab bar 保持固定，內容淡入並保留各 Tab 捲動位置。
- iPhone 長列表向下捲時縮成只保留圖示的緊湊浮動 bar，向上捲、點目前 Tab 或回到頂端時恢復；Android 採同一可理解行為但保留平台返回語意；Flutter Web 維持展開尺寸，僅作響應式與視覺 QA。
- 五個根 Tab 固定為「聊天、行程、地圖、收藏、帳號」，全部只負責導覽、始終可見且保留各分頁導覽與捲動狀態；不得把新增、匯入或其他 action 放進 Tab。
- Glass surface 使用 backdrop blur、淡色 tint、1px 高光邊界與極輕陰影。淺色／深色模式分開取樣；高對比或無法安全判定透明偏好時提高不透明度，文字與 icon 仍達可讀對比。
- Glass 互動只做 150–250ms 的尺寸、透明度與色彩轉場；Reduce Motion／`disableAnimations` 時立即切換，禁止彈跳、縮放與大範圍位移。
- 「新增行程」從底部 FAB 移到行程頁 toolbar 的 `+`，避免遮住列表並與 Tab bar 競爭。
- 所有 toolbar、safe area、鍵盤與小螢幕邊距使用同一規則。
- 根頁 large title 的展開與 inline 狀態必須與實際捲動綁定；次層頁只用 inline title。每個頂部 toolbar 最多兩個可見 trailing action，其餘收進具名「更多」選單。
- 新增、收藏與協作成功使用輕微平台 haptic；錯誤只用清楚文案與語意色，不使用懲罰性的強烈震動。

Root 頁面需區分 loading、第一次使用、無資料、搜尋無結果、離線、權限不足與載入失敗。行程顯示 2–3 張結構骨架；聊天顯示對話骨架與文字；地圖先保留地圖容器再疊局部 loading。超過約兩秒才補充較完整的狀態文案，失敗留在原頁並提供重試。

登入錯誤依 `401/403`、帳密驗證、連線失敗與未知錯誤分流；保留 Email，不把 CORS 或 session 失效統稱為網路問題。開發環境細節只寫 debug log。

所有 icon-only action、FAB、marker、卡片管理動作都必須有可辨識語意名稱、提示與合理焦點順序。新增行程的名稱固定為「新增行程」。

### 2. 原生 Google Maps 與 Web 功能對齊

保留 `TripMapPoint`、route 與 marker 的領域資料；地圖 adapter 內部改成 `GoogleMap`、`GoogleMapController`、`Marker`、`Polyline` 與 `CameraUpdate`。移除 tile preset、tile provider 與圖層選單。

行程地圖功能：

- 預設全覽；提供全覽與每日篩選，切換後 fit 到目前可見點位。
- marker 顯示日別與站序；聚焦點位放大並提高層級，已經過點位視覺降階。
- 點 marker 聚焦對應卡片；點或滑到卡片會聚焦 marker 並移動鏡頭。
- 總覽依日顯示路線；路徑使用 Web 已使用的 `/route` 回應 polyline，不以景點直線假裝導航。路線服務失敗時略過該段並保留 marker／卡片，而不是繪製錯誤替代線。
- 聚焦單一景點時只強調所屬日路線。
- 保留定位、全覽重置、單點安全 zoom、空座標與單點 bounds 防護。
- 多點過密時使用 Google Maps clustering；單日或低密度時直接顯示編號 marker。
- 景點卡片跨日連續捲動，日篩選與 active card 保持同步。
- 選中景點顯示可關閉詳情，提供「跳到行程」並定位到該 stop。
- 地圖內容延伸到半透明功能層後方；控制項放在 safe area 內，不與 Tab bar 或卡片重疊。

`/map` 從既有 Sembast cache 讀取最後成功開啟的 trip ID；沒有紀錄或該行程已不可見時使用行程清單第一筆，並更新 cache。有行程時進入該行程地圖，沒有行程時顯示單一新增行程動作。`/trip/:tripId/map` 與 stop deep link 保留，兩個入口共用同一地圖狀態與元件，不維護第二套全域收藏地圖。

金鑰與平台設定：

- iOS 從 build setting / plist 取得 iOS 專用 key，App 啟動時提供給 Google Maps SDK。
- Android 從未提交的本機 property 或 CI environment 轉為 manifest placeholder。
- GitHub Actions 使用分開的 iOS／Android repository secrets；workflow 不輸出 key。
- 目前被追蹤的 `ios/Flutter/Secrets.xcconfig` 改為未追蹤的本機檔案，repository 提交無值範本與注入邏輯；Android 採同樣規則。
- 因既有 iOS key 已出現在 git 歷史，實作完成前要在 Google Cloud 旋轉並更新本機及 GitHub secret；不把新值寫入 commit、log 或 PR。
- Google Cloud 端需限制 iOS bundle ID `com.raychiu.tripline` 與 Android application ID、簽章指紋；兩平台 key 不共用。

### 3. 核心內容頁

#### 行程列表

- 移除無語意的大型數字封面；已有可用目的地影像時顯示影像，否則使用緊湊日期／目的地色塊，不新增圖片服務。
- 卡片需清楚顯示名稱、日期、國家、天數與擁有者；提高單屏資訊量。
- 搜尋使用較緊湊的系統密度；「全部／我的／共編」緊接搜尋並可橫向捲動，選取不只依賴低對比底色。
- 搜尋預設涵蓋全部內容；scope 只在會明顯改變結果集合時出現。搜尋欄、scope 與 filter 不得同時形成三列常駐控制。

#### 行程詳情

- toolbar 只保留返回、編輯與更多；列印、異動紀錄等低頻動作進更多選單。
- 地圖與筆記改為內容頂部 secondary navigation。
- 移動與排序控制只在編輯模式顯示；閱讀模式不壓縮卡片文字。
- stop 卡片語意需同時朗讀名稱、時間、類型與可用動作。
- DAY selector 自動把選中日期置中，保持可橫向捲動的提示。

#### 收藏

- 預設列只顯示內容與收藏狀態。
- 批次操作只在選取模式顯示；加入行程移到 context menu／平台可用的列動作。
- 地區與類型整合為 Filter sheet，列表頂部只顯示目前生效的少量條件。

#### AI 聊天

- composer 明確顯示輸入 surface，語音與送出不壓過文字輸入。
- 修正缺字方框，回覆按段落與清單排版，先顯示結論。
- 從現有訊息內容或既有 metadata 能可靠識別時，呈現 action chips。
- 任何會改動行程的 AI 動作先顯示 preview，使用者確認後才呼叫 mutation。
- 若現有 API 無法可靠提供結構化 action／preview，後端新增最小欄位，不在客戶端用脆弱文字解析猜測。

### 4. 表單、帳號與管理頁

- 登入、註冊、忘記密碼與設定表單使用持續可見 label、較緊湊欄位及欄位級 helper/error。
- 密碼欄提供規則與顯示／隱藏；submit 保留文字並顯示進度，具備 disabled、loading、success 狀態。
- 個人資料未變更時停用儲存，成功後提供簡短確認。
- 登入裝置顯示人類時間、可信裝置名稱與大概位置；IP 指紋等技術資訊移入詳情。
- 裝置列表不直接鋪滿紅色登出按鈕；詳情頁才提供 destructive action。
- 已連結應用把 epoch 轉成人類時間，把 `openid/profile` 等 scope 翻成使用者可理解的權限。
- 開發者應用移到「進階／開發者」區，不與登入安全並列。
- 通知與外觀保留目前清楚的主標／說明結構，僅套用共用 material、間距與狀態規則。

## 資料流與後端邊界

Flutter 仍以 repository/provider 為唯一資料入口。畫面只維護選取日、選取景點、sheet、filter 與編輯模式等暫態 UI state，不複製 API 資料。

地圖資料由既有 trip/day/timeline model 轉為共用 map view model；`/map` 與行程詳情地圖共用同一轉換。marker、卡片、polyline 與鏡頭都由同一 active entry/day state 驅動，避免雙向同步漂移。

Web 後端 worktree 的修改只允許：

1. 補足結構化 AI action 與 preview 所需欄位。
2. 補足 Flutter 已顯示但現有回應缺少的人類可讀 metadata。
3. 增加相容性測試與文件。

不得順帶重做 Web UI、資料庫架構或無關 API。現有客戶端相容性必須保留；新欄位優先採 additive response。

## 錯誤與降級

- Google Maps SDK 初始化失敗、金鑰受限或配額錯誤時，地圖區顯示原因可理解的錯誤與重試，不讓整頁崩潰。
- 定位權限被拒時保留地圖功能，提供前往系統設定的說明；不反覆要求權限。
- 缺少座標的 stop 留在卡片列表但不建立 marker，並標示「尚無位置」。
- API 離線時保留已有快取內容並顯示非阻斷提示；mutation 仍沿用現有 OCC／離線佇列規則。
- Reduce Motion 關閉非必要位移與 shimmer；Reduce Transparency 時功能層改用不透明高對比 surface。
- Dynamic Type 放大時 toolbar 動作收進更多選單，卡片高度可成長，不裁切文字。
- 所有互動目標最小 44×44pt，正文基準 17pt、輔助文字不小於 11pt；200% Dynamic Type 下 Tab label、標題、表單 label 與主要動作仍可辨識且不互相覆蓋。

## 驗證與完成標準

每個切片保留最小可失敗測試，不為視覺細節建立重型測試框架：

- 純 Dart 測試：map view model、日／景點同步、單點 bounds、錯誤分類、人類時間與 scope 翻譯。
- Widget tests：Tab semantics、FAB／icon actions 名稱、root state variants、表單 label/error、toolbar overflow、map card/day interaction。
- Shell widget tests：五個 Tab 固定且皆有 label／selected semantics、內容延伸到浮動 bar 後方、垂直向下捲縮減、向上捲恢復、水平捲動不觸發、停用動畫時沒有轉場、Web 不縮減。
- Platform configuration tests：iOS plist/build setting 與 Android manifest placeholder 存在，repository 無新增明文 key。
- 若修改後端：API schema／相容性測試及該 repo 的既有完整測試。
- 靜態驗證：`dart format --output=none --set-exit-if-changed .`、`flutter analyze --no-fatal-infos`、`flutter test`。
- 建置驗證：Android debug/release build、iOS no-codesign build；CI 以 repository secrets 驗證 release 注入。
- Runtime QA：Flutter Web 重新跑 390×844、320×568 登入後全頁巡檢；iOS 與 Android 實機驗證地圖手勢、定位、safe area、鍵盤、Dynamic Type、Reduce Motion／Transparency 與 VoiceOver／TalkBack 關鍵流程。

完成需逐項回查 2026-07-14 稽核報告：每個具體 finding 必須有程式碼、測試或 runtime 截圖證據；需要新 API 的項目必須完成後端 additive change，不能只列為待辦。只有受外部平台限制、無法由產品程式控制的項目可以在 PR 中明確記錄限制。

Tab／材質驗收以 Apple 官方現行規範為準：Tab Bar 是根層導覽而非 action、在 iPhone 浮於內容上並以 Liquid Glass 顯示底下內容；Liquid Glass 只形成控制與導覽的功能層，內容層使用標準材質。參考：[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)、[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)。

## 提交順序

1. UI tokens、root shell、狀態、錯誤與無障礙。
2. iOS／Android Google Maps adapter、平台設定與地圖互動。
3. 行程、詳情、收藏、聊天、表單與帳號管理。
4. 必要 Web API worktree 變更、測試與合併。
5. 全量 QA、完成矩陣、版本與 PR。

各提交必須保持可分析、可測；跨 repo 變更先在 Web worktree 通過測試，合併後 Flutter 才鎖定新契約。任何切片失敗都應可單獨回退，不依賴未提交的本機狀態。
