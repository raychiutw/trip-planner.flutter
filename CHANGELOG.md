# Changelog

本專案的重要變更紀錄。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/),版本依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

### 修正

- 底部 tab 的字符與標籤不再被往 bar 中心擠。原本整排字符與標籤住在「玻璃列寬度扣掉 4pt」的帶狀區裡,四欄均分後每一欄的中心都比自己真正的欄位中心偏內 3／1／−1／−3pt(inline 版面是 6／2／−2／−6pt),越靠外的 tab 偏得越多。現在偏移量最大 1.5pt。
- 捲動時內容不再直接撞上頂部的膠囊。header 佔的那一整條帶(含狀態列)改為對底下的內容做**漸進模糊加淡出**,越往上越糊越淡,到膠囊下緣才收乾淨 —— 日期不會被標題膠囊蓋掉一半,膠囊之間的縫隙也不會漏出孤零零的半個字。原本的柔邊只有 16pt、掛在 header **下方**、而且只有顏色漸層沒有模糊,擋不住 v0.13.0 把 header 拆成獨立膠囊之後從縫隙穿上來的內容。六個 root 畫面共用同一條帶,不再是個別畫面自己決定要不要開。開啟「提高對比」或「降低透明度」時收斂為不透明、不模糊的帶。
- 天氣卡永遠顯示「暫時無法取得預報」。成因有兩層:一是請求的 `end_date` 送 today+16,但 Open-Meteo forecast endpoint 的 16 天含當天、最多只到 today+15,實測整包被打回 HTTP 400 `Parameter 'end_date' is out of allowed range`;行程沒有帶 `tripEnd`,所以每一次請求都踩到。二是 riverpod 3 的 `defaultRetry` 只跳過 `Error`,`DioException` 這類 Exception 一律指數退避重試 10 次,實測會重打 11 次、橫跨約 38 秒,期間畫面卡在「正在更新預報」。現在請求範圍與卡片的「出發前 16 天才開放」門檻共用同一個常數,失敗也不再自動重試。
- 天氣取不到時的文案改成講得出下一步(無法連線／連線逾時／服務回應異常 HTTP xxx),並多一顆「重試」鍵,不再只是一句沒有資訊的「暫時無法取得預報」。

## [0.13.0] - 2026-07-27

### 變更

- 頁面頂部從「一整片玻璃板包住標題與按鈕」改成**每個控制項各自成膠囊**：標題自己一顆、更多選單與帳號頭像各自一顆，中間的空隙直接透出底下的內容。原本的作法是玻璃疊玻璃（動作與頭像本來就各自是玻璃圓鈕），而 iOS 26 的頂部只有按鈕群是玻璃。
- 底部 tab 的選取指示改成**中性膠囊配品牌柔褐的字符與標籤**，不再是柔褐鋪底加純黑字符。對照 iOS 26「電話」app 實測：選取膠囊是中性灰、系統藍在字符與標籤上 —— 強調色在前景，不在背景。
- 底部 tab 未選取的字符改為近白，與標籤同色。先前同一顆 tab 裡字符是中灰、標籤是近白，兩者不一致。
- 底部 tab 的選取膠囊收進自己的欄位。先前膠囊比欄位還寬（實測 124%），會壓到左右鄰居。

### 修正

- 玻璃元件的邊緣重新出現。先前的作法是移除描邊、把邊緣交還玻璃材質，但材質實際上並沒有接手 —— 模擬器實測不論背後是純黑或壓在內容上，邊緣與內部填色的亮度差都是 0，等於整條邊界消失。現在邊緣的強度對齊 iOS 26 實測值。

## [0.12.0] - 2026-07-26

### 變更

- 日期選擇器改成 iOS 分段控制項：半透明的 systemGray6 軌加上比軌更亮的選取膠囊，靠「浮起」表達選取，背後的內容會模糊透出。原本的玻璃軌在純色頁面上等於沒有顏色 —— 導覽玻璃的色調在淺色模式是 `surface`（白），疊在白色頁面上實測軌與頁面同為 `#FFFFFF`。那套配方是給「浮在捲動內容之上的 bar」設計的，靠折射顯形；選擇器需要確定的色值，改用模糊濾鏡加半透明填色達成。開啟「提高對比」或「降低透明度」時收斂為不透明且不模糊。
- Root tab bar 的選取膠囊改回品牌柔褐、字符反白，對齊 iOS 26 tab bar 拿強調色當選取背景的作法。日期選擇器維持中性語意層 —— 它是篩選內容而非切換功能，兩處刻意不同（見 `docs/adr/0003-brand-tint-for-root-tab-selection.md`）。

### 修正

- 補上未定義的 `surfaceContainerHighest` 色階（iOS systemGray4）。它先前會靜靜回退成 `surface`，導致 root tab 與日期選擇器的選取膠囊在深色下比容器更暗、淺色下只差 4%，等於隱形；骨架屏也因此是白底白條／黑底黑條。
- 日期選擇器的選取膠囊先前完全看不見：實測淺色下選取態與未選同為 `#FFFFFF`（差 0），深色是 `#080808` 對 `#040404`（差 4/255）。成因是巢狀玻璃 —— 軌道自成一個玻璃層，巢狀在裡面的子玻璃會被合併進母層，子層自己的顏色不生效。
- 景點外開 Google 地圖時改以名稱優先，不再顯示一串經緯度。座標當查詢字串時地圖只會落一根無名的針。名稱空白才退回座標。
- 日期選擇器軌道移除一條畫不出來的細邊：一般模式下玻璃只拿形狀做裁切、不描邊，那條線只在無障礙 fallback 現形且比其他控制項弱得多。改與導覽 chrome 收斂到同一條規則。

### 內部

- 修好長期失效的 CI 格式檢查閘門：`patrol_test/test_bundle.dart` 由 `patrol build` 產生且未通過 `dart format`，導致每一支 PR 的 CI 都紅（與改動內容無關），後續的 analyze 與測試步驟全被跳過。改以 git pathspec 排除該檔。

## [0.11.0] - 2026-07-26

### 變更

