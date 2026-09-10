---
status: accepted
supersedes: 0003-brand-tint-for-root-tab-selection.md
---

# 選取指示一律是「中性底 + tint 前景」,導覽 chrome 每個控制項各自成膠囊

取代 [ADR-0003](0003-brand-tint-for-root-tab-selection.md)。

> **2026-09-09，#303／#304 更新**：中性表面、tint 前景與媒體背景語意仍有效。
> 共用材質改採 liquid_glass_widgets 1.4.1 公開預設，撤銷第 5 節及其後續實作中
> 只為舊 shader 邊緣強度而調整 Fresnel、光照、色散、折射率與 blur 的要求。
> 以下量測與更正史保留供追溯，不是新版的校準目標。一般模式不另畫邊線，提高
> 對比才補明確邊界；提高對比與降低透明度各自使用不透明、無 shader 降級。
> 第 3 節的 root tab 70% 膠囊與自畫選取層已由 #305 移除；套件接手選取繪製與指標互動。
> 日期選擇器已由 #306 改用 `GlassSegmentedControl.scrollable`，移除自畫膠囊及手算欄寬／中心。
> 下方 #169 的自畫選取填色理由僅保留歷史脈絡，不再是目前實作要求。


## 為什麼推翻 ADR-0003

ADR-0003 主張 root tab bar 的選取膠囊該用品牌柔褐鋪底、字符反白,論據是:

> iOS 26「電話」app 的 tab bar 選取態是強調色實心底 + 反白字符 + 強調色標籤
> —— Apple 自己就拿強調色當選取背景。

**這個論據經像素實測為錯誤。** 對 iOS 26「電話」app 通話記錄分頁的截圖做水平掃描
(y = 圖示列中央):

| x | 值 | 是什麼 |
|---|---|---|
| 60–236 | `#16`–`#28` | tab bar 容器(值持續變動 = 內容從玻璃透出) |
| 308 | **`#363636`** | 選取膠囊起點 —— 中性灰,比容器亮約 20 階 |
| 378 | **`#4D8DE3`** | 時鐘字符 —— 系統藍 |

標籤同樣是系統藍(`#5EACF7`)。**強調色在前景,不在背景**,與 ADR-0003 的描述正好相反。

ADR-0003 當時是為了推翻 #118 而寫,理由是「#118 把『Apple 不這樣做』當成事實」。
實際上 #118 的方向是對的,它缺的只是證據;ADR-0003 則用了一個同樣未經驗證的反向斷言
去推翻它。**兩份文件犯的是同一個錯:用沒量過的斷言當前提。**

ADR-0003 關於「HIG 沒有規定選取指示的形狀或配色」的觀察仍然成立,那部分不受影響 ——
本 ADR 選中性底不是因為 HIG 規定,而是因為那是 Apple 實際的做法,而本專案的目標是
對齊 iOS 26 的觀感。

## 決定

### 1. 選取指示:中性底 + tint 前景

適用於 root tab bar 與所有選取指示。膠囊本身走中性語意層,品牌柔褐上在字符與標籤。

`CONTEXT.md` 的「tint 只用於前景」因此**回到沒有例外**的狀態。

順帶修掉兩個實測發現的問題:

- 選取字符先前是 `onPrimary`(純黑 `#000000`)坐在柔褐膠囊上 —— 低對比且顯髒。
- 選取標籤先前是 `primary`,與它所坐的膠囊底**同一個色相**。

### 2. 未選取的字符與標籤同色

實測我們的未選 icon 是 `#919197`(中灰)、label 是 `#F9F9FB`(近白)—— 同一顆 tab
裡兩者不一致。Apple 兩者都是近白(`#F7F7F8` / `#F6F6F6`)。統一為近白;未選態靠
「沒有膠囊」與「不是 tint」區分,不靠變淡。

### 3. root tab 選取指示交由套件繪製（#305 取代舊比例決策）

2026-09-09，母規格 #303 已同意採 Liquid Glass 1.4.1 的預設幾何與互動。
root tab 移除 70% 自畫膠囊、activeIcon 疊層、負 indicatorExpansion、tabPadding
對齊補償及模擬套件文字高度的 TextPainter。選取填色使用公開 indicatorColor
指定中性語意色，字符與標籤保留品牌 tint；媒體背景與無障礙降級沿用共用配方。

