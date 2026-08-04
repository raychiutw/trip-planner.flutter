# Tripline

trip-planner React SPA 的 iOS/Android 移植版。這份文件只定義本專案的共同語彙 —— 同一個東西有多種叫法時,挑一個,其餘列在 _避免_。實作細節不寫在這裡。

## 導覽外框(chrome)

**浮動 header**:
浮在內容之上、左右內縮、圓角玻璃的頂部列,由 `TpRootScaffold` 提供,只用於 root 分支畫面(聊天、行程列表、時間軸、行程地圖、總覽地圖、收藏)。
_避免_: app bar、標題列、導覽列

**固定 bar**:
貼齊頂端、佔滿寬度的傳統頂部列,由 `TpAppBar` 提供,用於 detail 與 modal 畫面。
_避免_: app bar、toolbar

**bar button**:
浮動 header 或固定 bar 上的單一動作,呈現為圓形玻璃按鈕。
_避免_: toolbar icon、header icon、action button

**動作群組**:
共用同一片玻璃容器的多個相關 bar button,彼此**僅以間距分隔,不畫分隔線**。不相關的動作(例如帳號)另起一顆容器。一列最多約三組。
_避免_: action row、button group

註:選單**內部**的分組分隔線是另一回事,那屬選單語彙,HIG 明文允許。

**root tab bar**:
底部四個一級分頁(聊天 / 行程 / 地圖 / 收藏)的玻璃列。
_避免_: bottom nav、navigation bar

**bottom accessory**:
貼在 root tab bar 上方、與 tab bar 分屬兩層的常駐控制列。同一畫面最多一個。
_避免_: 底部工具列、bottom bar、floating bar

**聊天 composer**:
聊天頁那條常駐的 bottom accessory:左側 `＋`、中間輸入框、右側麥克風與送出。草稿屬於行程,切走再切回要恢復。
_避免_: 輸入列、input bar、訊息框

## 內容控制項

**日期選擇器**:
時間軸與地圖上方那條水平捲動的天數切換列(Day 1、Day 2…),由 `TpHorizontalSelector` 提供。
_避免_: day tab、日期 tab、segmented control

**選單**:
由 bar button 或卡片上的「⋯」觸發、由觸發點展開的下拉動作清單(對應 iOS pull-down menu)。
_避免_: popup menu、dropdown、context menu(後者專指長按觸發的那一種)

**行程切換鈕**:
浮動 header 標題位置的按鈕,點擊後開出切換行程的 sheet。
_避免_: title button、trip picker

**行程 POI accessory**:
地圖頁的 bottom accessory:一列橫向捲動的行程 POI 卡片,與地圖 marker 雙向連動。
_避免_: bottom sheet、POI carousel、卡片抽屜

## 視覺語彙

**tint**:
品牌柔褐,唯一的品牌強調色。用於前景 —— 文字、字符、選取指示。不畫成框線。

**沒有例外 —— tint 一律在前景。** 包含 root tab bar 的選取膠囊:膠囊本身走中性語意層,
tint 上在字符與標籤。這與 iOS 26 一致 —— 「電話」app 通話記錄分頁的選取膠囊實測是
`#363636`(中性灰,比容器亮約 20 階),字符與標籤才是系統藍。
見 `docs/adr/0004-neutral-selection-surface-with-tinted-foreground.md`。
_避免_: 主色、primary、強調色

**中性語意層**:
跟隨 iOS 系統語意層級的表面色(`surface` / `surfaceContainerLow` / `surfaceContainerHigh`)。所有內容表面與玻璃底色都走這一層。
_避免_: 背景色、surface color

**媒體背景**:
玻璃底下是照片或地圖圖磚的情境。此時 bar button 字符走白 / label 色,而非 tint。
_避免_: platform view 背景、透明背景

**帶狀遮蔽**:
浮動 header 佔的那一整條帶(從畫面最頂含狀態列,到膠囊下緣再多一小段羽化),對**底下捲過去的內容**做漸進模糊與淡出。它畫在內容與膠囊之間,所以膠囊自己不糊;也不吃觸控。
_避免_: 柔邊、soft edge、scrim、遮罩

## 行程資料

**停留點**:
時間軸上的一個停留 —— 一段時間加一個地點。可以是景點,也可以是旅館、機場或休息站。
_避免_: 景點、entry、stop、行程項目

**正選 POI**:
一個停留點當前生效的那個地點。程式碼識別字是 `master`。
_避免_: 主要 POI、primary POI、主 POI

**備選 POI**:
同一個停留點上除正選以外的候選地點,備而不用。程式碼識別字是 `alternates`。
_避免_: 替代景點、候選清單、alternates

**行程 POI**:
已加入某個行程某一天的地點,在地圖上以編號 marker 呈現。
_避免_: 景點、地標

**外部 POI**:
來自地圖圖資、尚未加入行程的地點。與行程 POI 是兩種來源,UI 上不共用同一種卡片。
_避免_: 地圖 POI、第三方 POI

**移動段**:
兩個相鄰停留點之間的移動 —— 方式、時間、距離。由後端組裝,不是使用者輸入。
_避免_: segment、交通、路線

**行程筆記五區**:
航班、住宿、預訂、行前須知、緊急聯絡 —— 行程筆記固定就這五區,不多不少。
_避免_: notes section、附註

## 聊天

**工單**:
聊天送出的一則訊息在後端是一筆工單,由外部 worker 非同步處理後回填答覆。不是對話式 API,沒有多輪記憶;一張工單等於一組提問與回覆的交換。per-trip,同行程的協作者共享同一串。
_避免_: 行程請求、對話訊息、chat message、prompt

**思考中**:
工單尚未回填答覆時顯示的 AI 氣泡占位。等待可長達數十分鐘,不設短 timeout 放棄。
_避免_: loading、pending reply

## 離線

**stale 與 fresh**:
同一次讀取的兩段式發射 —— 先吐本機快取(stale),背景抓到網路資料後再吐一次(fresh)。畫面的同一個 `AsyncValue` 會收到兩次 data。
_避免_: 舊資料與新資料、cache hit

**離線佇列**:
離線期間寫入操作排入的本機序列,重連後依序重播。
_避免_: mutation queue、pending queue、待同步清單

**樂觀 patch**:
寫入操作入隊時就地改寫相關快取的純函式,讓離線編輯立刻可見。
_避免_: optimistic update、本地更新

**線上限定**:
不進離線佇列的操作(排序、移動段、行程與 Day 結構、收藏、搜尋、AI)。離線時必須說明原因,不得假裝已成功。
_避免_: 需要網路、online-only

## 動作動詞

四個詞在 UI 文案與 code review 都要嚴格分開,不可互換。

**新增**:
建立原本不存在的資料(行程、Day、筆記、自訂停留點)。
_避免_: 建立、create、加入

**加入**:
把既有資料關聯到另一個範圍(收藏加入行程、地點加入備選)。
_避免_: 新增、添加、add

**移除**:
解除一段可以重新建立的關聯(取消收藏、移除備選、移除共編成員)。
_避免_: 刪除、remove

**刪除**:
永久銷毀使用者資料(行程、Day、停留點、筆記、分享連結)。不可復原,一律先確認。
_避免_: 移除、清除、delete

註:唯讀的「異動紀錄:新增 / 刪除」是事件名稱,不是可點擊的動作,不套本節規則。