- 開啟「降低透明度」或「提高對比」時，日期選擇器與 root tab bar 的選取膠囊改為中性語意層，不再變成整塊品牌柔褐。
- 選單的選取態改為保留項目原本的字符、勾選另外顯示，不再以勾取代字符；更多選單、範圍選單與行程列表排序三處一致。
- 帳號頭像退出內容頁：固定 bar 不再自動附加帳號入口，帳號入口只留在 6 個 root 畫面的浮動 header。共編設定與分享設定位於 root tab bar 之外，以 `TpAppBar.accountEntry` 明文保留各自的帳號入口 —— 帳號自成一組，不佔內容 Header 的動作額度。
- 時間軸與行程地圖的浮動 header 不再各掛一顆跳到對方的 bar button（與 root tab bar 的「行程」「地圖」重複），切換一律交由 root tab bar 承擔。原本靠查詢參數帶過去的「第幾天」改由跨畫面共用的選取日承接：在時間軸看第 3 天、切到地圖 tab 仍是第 3 天，反向亦然；地圖選「全部」後切回時間軸不會被打回第 1 天；深連結指定的日期仍優先於共用狀態；切換行程後不殘留前一個行程的天數。
- 玻璃元件不再額外描一圈固定顏色的實心線（共用玻璃表面、工具列玻璃圓鈕、工具列動作表面與動作群組四處）；邊緣改由材質的環境邊緣光與高光沿周長產生，只有「提高對比」模式才補一條可見實心邊。導覽配方與共用玻璃表面的參數收斂為同一組，並補上原本未設定的環境邊緣光、光暈強度與高光銳利度三個參數。日期選擇器軌道的中性細邊維持不變。
- 更多選單改以框架的 `RawMenuAnchor` 承載，面板保留自有玻璃並改為中性語意層；觸發鈕本體與按壓高亮同樣改中性、深色模式的項目文字改回標籤色，品牌色只留給字符。選單從觸發鈕位置 scale 展開，空間不足往上翻時原點跟著改為底部對齊；面板寬度改依最長標籤量測並保留區間，短標籤不再撐出空白。對外 API 不變。
- 玻璃上的字符與文字改走單色標籤語意色，並依玻璃底下內容的亮度切換深淺，不再依 app 的明暗模式寫死顏色。地圖等 platform view 背景改用清透玻璃並加約 35% 暗化層（地圖圖磚恆為亮色，深色模式也一樣），字符在暗化後改亮色；行程切換鈕的下拉箭頭改次要文字色，標題本身維持標籤色。
- 收藏 header 的排序與新增收進同一片玻璃容器，彼此只以間距分隔、不畫分隔線；帳號入口維持獨立一顆不入群組，窄寬度加大字級時仍維持原本的折疊行為。表單的儲存／完成改為 prominent 主要動作，著色在底色而不是字符，一列只有一個且置於尾端。
- Root tab bar 的選取膠囊改為中性語意層，字符、標籤與光暈改品牌 tint；未選取態的字符從線條改為實心，兩態靠顏色區分而不是 outline↔filled 切換，與日期選擇器同一套選取語彙。
- 日期選擇器的選取膠囊改為中性語意層，品牌柔褐退回前景（選取態文字與字符）；未選取維持中性次要前景。欄寬從字元數階梯改為量測實際文字寬度，長標籤不再被擠壓截斷，短標籤仍保留 44pt 最小點擊尺寸，且 Dynamic Type 只被計入一次。

### 修正

- 發版 workflow 的契約測試改為驗證縮短後的路徑：商店上傳不等待外部裝置與人工證據，但必須保留 `mobile-release` 環境審核與 master-only 限制；`mobile-e2e.yml` 必須保有自己的 `schedule` 與 `workflow_dispatch`，不會變成沒人呼叫的孤兒 workflow。決策與殘留風險記於 `docs/adr/0002-decouple-store-upload-from-evidence-gates.md`。

## [0.10.1] - 2026-07-25

### 新增

- Android 與 iOS 真機測試現在會實際注入原生地圖的縮放、旋轉與雙擊手勢，並以鏡頭 callback 驗證結果；iOS 本機 release 測試補上獨立的 development signing 設定與操作說明。

### 變更

- Agent skills 統一使用 canonical GitHub repo、五種 triage labels 與按需建立的 domain 文件；issue／PR 內容明確視為不可信資料，避免外部文字被誤當操作指令。
- Mobile release 手動 dispatch 會直接平行上傳 TestFlight 與 Google Play internal；PR／push CI 改跑 format、analyze 與三組 smoke tests，Firebase Test Lab 與人工證據保留為獨立驗證。

### 修正

- 修正 Android 真機手勢橋接可能在測試結束後殘留或吞掉背景例外的問題；清理逾時與執行緒失敗現在會保留原測試錯誤並回報明確原因。

## [0.10.0] - 2026-07-24

### 變更

- 行程清單搜尋支援鍵盤 Search、清除與跨 root tab／詳情往返狀態保留；時間軸 Day selector 補齊左右方向鍵、完整 VoiceOver 語意、窄螢幕置中與僅點選換日。行程與行程日刪除統一為不可復原流程，伺服器成功前鎖定並保留內容，失敗時提供持續重試；缺少日期改以「新增」而非「加回」表達。
- Account 採用有 section header 與 inset separator 的系統設定列；compact width 維持近滿版 Navigation Stack sheet，一般寬度改用置中 form sheet。外觀預設跟隨系統，個人資料支援正確焦點與 Dynamic Type；通知只在使用者啟用項目時說明用途並請求系統權限，並在回到 App 時同步系統狀態，拒絕後不重複提示。刪除帳號會列出影響、要求重新驗證，且僅在伺服器成功後清除本機帳號資料；純 OAuth 帳號在尚無 fresh-auth 契約時會安全阻擋 App 內刪除並導向身分核對說明。
- 收藏刪除改為不可復原：卡片、左滑、選單與批次入口都先顯示具名確認，伺服器成功後才移除；失敗時保留資料與選取並提供重試。Flutter restore API、Undo、feature flag 與 staging release verifier 已移除。
- 註冊、信箱驗證、密碼重設與 OAuth 改用 inline Header 與防重複提交；邀請與公開分享補齊在地日期／時間、Dynamic Type、鍵盤操作與 screen reader 狀態，並維持既有登入方式、不加入 Apple ID 登入。
- 聊天輸入列新增附件／行程項目入口、1–4 行文字輸入、空白時麥克風與有文字時送出切換，並支援 Command–Return 送出；首次語音輸入會先說明用途，權限不可用時提供前往系統設定的恢復動線。
- 聊天、行程與地圖共用目前行程選擇器與 Day 狀態；跨分頁切換會保留可用 Day、分行程聊天草稿，並清除舊地圖選取。
- Root navigation 改為聊天、行程、地圖、收藏四個 tabs；Account 由每個內容頁右上角的 `person.crop.circle` 開啟獨立 navigation sheet，舊 Account／Settings deep links 仍可直達對應 sheet 子頁。
- Welcome／Login 採用跨 iOS、Android 共用的 system colors、暖褐 app tint、HIG controls 與 accessibility fallback；認證與 redirect contract 維持不變。
- Root navigation 依可用寬度在 compact bottom tabs 與 regular top tabs 間切換；一般寬度的行程 detail 加入共用狀態的清單 split view，resize 會保留目前 branch、選取與輸入內容。
- 地圖改用「全部／Day」水平 selector；行程 POI 卡與 marker 雙向聚焦，無 POI 時隱藏底部配件，外部 POI 關閉後會還原原 Day、卡片與 marker 選取，定位受限時提供清楚的設定入口。