仍保留兩項薄整合：

- 套件 1.4.1 的 TabBarBottomLayout 對 BottomBarTabItem 傳入 `onTap: null`，
  使內容的鍵盤啟用沒有回呼。App 提供指標可穿透的鍵盤／讀屏區域，排除套件重複
  focus／semantics；真正的觸控與拖曳仍由套件處理。branch 換頁後恢復目前 tab 焦點。
- 套件固定 barHeight 會讓 300% 文字再次縮小；App 明確指定 label typography，
  只依這份 App 自有字級與間距增加公開 barHeight，並同步 shell、內容與 accessory
  佔位。不讀取或反推套件內部文字、選取膠囊與裁切幾何。

測試改驗實際選取填色與移動、文字邊界、44pt 觸控區、selected semantics、點選、
拖曳、讀屏、Tab／Shift-Tab、Enter／Space 及分支狀態；不再把舊比例當作契約。
以下保留 0.x 時期的量測與選擇，作為歷史脈絡：

#### 舊決定（已被 #305 取代）

`GlassTabBar` 的 `indicatorExpansion` 預設 `horizontal: 12`,我們未曾覆寫,結果膠囊
比自己的欄位還寬(實測欄寬 275px、膠囊 341px = **124%**),溢出到左右鄰居。
Apple 約 70%。

### 4. 導覽 chrome:每個控制項各自成膠囊

Header 從「一顆 64pt 玻璃膠囊包住標題 + 切換 + `⋯` + 頭像」改成**每個控制項各包一顆**
—— 返回、標題(含 chevron)、`⋯`、頭像各自獨立,中間的空隙直接透出內容。

依據是 iOS 26「訊息」app:`‹ 121`、頭像、`roybee903@icl… ›`、視訊鈕四個各自成膠囊。
標題**保留**且包在自己的膠囊裡 —— 這同時解決了「釘住的純文字標題會與捲上來的內容
重疊」的問題,不需要拿掉標題。

控制項全部釘住,內容從膠囊下方與空隙之間捲過。

> **本項的分組粒度已更正,以下是更正後的版本。** 原文寫成「返回、標題(含 chevron)、
> `⋯`、頭像各自獨立」四顆膠囊,實作是**三顆:返回鍵與標題共用一顆,動作與頭像
> 各自一顆**。

`lib/ui/tp_root_scaffold.dart:143`–`193` 把 `config.leading` 與標題包進同一個
`TpGlassSurface`,程式碼註解就寫在 `lib/ui/tp_root_scaffold.dart:136`:「返回鍵與標題是
**同一組**,包在同一顆膠囊裡」。右側的 `TpHeaderActionRow`
(`lib/ui/tp_root_scaffold.dart:195`)只是帶間距的 `Row`,動作與
`TpAccountAvatarButton`(`lib/ui/tp_root_scaffold.dart:214`)各自是一顆玻璃圓鈕。

依據仍是同一張 iOS 26「訊息」app 參考,只是讀法修正了:`‹ 121` 是**一組** —— 返回字符
與它所屬的內容同屬一顆膠囊,不是兩顆各自浮著。原文把那一組數成了兩顆。本項的決定
(「不是一整片玻璃板、每組各自成膠囊」)不變,變的只是「一組」的邊界在哪。

這個粒度與 `CONTEXT.md`「動作群組」的定義相符:相關的 bar button 共用一片玻璃容器,
不相關的(帳號)另起一顆 —— 返回與標題相關,頭像不相關。

### 5. 玻璃邊緣做回來,強度用 Apple 的量級

> **本項已於 #169 更正兩次,以下是更正後的版本。** 原文的「材質完全不產生邊緣」是
> **模擬器**的結論,真機不成立;更正紀錄見本節末尾的「更正史」。

實測「邊緣峰值高出內部填色」的差值:

| | 邊緣高出填色 | 量在哪 | 沿邊緣是否均勻 |
|---|---|---|---|
| iOS 26 訊息 標題膠囊 | **+28 ~ +33** | 真機截圖 | 是(x 360→810 全程一致) |
| iOS 26 電話 編輯膠囊 | **+29** | 真機截圖 | 是 |
| Tripline 標題膠囊 / 頭像圓鈕(v0.13.0) | **+125 ~ +138** | **真機** | 是 |
| Tripline DAY tab 軌(v0.13.0) | **+20 ~ +31** | **真機** | 是 |
| Tripline 標題膠囊(同一版) | **0** | **模擬器** | —(量不到邊緣) |

