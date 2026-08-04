---
status: accepted
---

# iOS 與 Android 共用一套 iOS HIG，導覽配置由可用寬度而非作業系統決定

Tripline 要同時上 iPhone、iPad、Android 手機與 Android 平板四種形態。一般作法是「各平台走各自的原生語言」——
iOS 走 HIG、Android 走 Material——再依作業系統挑版型。本專案**兩件事都不做**：全平台使用同一套 iOS 26
system-app 的視覺與互動，不另外建立 Material 版本（`DESIGN.md:22`）；導覽究竟走 compact 或 regular，
由**該 subtree 實際拿到的可用寬度**決定，與作業系統無關（`DESIGN.md:24`、`DESIGN.md:52`）。

實作只有一條門檻：`lib/features/shell/app_shell.dart:39` 的 `regularNavigationWidth = 720.0`，
在 `app_shell.dart:73` 用 `LayoutBuilder` 的 `constraints.maxWidth` 比對。過門檻時同一組 root tab bar 以
`inline` 形態掛到頂部（`app_shell.dart:82`），未過則留在底部（`app_shell.dart:115`）；
行程 detail 用同一個常數決定左側是否並排 320pt 的行程清單（`app_shell.dart:148`、`app_shell.dart:177`）。

之所以是**寬度**而不是 OS，理由不是偏好而是資訊本身：作業系統回答不了「現在有多寬」。
`test/features/shell/app_shell_test.dart:180` 的尺寸矩陣把這點寫成斷言——iPad Split View 600×820 仍是 iOS
卻必須走 compact，iPhone 橫向 844×390 反而該走 regular，Android 平板 1280×800 走的是與 iPad 相同的 regular
型態。任何以 OS 為分支條件的規則在這三格全部答錯。

## Considered Options

**每平台各自原生（Android 走 Material）** —— 這是成本最高的選項，而且成本不在寫的時候，在維護的時候。
導覽 chrome 整組建在 `liquid_glass_widgets` 之上（見 [ADR-0001](0001-keep-liquid-glass-over-native-cupertino.md)），
Material 版本等於要再長出一套平行的 tab bar、header、選單與日期選擇器；`DESIGN.md` 從 §4 到 §17 的每一條
「HIG 必須」都要有對應的 Material 條文，`DESIGN.md:333` 的驗收矩陣要拆成兩份，關鍵畫面的 golden 也要兩套。
使用者只有一個人、App 只有一套資訊架構，卻要付兩份持續成本。`DESIGN.md:346` 因此把「Android phone 與
Android tablet 使用相同 iOS HIG 視覺」直接列進手動驗收項目。

**依作業系統分兩套版型** —— 會讓 Android 平板與 iPad 的行為漂移：兩者螢幕尺寸重疊、使用情境相同，卻因為
OS 不同而拿到不同的導覽（`DESIGN.md:52` 明文要求 Android tablet 依相同 width 規則呈現 iPad 型態）。更根本的問題是上面那三格——OS 不變、
可用寬度會變。iPad multitasking resize（`DESIGN.md:25`、`DESIGN.md:53`）在同一個 OS、同一個 process 裡
就要求配置切換，OS 分支對此無話可說。

**手機畫面等比放大到 tablet** —— `DESIGN.md:24` 直接把它列為 HIG 必須不得做。放大版沒有利用寬版空間
（對照 `app_shell.dart:148`–`:166` 在 regular 下並排出來的 320pt 側欄），行程 detail 這種天生兩欄的內容仍然只能一次看一邊，
寬螢幕換來的只是更長的行寬與更多留白。

**另建 tablet 專用 store listing** —— 兩份 listing 意味著兩條發版線與兩份要同步的內容，而它想解決的
「平板體驗不同」其實是版面問題，不是發布問題。決定只改 layout，
不動發布結構、也不建立 tablet 專用的 domain state。

**Android 平板改用 `NavigationRail`** —— 這是本 ADR 最容易被質疑的一點，所以正面回答：**不用**
（`DESIGN.md:52`）。rail 是 Material 的頂層導覽語彙，採用它等於在一套 iOS 26 chrome 裡開一個唯一的
Material 破口，而且是最顯眼的那個。它還會連帶要求一套自己的選取指示、label 與 selected semantics，
以及 branch stack 保留行為（`DESIGN.md:44`）——也就是上面「每平台各自原生」那筆成本的縮小版。
這條規則不只寫在文件裡：`app_shell_test.dart:241` 與 `app_shell_test.dart:285` 對整個尺寸矩陣斷言
`find.byType(NavigationRail)` 為 `findsNothing`，它是被測試守住的不變式。

## Consequences

- **App 內存在兩條 regular 判定，門檻不同。** 導覽用 `app_shell.dart:39` 的寬度單一條件；
  `lib/app/adaptive.dart:754` 的 `appIsRegularSizeClass` 則是 `width >= 720 && height >= 700`，
  而它的註解（`adaptive.dart:748`）自稱是「全 App 判定 regular size class 的**唯一**規則」。
  結果 iPhone 橫向 844×390 會拿到 regular 頂部 tabs，卻不算 regular size class。目前兩者服務的對象不同
  （導覽版面 vs. sheet 呈現），但這個落差是隱性的——動任一邊之前要先確認是刻意還是漂移。
- **新增寬度分支時必須維持同一個 widget subtree。** `app_shell.dart:132` 的註解與
  `app_shell.dart:149`–`app_shell.dart:166` 的寫法刻意讓 compact 與 regular 共用同一組 `Row`/`Expanded`
  祖先，就是為了讓 iPad multitasking resize 不重建 detail、不掉目前行程與 Day。用 `if (regular) return A;
  else return B;` 這種直覺寫法會靜默破壞它，而且不會有測試以外的徵兆。
- **Android 使用者的預期落差由手動驗收承接，不由程式碼調和。** 返回手勢、選單、日期 picker 在 Android 上
  都不是系統原生觀感，這是本決策明知並接受的代價；`DESIGN.md:346` 的手動矩陣是唯一會抓到它的地方。
- `DESIGN.md:8` 與 `DESIGN.md:356` 目前連到不存在的 `docs/adr/0001-universal-ios-hig.md`，本 ADR 即該文件的
  正主；連結修正屬 #250 的範圍，不在此處變更。