## [0.9.6] - 2026-07-23

### 修正

- 修正 iOS Firebase Test Lab 的 Liquid Glass 底部導覽點擊：release 測試改用 app 自有穩定 key，不再依賴 release 不提供的 debug semantics 或套件內部手勢元件。
- 修正 Firebase iOS Test Lab 可能被 SpringBoard 的「Edit Home Screen」教學提示遮住，導致登入後行程清單與原生地圖整合測試誤判失敗；兩條 Patrol 流程會在開始前精準關閉該系統提示並確認提示已消失。
- 修正 iOS 實機 release 測試無法以 `WidgetTester.enterText` 寫入表單；app-owned Patrol 流程統一改走 Patrol 的實機文字輸入 driver，涵蓋登入、聊天與收藏搜尋。
- 登入後流程驗證失敗時保留當下畫面文字，讓 Firebase Test Lab 報告可直接辨識實際停留畫面，而不會先被 mock 驗證訊息覆蓋。

## [0.9.5] - 2026-07-22

### 修正

- 修正 Firebase iOS Test Lab 以不同 Xcode 版本建置與執行時會遭基礎設施拒絕；CI 建置與 Test Lab 統一鎖定 Xcode 26.2，並在簽章及建置前驗證所選 iOS 版本的即時相容性。
- 修正 320pt 窄螢幕搭配最大 Dynamic Type 時，行程卡的完整起訖時間會被 `ActionChip` 淡出裁切；時間維持單行並在可用寬度內等比例縮放。
- 修正行程景點的多行備註被截成三行；卡片現在依內容完整展開，描述、備註與其他資訊分行顯示。
- 修正編輯備註儲存後再次開啟仍顯示舊資料、後續因舊 OCC version 儲存失敗；離線快取會同步單筆資料，共用 optimistic cache 的線上寫入、pending 寫入（包含不同景點 path）與 flush 收尾都會依序執行，使用者再次儲存時會主動喚起 idle queue，當機復原的 patch 也會持久化。
- 編輯器拒絕亂序舊版 SWR 回應；409 `STALE_ENTRY` 重新載入或暫時失敗時保留草稿並等待最新 version 才能重試，重新載入失敗或停留點已被刪除時會持續顯示明確狀態並停用儲存。
- 多人同時編輯改為欄位級合併：未修改欄位採用協作者新版，同欄衝突會要求明確確認；送出期間停用表單，避免請求完成時遺失新草稿。
- 備註編輯改成符合 HIG 長文字情境的 4–8 行可捲動文字視圖，支援換行鍵盤並在鍵盤出現時保留足夠捲動空間。
- 修正 Google Play 安裝版因 Android Maps 金鑰未允許 Play App Signing 憑證而無法顯示地圖；保留既有 debug／upload 簽章與 Maps／Navigation API 限制。

## [0.9.4] - 2026-07-21

### 變更

- 行程停留點改用單行 `起訖時間`，右側接續精確停留時間；下一行固定顯示 Google 分類與星等，地圖入口精簡為 `Google`／`Apple`。

### 修正

- 修正 Timeline 第一個編號與動態高度卡片的直線起點錯位、交通列造成線段中斷，以及最後停留點下方未延伸的問題。
- 修正 45／75 分鐘被錯誤四捨五入為 1 小時／1.5 小時，並補上舊資料只提供 `time` 時的停留時間計算。
- 修正 iOS 大字體下編輯行程的「取消」被固定 44pt 寬度裁切，並為 Google／Apple 地圖按鈕補上完整 VoiceOver 動作語意。
- Android 發佈與 CI 持續由受管密鑰注入 Google Maps 設定；本版重新驗證原生地圖、Google POI 與固定 zoom `13`。

## [0.9.3] - 2026-07-21

### 新增

- Account 成為第 5 個 root tab；行程景點卡加入 Google／Apple 導航、備選景點展開與符合 Tripline 分組的操作選單。
- 行程排序支援短按拖曳到同日任意位置、其他 Day 或空 Day，並在更新後重算受影響日期的交通。

### 變更

- 行程景點卡收斂為名稱、時間／分類／停留／星等、導航與備註四列摘要；點卡片改為展開備選景點，編輯改由 `…` 選單進入。
- 全 App 共用點擊空白與向下捲動收合鍵盤；起訖時間改用平台原生 compact picker。
- Root Header、Day selector 與底部功能列統一 Liquid Glass recipe，並保留 Reduce Transparency／High Contrast fallback。
- GitHub Actions artifact 上傳更新至 `actions/upload-artifact v7.0.1`。

### 修正

- 修正同日景點拖到末端會落在倒數第二筆，以及排序／設為正選請求中切換行程可能更新錯誤行程。
- 修正 session 過期後直接登入另一帳號時，`/my-trips` 離線快取與待同步佇列可能沿用前帳號資料。
- 修正 Windows POSIX workflow contract tests 可能誤用 WSL Bash，並補上跨 Day、備選正選與刪除輔助使用回歸測試。

## [0.9.2] - 2026-07-21

### 新增