同一個 build,模擬器量到 0、真機量到 +125。差距全部來自材質:**模擬器不渲染
LiquidGlass 的材質邊緣光**。

修法分成兩層,對應兩個獨立的來源:

1. **畫上去的細邊**(`TpGlassEdge`,`onSurface` @ 12%)。這一層模擬器與真機一致 ——
   DAY tab 軌只有這一層,真機量到 +20~+31,恰好落在 Apple 的量級。保留。
   顏色由 `onSurface` 低透明度導出,讓兩種明暗模式各自得到可見的邊界(深色是偏亮的
   細邊、淺色是偏暗的細邊),而不是寫死白色 —— 淺色模式的填色本來就接近白,再加
   白邊等於沒有。
2. **材質自身的邊緣光**。真機上這一層就是 +125 的來源。#169 依 30/125 的比例調降
   `ambientRim`／`glowIntensity`,**但該調整值未經真機確認**。

   而且 #169 讀套件原始碼(0.22.1)發現:在 `GlassQuality.standard` 下,
   `shaders/lightweight_glass.frag` **沒有 `ambientRim` 這個 uniform**,
   `uGlowIntensity` 取的也是 `LightweightLiquidGlass` 的 widget 欄位而非
   `settings.glowIntensity`;該 shader 的邊緣來自硬寫死的 `kRimAlphaBase = 0.65`、
   `kMinRimVisibility = 0.35` 與 `uLightIntensity`／`uRefractiveIndex`／`uThickness`。
   **所以那組調降在目前的算圖路徑上預期是無效的**,要真的壓到 +30 得改走 premium
   路徑或升級套件 —— 尚未決定,詳見 #169。

#### 更正史

- **初稿**:寫「我們是 Apple 的 4 倍,要調弱」,依據是使用者提供的 +119 截圖。那張圖
  出自 `ab5fb19`(「玻璃邊緣交還材質,移除四處畫上去的描邊」)之前的 build,量到的是
  一個早已被移除的描邊。
- **第一次更正**:改寫成「材質並沒有接手,差值恆為 0,所以把邊緣做回來」。那組 0 是
  **模擬器**量的,真機是 +125 —— 方向對(邊緣要畫回來),但「材質不產生邊緣」這個
  理由是錯的。
- **第二次更正(#169,本次)**:材質確實會產生邊緣,而且過強;畫上去的細邊則剛好落在
  Apple 的量級。兩層分開處理。

## Consequences

- ADR-0003 標記為 superseded,原文保留供追溯。
- `CONTEXT.md` 的 tint 詞條回到「一律前景、沒有例外」。
- **無障礙 fallback 不變**:提高對比／降低透明度時仍收斂為中性不透明,本來就是中性,
  這次改動反而讓一般模式與 fallback 的語意一致了。
- Header 拆成多顆膠囊會動到 6 個 root 畫面與路由畫面的版面,是這批改動裡最大的一塊。
- 日期選擇器的軌**已於 #169 改回玻璃**,與其餘 chrome 用同一組材質參數(原文寫「不受
  影響:它在 v0.12.0 已改成 `BackdropFilter` + 填色」—— 那次換掉的理由同樣是模擬器
  的假象)。選取膠囊維持自畫的中性填色,巢狀在玻璃層裡的子玻璃顏色會被母層吃掉。

### 日期選擇器遷移（2026-09-09，#306）

新版公開控制項已自行提供軌道與選取底，不再外包 `TpGlassSurface`，也不再維護
`_optionWidth`、捲動中心與自畫 ShapeDecoration。選取底透過 `indicatorColor`
指定中性語意色；水平滑動只瀏覽，`selectionAlignment: center` 交由套件置中。

仍保留的薄整合與理由：

- 公開 `GlassSegment.icon` 可接受 widget，但沒有任意 label builder 或 App key 欄位。
  以此插槽承載水平標籤、圖示／資料圓點及既有操作 key，內容採自然寬度；完整讀屏
  標籤仍交 `semanticLabel`。不在 App 重建 gesture 或定位 overlay。
- `preferredHeight` 只量測 App 自有文字行高、44pt 下限及公開 control padding，
  同步時間軸固定列與地圖內容避讓，不反推套件內部幾何。