- 未登入首頁加入精簡功能導覽、品牌圖片、隱私權入口與登入後開始使用按鈕；帳號頁底部顯示實際 app 版本與 build number。
- 註冊流程要求使用者勾選個資條款並把真實 `privacyConsent` 傳給 signup API；帳號頁加入隱私權政策與依帳號類型二次確認的永久刪除流程。
- App 在前景由離線恢復連線時會立即重試既有同步佇列；冷啟動、回前景與手動重試入口維持不變。
- 行程與收藏列表支援 iOS 慣例的尾端左滑刪除，並保留原本可見操作與收藏六秒復原。
- 收藏頁加入 HIG S1 即時搜尋、排序／篩選選單與符合文字加深；窄螢幕搭配 200% Dynamic Type 時，新增景點會收進既有更多選單。
- 原生地圖 smoke 與 release flow 補上 zoom `13`、固定白天地圖、Light／Dark Liquid Glass 與命名畫面證據。

### 變更

- Flutter 開發、CI、TestFlight、Google Play 與 Firebase Test Lab 工具鏈統一為 3.44.7 stable；PATH 不再混用舊 SDK。
- 建立行程不再傳送 client-generated `id`，由後端回傳 canonical `tripId`；新行程維持 `published = 0`。
- 單一行程改用 20／15／13pt 內容層級並提供固定返回行程列表；Header command 與 Day selection 不再混在同一控制列。
- 文字型聊天／行程／收藏使用較實的 navigation material，地圖維持視覺背景材質，避免 Header 前後景文字疊在一起。
- 收藏搜尋改成與行程一覽一致的常駐搜尋欄；新增停留點改用短模式名稱、單一日期欄位與不折行分類列。
- 地圖 POI 卡移除停留進度與箭頭，改顯示起訖時間及本地化分類；滑卡只預覽，點卡片或 marker 才移動地圖。
- Bottom Sheet 依互動語意統一：固定內容不顯示 grabber，只有可調整高度表單顯示。
- 地圖預設進入、切換行程、切換 Day 與點選 Tripline POI 共用固定 zoom `13`；Google 原生 POI 選取仍不移動鏡頭。
- Root Header、底部導覽、DAY selector、POI dock 與功能選單統一使用共用 Liquid Glass recipe；PlatformView 上維持呼叫端指定 blur 與亮邊，不再疊加內層玻璃。
- 行程 Timeline 統一為 D1 `rail｜單一內容欄`，起訖時間固定單行並在空間不足時等比縮小；景點卡與交通列改用中性 surface 加單一 Tripline accent。
- 收藏卡的 POI 類型色退場，leading、heart 與搜尋命中改用同一 Tripline accent；搜尋命中文字渲染收斂為單一共用 widget。

### 修正

- 修正探索、加入景點與替代景點搜尋在清空或快速改字時殘留舊結果，以及 debounce 送出後再次觸發過期查詢。
- 修正 320pt／200% Dynamic Type 下收藏 Header、Timeline 時間與長交通狀態可能溢位或折行破版。
- 修正切換行程重用地圖 state 時未重新對焦，現在即使 days 物件相同也會以 zoom `13` 套用新行程中心。
- 商店上傳不再等待 Firebase／外部裝置證據；TestFlight 與 Google Play internal release 可在裝置報告稍後回補時獨立執行。
- Mobile release 新增 `both` 目標，TestFlight 與 Google Play internal 由同一次 dispatch 取得相同 build number，避免分開執行造成版本序號漂移。

## [0.9.1] - 2026-07-18

### 新增

- 以 Patrol 4.6.1 和 Firebase Test Lab 建立 Android／iOS 外部實機整合測試，GitHub Actions 會在行動版本上傳前收集影片、擷圖、日誌與 JUnit 結果。
- 新增可重現的 Light／Dark、100%／200% Dynamic Type、Reduce Motion 與 Reduce Transparency 自動化 HIG 回歸矩陣，並產出命名的 CI 畫面證據。
- 新增原生 Google Maps 邊界的 Patrol smoke，驗證 map ready、主題切換、路線／marker、zoom 12 與 Google 原生 POI callback。

### 變更

- 行程、聊天、地圖、收藏、帳號與近滿版 Sheet 收旂到共用 HIG／Liquid Glass 元件，地圖引擎改由 `google_navigation_flutter` 與 app-owned adapter 邊界統一管理。

### 修正

- iOS 與 Android CI 共用同一套 Play-safe build number，並切換到新的 TestFlight `0.9.1` 版本序列。
- Android 系統返回鍵會先離開近滿版 Sheet 的內層設定頁，再關閉整個 Sheet。
- 近滿版畫面的系統返回鍵現在會尊重內層未儲存變更，不會在子頁拒絕 pop 時仍關閉整個 Sheet。

## [0.9.0] - 2026-07-17

### 新增

- **Apple Music／HIG 四分頁主流程**：root tab 固定為聊天、行程、地圖、收藏；帳號改為四個主畫面右上圓形 avatar，並保留 `/account` deep link。
- **共用行程切換 sheet**：聊天、行程與地圖的標題直接顯示目前行程；點擊後以含搜尋、目前 checkmark 與最近項目的 bottom sheet 切換。
- **Android closed testing 發佈路徑**：同一套 Mobile workflow 可手動選擇 TestFlight 或 Google Play closed track，並使用各平台獨立簽章與唯一 build number。

### 變更

- **行程／地圖 selector 攤平成單層**：行程頁使用「地圖＋DAY」，地圖頁使用「行程＋DAY」，互切時保留目前天數；筆記收進右上功能區。
- **中性淺／深色系統定版**：Light 使用暖白色階，Dark 使用 Apple 中性深色階，POI、收藏、行程卡與設定列不再以 sage／pink／brown 分類上色。
- **地圖城市尺度與 POI rail 定版**：每日 zoom 固定 12，明確 POI focus 使用 16；所有 POI 卡使用相同 surface，水平露出相鄰卡並避讓浮動 tab。
- **設定頁對齊 HIG grouped list**：外觀與通知改用無外框、無陰影、內縮 separator 的共用設定群組；字級統一使用 HIG semantic roles 與 Dynamic Type。
- **設計文件收斂**：移除過程 SVG、舊三色／五分頁規格與重複計畫，最終 mockup 集中到 `2026-07-17-tripline-final.html`。

### 修正

- 修正水平 selector 在 route branch 尚未完成 layout 時呼叫 `ensureVisible`，造成 deep link／快速切頁測試出現 `RenderBox was not laid out`。
- 修正無座標日期以全行程 bounds 縮成全日本；現在仍以城市尺度 zoom 12 顯示。
- 修正行程切到地圖後 root tab 仍選中「行程」，並補上帳號 deep link 的右上關閉動作。

## [0.8.2] - 2026-07-16

### 修正

- **非同步操作還沒回來就離開頁面會讓 App 崩潰**：時間軸的交通自動重算由畫面建構時觸發，與使用者離開頁面天然競速；地點管理的操作也有同型問題（守衛寫在 `ref.invalidate` 之後，只護到了提示訊息）。兩處丟出的 `StateError` 都不是 `Exception` 子類，現場的 `on Exception` 攔不到，會一路逃成未捕捉例外。
- **地圖鏡頭不遵守系統「減少動態效果」**：POI 卡片已遵守，鏡頭卻一律平移 —— 而鏡頭平移正是最容易誘發動暈的動作。開啟該設定時改為直接切換。
- **OAuth id_token 未經驗證**（開發選項，出貨版本未啟用）：id_token 的 claims 是該模式下唯一的身分來源，先前只解碼不驗證，過期 token 會無限期維持登入。補上 `exp`／`aud`／`sub` 驗證。

## [0.8.1] - 2026-07-16

### 變更

- **路線與 POI 搜尋恢復永續快取**：兩者先前整個排除在快取外（sembast 全載入記憶體，而它們每個 query 都是新 key、無人 evict，會無界成長）。快取層遷到 drift 後前提消失，改為照常快取並給容量上限 100（對齊 web 的 IndexedDB LRU）。重看同一段路線不再重打 Google Directions。

### 修正

- **深色模式啟動會閃白**：launch screen 背景寫死白色，改為隨系統調適的畫布色（對齊 app 的 `#FFFBF5` / `#121214`），並移除自建立以來沒換過的 1×1 佔位圖。

## [0.8.0] - 2026-07-16

### 變更

- **地圖 marker 與路線樣式對齊 web**：POI 由 Google 預設水滴 pin 改為白底圓形 chip + 日色外環與編號，選中者換成柔褐實心並放大；路線改用 web 的 day palette，偶數天虛線、當前段加粗並提高不透明度。web 的 `dayPalette.ts` 本就規定該色盤「僅用於地圖 polyline，不套用到 UI chrome」——先前 Flutter 版把彩虹色填進 pin 是違反自家規則。
- **根頁頁首收斂為 inline 56pt**：移除 large title——它吃掉 96–108pt，內容卻只是重複 tab bar 已經講過的頁名；省下的高度換成同一螢幕多看到一張卡。
- **浮動 tab bar 固定 64pt**：移除捲動縮小與標籤淡出，位置與標籤恆定。
- **快取層由 sembast 遷移至 drift（sqlite）**：sembast 開啟時會把整個 DB 載入記憶體，撐不住 POI 搜尋與 AI 對話歷史等無界增長的資料。既有裝置的離線佇列與衝突區於首次啟動一次性搬遷（回應快取不搬，重抓即可）。

### 修正

- **地圖完全不顯示路線**：單段路線解析丟出的 `TypeError` 不是 `Exception` 子類 → `on Exception` 漏接 → `Future.wait` fail-fast 使整趟路線全滅並卡在無限 spinner。
- **路線重複燒 Google Directions 配額**：同 session 加上 in-memory LRU 快取（容量 100，對齊 web 的 IndexedDB LRU）。
- **認證卡片寬度漂移**：login 寫死 400、`_AuthScaffold` 寫死 420，在登入與忘記密碼之間切換時卡片會橫向跳動。

## [0.7.0] - 2026-07-15

### 新增

- **V3 中性深色系統**：全 app 共用中性深色 canvas／surface、柔褐 accent、單行 AppBar、scope menu 與浮動五分頁幾何，取代各頁自管的導覽 chrome。
- **編號 POI 橫向 rail**：地圖停留點改為 84% 寬度的水平分頁卡；沒有圖片時以 marker 同號 badge、停留順序、名稱、時間與位置狀態呈現，marker 與卡片雙向同步。

### 變更

- 行程、地圖與筆記共用單一 scope menu；移除重複的 DAY tabs 與次級導航按鈕，POI 不再提供垂直展開、收合或 detent。
- 根內容與地圖 accessory 共用實際五分頁高度及 iPhone bottom safe area；135% 以上 Dynamic Type 使用固定 accessibility rail。

### 修正

- 修正跨天總覽 marker 編號重複、長行程 page dots 溢出、scope 與定位按鈕重疊、POI VoiceOver 重複朗讀，以及 200% 長標題擠壓工具列。

## [0.6.0] - 2026-07-14

### 新增

- **自適應導覽與寬版版型**：五個 branch 共用 `AppleRootTabBar` 浮動根分頁並隨垂直捲動縮合；表單、對話與 feed 新增角色式最大寬度。
- **Liquid Glass 與原生地圖**：根分頁改為 Apple 式浮動功能層，地圖由 `flutter_map`／OSM 遷移至原生 Google Maps，支援路線 polyline、marker 與卡片同步。
- **持續錯誤與版型載入狀態**：真正錯誤改用可關閉、可重試的 persistent banner；列表、地圖、時間軸與主要 route 補齊靜態 skeleton 與載入 semantics。
- **地圖 accessibility**：marker 擴為 44pt 互動目標，加入 POI 類型 icon、語意標籤與定位失敗重試。
- **AI owner 授權流程**：建立行程與已連結應用共用授權卡；聊天首次送出前顯示原生 consent sheet，取消時保留草稿，授權成功後才送出原訊息。
- **細分類探索**：Google Places `primaryType` 顯示 zh-TW 細分類，探索頁依結果動態聚合、排序與精確篩選，超過四類時改用原生 action sheet。
- **Tripline 座標 App Icon**：保留定位圖釘與中央指南針箭頭識別，提供 iOS Default/Dark/Tinted 與 Android density 資產。
- **設計系統文件**：補齊 Apple Music/Apple HIG 對標理由、Flutter 自適應 UI reference 與新增畫面指南。

### 變更