- 外接鍵盤左右鍵沿用 App Focus；被動 pointer listener 只取得焦點，
  切換選項與拖曳仍由套件處理。套件不回呼同一 index，故目前選項的內容補
  一個 tap recognizer；它不處理 drag，不疊 overlay，保留時間軸點目前 Day 回到
  當日開頭。Enter／Space 也可重新啟用目前範圍。
- 讀屏普通點按仍採套件預設，提供「重新選取目前範圍」具名 action 保留再次
  選取的功能。App 不重複宣告 selected，讓 custom action 合併到套件原 label
  節點；重複 selected flag 或兩個 tap handler 會分裂成空白按鈕，測試禁止此情形。
- 套件 1.4.1 即使在 `GlassAccessibilityScope(reduceMotion: true)` 下仍會以
  300ms 捲動置中。公開行為測試已重現；只在公開 ScrollController 的 `animateTo`
  轉為 `jumpTo`，不改套件計算的目標與選取延遲。

十態矩陣以實際像素確認選取底會移動、未選取軌道可區分，以及提高對比／降低
透明度各自不透出背景；這是本機內容與幾何證據，不代表真機折射材質已驗收。

### 導覽外框與帶狀遮蔽遷移（2026-09-09，#307）

`GlassAppBar` 接手固定 bar 的自然寬度與標題置中避讓；移除 `TpToolbarSlots`、
`TextPainter` 寬度反推、群組固定 slot 與 sheet 左右等寬佔位。相關動作以
`GlassButtonGroup(showDividers: false)` 共用一片玻璃，子 `GlassButton` 採透明樣式，
同時接手 pointer、Tab／Enter 和讀屏；不再使用僅支援 pointer 的群組 GestureDetector。
bar button 不再覆寫舊版 interactionScale／stretch。

上下帶改用公開預設 `ProgressiveBlur` 與 soft `GlassScrollEdgeEffect`，移除六層
BackdropFilter、每層 sigma、peak／edge alpha、55% 區段比例與手製兩段漸層。
ProgressiveBlur 在 1.4.1 自行 ClipRect；App 保留 IgnorePointer 與內容／控制項層級。
公開元件不處理 App 的 Reduce Transparency，也沒有同時滿足固定不透明區及
獨立羽化的設定；因此提高對比與降低透明度各自保留 ColoredBox 不透明區，羽化
交給套件 soft effect。媒體背景的 35% 語意暗化透過公開 fadeColor 保留。

浮動 header 的返回與任意標題 widget 共用膠囊、帳號另組及 safe area 屬產品組裝，
繼續以 Row 和共用 TpGlassSurface 承接；它沒有 slot 反推或材質重寫。TpHeaderTitle
保留 inline 文字語意與省略規則；route 與 sheet 的 close guard 均保持在 App 層。

像素測試比較獨立公開套件參考組裝，原 renderer 亮度 197、新預設約 162，先失敗
再替換通過；另保留內容可讀性、控制項清晰、觸控穿透與不透明降級。headless 的
ProgressiveBlur 使用 uniform fallback，以上不是 Impeller 真實 shader 或真機材質驗收。

### 選單遷移（2026-09-09，#308）

`GlassMenu` 接手面板、`OverlayPortal`、開關 morph 與螢幕邊界調整。移除
`RawMenuAnchor`、自畫玻璃面板／動畫、上下翻轉估算、最長標籤面板寬度反推，
以及舊 shader 專用的 menu settings。入口前景維持品牌 tint，面板採共用新版
預設與獨立不透明降級。

精確 1.4.1 的普通非捲動 `GlassMenuItem` clone 會忽略讀屏 tap 回呼，已用公開
語意操作重現「預期 1 次、實際 0 次」。因此保留公開自訂內容
`GlassMenuLabel(child: GlassMenuItem(...))`：套件仍畫項目與焦點／按壓回饋，
App 只轉接 selected、停用原因、語意 tap、初始焦點和 Esc。此路徑不使用套件
滑動選取膠囊，採項目自身的 hover／focus／press 呈現，不重建材質或選取動畫。