- **Apple Music 式內容階層**：強化行程清單 CTA、時間軸 More 選單與 active day 捲動同步；收藏改為明確選取/完成與批次工具列，建立行程改為漸進揭露。
- **系統排版與動態效果**：移除自訂 Inter 依賴方向，改用平台系統字、HIG 字階、中文零字距、Dynamic Type 與 reduced-motion duration。
- **單一支援語系**：現階段明確限制為 `zh-TW`，避免介面宣告尚未完成的語系。
- **回饋分級**：成功與低風險狀態保留短暫 notice；載入、定位、搜尋與 mutation 失敗改為持續可見的錯誤介面。

### 修正

- 修正寬螢幕內容過度延伸、route 載入只顯示 spinner、空狀態缺少下一步，以及 rebase 後未使用的 loading/timeline state。
- 修正 AI 授權狀態查詢期間快速連點會重複開啟 consent sheet，並讓所有自訂動畫與時間軸捲動確實遵守系統「減少動態效果」。

## [0.5.1] - 2026-07-14

### 新增

- **Tripline App Icon**：加入木棕色主圖示、深色與灰階版本，並套用至 iOS 與 Android。

## [0.5.0] - 2026-07-10

### 新增

- **iOS 原生化(對標 Apple HIG)**:全 app 互動層改平台自適應。
  - 互動層:對話框/破壞性確認、action sheet、頂部通知橫幅、`.adaptive` spinner/switch、全程 `HapticFeedback` 觸覺回饋(平台自適應 helper 集中在 `lib/app/adaptive.dart`)。
  - 導航:行程清單/收藏/帳號改 iOS large title(`SliverAppBar.large`);帳號設定改 grouped inset list。
  - 輸入:登入 email/密碼支援 iOS Keychain 自動填入(`autofillHints` + `AutofillGroup`);搜尋列改 `CupertinoSearchTextField`(adaptive);聊天輸入列改 iMessage 圓角膠囊。
  - 下拉更新改 `RefreshIndicator.adaptive`(iOS Cupertino 轉圈)。
  - 圖示改 CupertinoIcons(交通模式與少數無對應者保留 Material);字型改系統字(iOS SF Pro、CJK 由系統 PingFang/Noto fallback,拿到真 Dynamic Type)。

- **公開分享頁補齊**:`/s/:token` 可未登入瀏覽公開行程、查看 days/notes 摘要,登入後可複製到自己的帳號。
- **列印與 PDF 預覽**:行程詳情新增列印頁,可預覽每日行程、筆記摘要並分享/輸出 PDF。新增 `pdf`、`printing` 依賴。
- **JSON 匯入/匯出**:行程清單支援 web 相容 `schemaVersion:1` JSON import/export,含 days、segments、notes。新增 `file_selector` 依賴。
- **帳號安全與 OAuth 設定**:新增登入裝置管理(`/account/sessions`)、已連結應用撤銷(`/account/connected-apps`)、開發者 OAuth app 清單/建立(`/dev/apps`)與 OAuth consent shell route(`/oauth/consent`)。
- **通知設定頁接上偏好 API**:Account「通知」row 轉正,`/settings/notifications` 與 web 相容 `/account/notifications` route 會讀寫 backend `/account/notifications` preferences,可分別切換行程更新、旅伴邀請、系統通知。
- **地圖 adapter**:新增 `features/map/map_adapter.dart`,集中 `flutter_map` 轉接層;`TripMapScreen` 與 `GlobalMapScreen` 改走 adapter,保留日後替換地圖 SDK 的空間。
- **帳號建立與復原流程**:補齊 web 相容 `/signup`、`/signup/check-email`、`/login/forgot`、`/auth/password/reset`、`/auth/verify-email` route,支援註冊、重寄驗證信、忘記密碼、重設密碼與 email 驗證。
- **編輯行程日期與天數管理**:`EditTripScreen` 補齊 web 相容出發日期平移、day 摘要、加到最前/最後、補回中間缺漏日期與刪除 day,呼叫 `/trips/:tripId/days`、`/days/:dayNum`、`/days/shift` 並刷新行程詳情、清單與日程快取。
- **AI 行程健檢頁**:新增 `/trips/:tripId/health` 與 web alias `/trip/:tripId/health`,可查看既有 AI findings、POI closed/missing 摘要、啟動/重新生成健檢,並在空行程時阻擋送出。
- **行程異動紀錄頁**:新增 `/trips/:tripId/audit` 與 web alias `/trip/:tripId/audit`,可查看 audit log 摘要、diff 欄位並對非錯誤記錄執行確認式 rollback。
- **行程筆記 AI 生成**:`TripNotesScreen` 補齊行前須知（一般/住宿）與緊急聯絡 AI 生成入口,改打 web/backend 支援的 `tips`、`lodging-tips`、`emergency` doc type,並透過 `/requests/:id/events` SSE 完成後自動刷新筆記。
- **停留點 web route 相容**:新增 `/trips/:tripId/entries/:eid/edit|copy|move` 全頁入口,並支援 web alias `/trip/:tripId/stop/:entryId/edit|change-poi|copy|move`；`change-poi` 地點管理可用搜尋或收藏置換正選 POI / 加入備選,並支援備選排序。
- **新增停留點 deep link**:新增 `/trips/:tripId/entries/new?day=N` 全頁新增入口,支援搜尋 POI、收藏景點或自訂停留點；web alias `/trip/:tripId/add-entry|add-stop|add-custom-stop?day=N` 會進對應模式,`/trip/:tripId/add-stop?tab=favorites&day=N` 會進收藏景點模式,搜尋模式會保留 `region` query 並送進 POI 搜尋；搜尋/收藏模式皆支援 web 相容分類篩選與多選後批次加入,搜尋 POI 加入前會 resolve Place Details 生成營業/消費/地址備註,選取後可覆寫單筆 POI 分類；自訂停留點可設定 POI 分類與座標。
- **Legacy route redirects**:支援 web 保留路徑 `/admin` → `/trips`、`/manage` → `/chat`。
- **地圖停留點 deep link**:`/trip/:tripId/stop/:entryId/map` 會導到 `/trips/:tripId/map?entry=:entryId`,並在地圖初始顯示該停留點所在日。
- **時間軸停留點 deep link**:`/trip/:tripId/stop/:entryId` 會導到 `/trips/:tripId?entry=:entryId`,並在時間軸初始捲動與標示該停留點。
- **Web selected/focus deep link**:支援 `/trips?selected=:tripId&focus=:entryId`,會導到 Flutter canonical `/trips/:tripId?entry=:entryId`。

### 修正