自訂內容的公開高度需明確提供，故保留文字量測來容納換行與放大字級；量測
只決定項目內容高度，不再計算面板位置，亦不設定固定 `menuHeight`。寬度由
公開 `menuWidth` 約束為可用螢幕內最多 280pt；`autoAdjustToScreen` 與
`menuPadding` 接手邊界和 safe area。降低動態效果時，除套件 morph 政策外，
公開設定另停用面板 interactionScale／stretch 與項目 press scale。

`TpMoreMenuController` 只把按鈕與卡片長按統一交給公開 `GlassMenuController`，
並在每次 open 重置單次選取去重。選取同步啟動關閉與業務回呼，不等待動畫，
原有破壞性確認流程不變。探索頁與新增停留點的地區選單亦共用此入口，保留
目前選取語意、地區切換與原搜尋查詢。

精確 1.4.1 的 route listener 在 GoRouter declarative 導航更新期間呼叫
`OverlayPortal.hide`，會觸發 persistentCallbacks 斷言；既有 JSON 匯入導航測試
可重現。公開 controller 沒有立即 dismiss 或停用 route listener 的選項，故 App
以 root `OverlayEntry` 提供無 ModalRoute 的套件 host，透過公開
`CompositedTransformTarget`／`Follower` 連結原觸發點。App 不手算 popup 位置、
不重畫面板：普通關閉等待套件 morph 完成，原頁或祖先 route 切換及 dispose
才移除 host。host 捕捉原頁 theme／MediaQuery，媒體與玻璃設定讀原 scope；
依賴或業務項目／入口狀態變更先關閉，下次開啟重新捕捉，避免舊字級、
可及性設定或停用原因殘留。

Bold Text 的實際字重同時套用於量測及呈現。以真實 regular／bold 字型的
公開文字省略與勾號矩形測試驗證，避免 Ahem 相同字寬造成假綠。

### Sheet 遷移（2026-09-09，#309）

移除 `_appLargeSheetSettings` 的舊 shader 校準與 halfSettings 重複覆寫；
一般態讓 `GlassModalSheetScaffold` 自行解析套件 sheet 預設。
移除 93%／62% 高度、28／0 圓角與零 margin，保留 fixed `{large}`／
resizable `{medium, large}`。原先 0.85 fillThreshold 與 gradual 本來就是
這個公開 scaffold 的預設，刪去是消除重複設定，不宣稱因此改變畫面；
不可混用 `GlassModalSheet.show` 的另一組預設。

large 的不透明內容色保留系統 surface；提高對比或降低透明度則各自提供
不透明設定與 minimal 品質，不能只靠 blur 歸零。regular Account 保留
560×720 置中 form-sheet 幾何，以公開 `GlassContainer` 接手材質與圓角，
取捨見 ADR-0010。沒有 App 自製的捲動交接控制器可刪，套件公開 controller
與原有可捲動內容已能完成同一手勢的展開／捲動交接。

App 保留 route、dirty／submitting／關閉去重、內層 Navigator、拒絕後復位、
child identity 與鍵盤收合。公開 `show` 入口不能取代這些非同步關閉保護；
薄 route 另尊重 Reduce Motion，進出不位移。共用鍵盤 listener 只做 unfocus，
不是舊版 sheet 手勢 workaround。

測試以公開參考組裝比較 medium 材質與左上圓角、regular 材質與幾何，並驗證
獨立不透明降級、真實拖曳、長清單及未儲存保護。這些 headless 像素與操作證據
不是 Impeller shader、PlatformView 或 iOS／Android 真機材質驗收。

### 媒體日期與帳號可讀性更正（2026-09-10）

1.4.1 的 scrollable 日期軌道不會因 glass settings 改變底色；原本未選日期
使用半透明 `onSurfaceVariant`，帳號亦未承接媒體合成設定。深色模式的亮色
地圖背景上，真 App 元件與實際字型的日期對比僅 1.105:1，不能用 token
名目色或「已指定媒體 recipe」作為可讀性證據。

使用者比較全不透明方案與半透明方案後，選擇後者：僅媒體上的日期軌道與
帳號採 70% `surfaceContainerLow`，未選日期及帳號符號採不透明 `onSurface`。
保留圖磚透出的取捨由此處明文限定；共用 35% 媒體暗化值、標題、底部 tab、
POI 及地圖圖資不變，選取日期仍採中性底與品牌 tint 前景。這是前景與底色
配對的產品例外，不恢復任何舊 shader 校準。提高對比與降低透明度仍各自
收斂為不透明系統底；非媒體外觀不變。