- POI 分類顯示對齊 web:純中文/假名 curated 分類（如「沖繩麵」「すし」）保留原樣,英文 Google primaryType 顯示為 8 類中文 label,避免探索卡與時間軸誤顯「景點」或外露 `tourist_attraction`。
- 更新 reorder callback 參數名稱,對齊目前 Flutter SDK 的 `onReorder` API。
- 登入 return-to flow 會消費安全的站內 `redirect_after`,公開分享頁登入後可回到原分享頁；外部 redirect 會被忽略。

## [0.4.0] - 2026-06-16

行程清單名稱排序 + 聊天語音指令(本 repo 可做的 web parity 後續)。

### 新增

- **行程清單排序**:預設順序 / 名稱 A→Z,與搜尋並存。(web 的「最新編輯/出發日」需後端 `/my-trips` 回 `updatedAt`/`startDate`,暫不支援。)
- **聊天語音指令**:聊天輸入加麥克風語音轉文字(`speech_to_text`),對齊 web「輸入訊息或語音指令」。**lazy 權限**(點麥克風才請求),辨識文字回填輸入框沿用送出。新增 iOS `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription`、Android `RECORD_AUDIO`。

## [0.3.0] - 2026-06-15

離線寫衝突解決 + web 對齊:離線 OCC rebase(三方 merge)、時間軸資訊密度補齊、行程清單搜尋、聊天建議引導。

### 新增

- **離線寫 OCC 409 三方 merge rebase**:離線編輯重連 flush 遇 `STALE_ENTRY` 時自動 **dirty-aware 三方 merge**(只比對/重送使用者改過的欄位)→ 無真衝突靜默 rebase、真衝突進持久化 conflict store + banner 點開 bottom sheet 整筆二選一(保留你的 / 用對方的)。不丟資料:重抓/重送離線保留、`newVersion` 缺失當衝突、row 被刪上報;換帳號/登出一併清 conflict store。範圍 `entry.update` + `note.update`。新增 `rebase_merge.dart`(rebaseMerge / dirtyFields / entry|note 欄位擷取)、`ConflictRecord` + conflict store(Sembast)、`_send` writeCache 參數。
- **時間軸資訊補齊(對齊 web 手機版)**:交通段顯示距離 km(`travel.distanceM`)、當日總覽「N 個停留點 · 總距離 km」、景點停留時長、**注意事項卡**(POI 營業時間早於提醒,移植 web `validateDay`)、entry 編號 + 當日時間範圍。
- **行程清單搜尋**:本地 filter(名稱 / 標題)。
- **聊天空對話引導**:「從一個指令開始」+ 4 個建議 prompt 快捷鈕。

### 變更

- `AuthNotifier` 換帳號 / 登出清快取一併清 conflict store(沿用 `__cache_owner__` owner-check)。

## [0.2.0] - 2026-06-15

P1 + P2 收斂發版:收藏/探索、Entry CRUD、筆記 CRUD、AI 聊天、建立/編輯行程、全域地圖、共編邀請、設定子頁、分享連結、OAuth PKCE(就緒待啟用)、離線快取(讀寫同步)。

### 新增

- **`--dart-define=TRIPLINE_API_ORIGIN`**:build/run 時覆寫 API origin(本機後端開發),預設仍為正式站;同一 origin 同時驅動 base URL 與 CSRF Origin header。新增 `docs/howto-local-backend.md`。
- **測試補強**:trip_detail widgets(DayHeader/DayPills/HotelCard/TravelPill/TimelineEntryTile/entry_tone 色階)、TripCard、AppShell 5-tab 導航、跨畫面流程(登入＋瀏覽)、`integration_test` device smoke(iOS 模擬器驗證通過)。
- **收藏清單**:favorites tab 轉正 — `GET /poi-favorites` 渲染(名稱/類型 tone/評分/note/用於 N 個行程)+ heart 取消收藏(確認對話框 → `DELETE`)。POI 類型→tone 對應抽到共用 `lib/theme/poi_tone.dart`。
- **探索（ExploreScreen）**:收藏 tab 新增入口 — poi-search 搜尋（防 race）+ region/分類 filter（為你推薦/景點/美食/住宿/購物）+ 4 狀態 + auto-search seed + heart 收藏 toggle（find-or-create → favorite）。POI 類型映射 `mapGooglePrimaryTypeToPoiType`;`ApiClient.get` 支援 CancelToken。
- **加入行程（AddToTripScreen）**:收藏/探索 POI → 選 trip/day/時間加入行程（favorite mode `POST /poi-favorites/:id/add-to-trip` + direct mode `POST /trips/:id/days/:num/entries`）;409 時段衝突對話框。`ApiError` 加 `payload` 保留原始 body 供 conflictWith。
- **Entry CRUD（時間軸停留點）**:編輯/刪除/新增自訂停留點、同日拖曳排序 + 跨天搬移、地點管理全頁（正選切換／備選增刪排序／per-POI 備註·分類·訂位／POI 搜尋）、交通方式編輯（開車·步行重算／大眾運輸手動）。三套 OCC:entry `version`(meta)、`entryPoisVersion`(POI 結構)、segment `version`(交通),409 `STALE_ENTRY` 重抓。新增 `TripSegment` model。
- **行程筆記 CRUD**:筆記 5 區（航班/住宿/預訂/行前須知/緊急聯絡）由唯讀轉可新增/編輯/刪除 + 每區拖曳排序。吃後端「5 區共用泛型引擎」→ client `NoteSection` + 泛型 repository + spec-driven `NoteEditSheet`（一個表單服務 5 型）。OCC `expectedVersion`,409 `STALE_ENTRY`。
- **AI 聊天（行程助手）**:chat tab 由 placeholder 轉正 — 工單佇列模型（`POST /api/requests` 建單 → 外部 worker 填 reply）+ polling 到終態 + markdown 回覆（deep-link `/trip/:id/*` 映射成 app `/trips/:id/*`）。頂端行程下拉（預設最近）、樂觀送出、三方氣泡（自己/協作者/AI）、亂碼防護。**completed 後 invalidate 行程相關 providers**（AI 直接改行程,畫面才看得到）。新增 `TripRequest` model、`RequestsRepository`、`ChatController`(`NotifierProvider.autoDispose.family`)、`flutter_markdown_plus` 依賴。
- **建立／編輯行程**:行程清單可建立（目的地優先 POI 搜尋 + 固定/彈性日期模式 + 每地天數分配,送出衍生 `name`/`id` slug/`countries`）與編輯（PUT 欄位:目的地/標題/描述/語言/發布,明確儲存鈕,無 OCC,不動日期）。新增 `DestinationInput`、`trip_form_logic`(slugify/genTripId/日期推算)、`createTrip`/`updateTrip`、共用 `DestinationPicker`、`flutter_localizations`(zh-TW 日期)。入口:清單 FAB / 詳情 AppBar。
- **全域地圖**:map tab 由 placeholder 轉正 — 收藏 POI（`GET /poi-favorites`）跨行程畫在 `flutter_map`,依 poi_type 上色,點 marker 顯示名稱/評分/所屬行程。（web 的 /map 實為導回單行程地圖的 dead code;此為真正的跨行程地圖。）
- **共編邀請**:成員管理 — 已授權成員（改角色 member↔viewer / 移除）+ 待接受邀請（撤銷）+ 新增成員（email + 角色）。`/api/permissions` + `/api/invitations`;owner/admin 限定管理(他人顯示提示)、owner/admin 列不可改不可移除。新增 `TripMember`/`TripInvite`、`CollabRepository`、`CollabController`。入口:清單長按 sheet「共編設定」。
- **設定子頁**:帳號設定轉正 — **外觀**(主題 跟隨系統/淺色/深色,client 端持久化,`themeModeProvider` 接 `MaterialApp.themeMode`)+ **個人資料編輯**(displayName → `PATCH /account/profile` → invalidate authState)。新增 `SettingsStore`、`ThemeModeController`、`AppearanceScreen`、`ProfileEditScreen`(`/settings/appearance`、`/settings/profile`);Account「外觀/個人資料」row 由 placeholder 轉正(通知仍 coming-soon)。MVP:sessions/connected-apps/通知 延後。
- **分享(公開連結)**:為行程建立/管理唯讀公開分享連結(`trip_shares`)— 列出(label/狀態/瀏覽次數)、建立(顯示完整 `<origin>/s/<token>` URL + 複製,raw token 只回一次)、撤銷(二次確認)。`GET/POST /trips/:id/shares`、`PATCH .../:shareId {action:'revoke'}`;owner/editor 可管理(viewer 提示)。新增 `TripShare`/`ShareLink`、`ShareRepository`、`ShareController`。入口:清單長按 sheet「分享」。MVP:expiry/sections/anonymous/rotate 延後。
- **OAuth 2.1 PKCE + Bearer 認證（client 端,就緒待啟用）**:實作 native app 的 authorization-code + PKCE-S256 流程,取代「session cookie + 偽造 Origin」過渡方案。新增 `pkce`、`OAuthTokens`、`OAuthRepository`(authorize URL / token / refresh)、`OAuthTokenStore`、`OAuthLoginService`(RFC 8252 loopback);**`ApiClient` 新增 Bearer 模式**(有 token → 帶 `Authorization`、不送 Origin、401 自動 refresh-retry;無 token → 回退 cookie)。client_id/redirect 由 `--dart-define` 注入,**僅在設定後啟用**(預設仍 cookie,零破壞)。deps:`crypto`、`url_launcher`。**e2e 待 backend owner provision 一個 active public client**(見 `docs/howto-oauth-pkce.md`)。

### 變更

- `kTriplineOrigin` 由固定常數改為 `String.fromEnvironment`(預設值不變,既有測試零破壞)。
- `docs/PORTING_PLAN.md`:dart-define 覆寫由 `TRIPLINE_API_URL` 更正為 `TRIPLINE_API_ORIGIN`(origin 語意)。
- **favorites review cleanup**:收藏比對改「名稱」單一 key（消除 server poiType 與 client category 映射不一致致取消收藏失效）、AddToTripScreen 改純讀 fallback + 「結束晚於開始」驗證 + 送出守門、router add-to-trip 對遺失 extra 改 redirect 防 crash;移除 dead code `AddToTripResult`、`poi_type` RegExp 提升檔案層級、抽共用 `PoiRatingLabel` 與 `reorderedSortOrders`。
- **過時文案清理**:收藏空狀態移除「(即將推出)」(探索功能早已上線),改為「去探索」按鈕直達 `/favorites/explore`;校正 `AccountScreen` 設定群組過時註解(外觀/個人資料已可用,僅通知為即將推出)。

## [0.1.0] - 2026-06-10

P0 里程碑:trip-planner 的 iOS/Android 唯讀版可用 — 登入後能瀏覽自己的行程、逐日時間軸、地圖與筆記,資料與 web 版完全同步(共用同一套後端)。

### 新增

- **登入**:email/密碼登入,session 以 flutter_secure_storage 持久化,重開 app 免重登
- **5-tab shell**:聊天/行程/地圖/收藏/帳號底部導航,各 tab 保留瀏覽狀態;未登入自動導向登入頁
- **行程清單**:三色 tone 卡片、下拉更新、長按刪除(二次確認)
- **行程時間軸**:day pills 換日、逐日 timeline(三色 POI tone、travel pill、hotel 卡)
- **行程地圖**:flutter_map + OSM(免 API key)、逐日 pin 配色、day tabs 與 entry cards 同步
- **行程筆記**:航班/住宿/預訂/行前/緊急聯絡 5-section accordion(唯讀)
- **帳號**:profile、行程統計、登出
- **基礎層**:design tokens + light/dark 雙主題、手寫 fromJson models、dio API client(cookie 認證、CSRF Origin、429 retry、204 處理)
- **測試**:TDD 全程,144 tests(models 解析/API client 行為/widget)

### 文件

- Diataxis 四象限文件 9 篇(新手教學、3 篇 how-to、4 篇 reference、架構說明),README 文件索引
- 專案 CLAUDE.md(agent 開發指南)
- PORTING_PLAN/CONTRACTS 與實作同步(riverpod 3.x、歷史契約標註)

[Unreleased]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.9.6...v0.10.0
[0.9.6]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.9.5...v0.9.6
[0.9.5]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.9.4...v0.9.5
[0.9.4]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.9.3...v0.9.4
[0.9.3]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.9.0...v0.9.1
[0.1.0]: https://github.com/raychiutw/trip-planner.flutter/releases/tag/v0.1.0