新增回歸以真 `TpHorizontalSelector`／`TpAccountAvatarButton`、Roboto 與
Cupertino 字型驗證 Light／Dark、亮暗背景的合成像素、獨立不透明降級及
44pt／日期點選捲動／帳號導航。此證據限於 App 自有色彩與操作，不能代替
原生 PlatformView、Impeller 或真機 Liquid Glass 材質驗收。

### 帳號與定位透明度更正（2026-09-10，後續使用者確認）

使用者再次比較地圖畫面後，確認帳號與定位背景需更通透、接近標題玻璃，
但圖示仍須清楚，日期列不變。本節只取代上節帳號的 70% 中性底策略；
日期 70% 底色、未選文字 4.5:1、200% 字級與選取 tint 契約繼續有效。

帳號與定位改用同一個共用圖示配方：45% 黑色填色與白色媒體前景，
透過套件公開 glassColor／platformViewFallbackColor 設定；其他媒體控制項
仍採 35% 暗化。定位移除原本不透明 Material 背景，接上公開 GlassButton，
保留 44pt、原圓角方形、定位中進度與禁重入、首次點擊請求權限。
提高對比或降低透明度任一啟用時，兩顆皆改不透明系統底與對應前景。
定位中改由同配方的 TpGlassSurface 呈現進度，保留 disabled 按鈕語意且
沒有回呼；避免套件 disabled 對整顆按鈕降為 50% opacity，破壞不透明降級。

真元件黑白背景像素差的 baseline：帳號 29.8%、定位 0%；修正後皆為
54.9%，圖示對比至少 3:1。測試另覆蓋真 TripMapScreen 的組裝，底圖由
mapBuilder 取代；這是 App 自有填色、幾何與操作證據，不是原生圖磚、
Impeller 或真機 Liquid Glass 光學驗收。前述更正史與各次證據保持原歸屬。

## 方法論備註

### 2026-09-09 全範圍盤點（#310）

composer、POI accessory 與地圖上的既有玻璃控制已承接 #304 的共用預設材質，不再保留
局部 blur／光學校準。正常模式保留媒體 scope、35% 產品暗化值與白色前景，因圖磚維持
日間樣式而套件不替 App 判定原生圖磚亮度；它們透過公開色彩設定與
`platformViewBackdrop` 共存路徑提供，不代表原生地圖能被 shader 折射。
提高對比或降低透明度時，不透明表面已遮住媒體，bar 前景改為 `onSurface`；
不將正常模式的白色沿用到淺色不透明表面。品牌選取前景仍維持既有 tint。
POI 內容卡保持非玻璃，動態高度、分頁／marker 同步、composer 草稿及鍵盤配置
仍屬產品契約。完整移除／保留清單、切片 commit 與驗證限制見
[1.4.1 遷移紀錄](../liquid-glass-1.4.1-migration.md)。裝置材質／效能驗收仍未完成。

本 ADR 早期的外觀比較數字來自像素量測,而不是目視判斷。這是刻意的 —— 這條線上前後兩份
文件(#118 與 ADR-0003)都因為「看起來像」而下了錯誤結論。

**但光是「量」還不夠。** 本 ADR 的初稿在第 5 項就犯了第三次同類錯誤:量了 Apple,
卻拿**使用者提供的截圖**當我們這邊的現況 —— 那張圖出自舊 build,量到的是一個早已被
移除的描邊。正確的作法是**兩邊都量當前狀態**:Apple 量截圖、我們量剛建置出來的畫面。
差一步就會得到方向完全相反的結論。

**而且量在哪裡也算數(#169 補上的第四課)。**

> **模擬器不可用於驗證 LiquidGlass 材質。** 模擬器不渲染材質自身的邊緣光。同一個
> build,模擬器量到「材質不產生邊緣」(差 0),真機量到 +125。凡是玻璃材質的外觀
> ——邊緣光、折射、材質在不同背景上的顯形程度 —— **模擬器數值一律不得作為驗收
> 依據**,只能用來驗「我們自己畫上去的東西」(描邊、填色、幾何),那一層兩邊一致。

前後三輪在同一條線上判斷錯誤:#118 與 ADR-0003 是「沒量就下結論」,PR #163 與
PR #155 是「量了,但量在模擬器上」。**量測本身不夠,還要量在對的地方。**
