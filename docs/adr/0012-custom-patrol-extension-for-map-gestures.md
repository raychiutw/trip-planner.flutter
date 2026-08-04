---
status: accepted
---

# 原生地圖的多指手勢測試走自建 Patrol server extension

issue #104 要為原生 Google Map platform view 取得 pinch／rotate／double-tap 的自動化證據。
Patrol 直到 4.8.0 都沒有任何多指手勢 API —— 對 4.8.0 套件原始碼做 `pinch|rotate|multitouch`
全文搜尋只命中內附的 DevTools build 產物,Dart 公開手勢面只有 `tap`／`doubleTap`／`tapAt`／
`swipe`／`swipeBack`／`longPress`(`docs/discovery/native-map-gestures.md:33-40`)。所以手勢
一定得自己注入,問題只在「原生端怎麼知道現在該注入」。

原本的設計是單向旗標:Dart 端把按鈕文字改成 `Tripline native map pinch request`,原生端輪詢
accessibility label,看到就注入。**這條路在 iOS 上從未觸發過任何一次手勢**,因為 iOS 實機的
XCUI accessibility tree 裡根本沒有 Flutter 的 `Semantics` 節點(run 30175947137 的 dump 只有
`Application` / `Window` / 五層無 label 的 `Other` / `platform_view[0].overlay[*]`)。

決定改走 **Patrol 4.8.0 新增的 server extension**:自己開一條 HTTP route
`POST /tripline/gesture`,由 Dart 端直接呼叫(`patrol_test/native_map_smoke_test.dart:500-516`),
iOS 端由 `TriplineGestureExtension` 的
`register(on:)` 掛上這條 route,並執行 `XCUIElement` 的公開多指介面
(`ios/RunnerUITests/TriplineGestureExtension.swift:28-54`)。關鍵在於 iOS 的 Patrol automation
server 跑在 **XCTest runner 行程內**,handler 裡可以直接操作 `XCUIApplication`,**完全繞開
accessibility tree**。Android 沒有這個問題,維持既有的 UiAutomator 多指注入
(`android/app/src/androidTest/java/com/raychiu/tripline/MainActivityTest.java:112-139`)。

## Considered Options

**Patrol 內建手勢 API** —— 不存在,不是版本落後的問題。上游 `leancodepl/patrol` 搜尋
`pinch`／`multitouch`／`zoom gesture`／`rotate gesture` 全部 `total_count=0`,沒有 issue、
沒有 PR、沒有 roadmap 訊號。等官方支援等於無限期等待,不可規劃。

**Dart 端 `PlatformDispatcher.instance.setSemanticsTreeEnabled(true)`** —— 這是調查報告
明列的首選路徑(`docs/discovery/native-map-gestures.md:242,248`),理由是 `flutter_test` 的
`TestPlatformDispatcher` 沒轉發這支 API、被 `noSuchMethod` 吞掉,所以繞過 wrapper 直接打
dart:ui 的真 singleton 就該通。**實測失敗**(commit `de67380`)。一行測試碼、零 production
風險、針對報告找出的「唯一已知阻斷點」—— 成本最低的路徑,但它沒有讓 Flutter 的 semantics
節點進到 XCUI 那棵樹。

**原生端 `[flutterEngine ensureSemanticsEnabled]`** —— 上一項失敗後的正規備案,官方 header
明寫用途就是 UI 測試,代價是要動 `ios/Runner/AppDelegate.swift` 這個 production target 並自己
做 gating。**同樣實測失敗**(commit `363db7f`)。兩條路都試完之後才 dump 出那棵 tree
(commit `61a93f7`),確認缺的不是「開關沒打開」而是節點根本不在,semantics 這個方向整條作廢。

**在裝置上開 VoiceOver／Switch Control** —— 符合 iOS embedder 建立 accessibility bridge 的
判斷式,但 Firebase Test Lab 的受管實機無法改系統設定;而且 VoiceOver 會攔截手勢,打開了反而
讓要測的東西測不成。

**降級證據:改用 `TripMapController` 的 camera API** —— 不注入手勢,直接呼叫 API 移動相機再驗
callback。成本低,但驗的是 SDK 的 camera API,不是使用者手勢,**不能宣稱 gesture 已驗證** ——
只能維持 issue 上的 `BLOCKED` 記錄。

## Consequences

- **這是跨 Patrol 升版 + 三個平台檔案的測試基礎建設,升 Patrol 版本時要一併檢查。** 牽動的點:
  `pubspec.yaml:69` 的 `patrol: 4.8.0` 與 `.github/workflows/mobile-e2e.yml:59` 的
  `PATROL_CLI_VERSION: '4.6.1'` **必須同時升**(4.7.0 起兩者互相要求版本下限);
  `PatrolServerExtension`／`PatrolRouteRegistrar`／`PatrolServerExtensions.registerExtensionClass`
  是 4.8.0 才有的擴充點,升版時要確認簽名沒變;`ios/Runner.xcodeproj/project.pbxproj:21,220` 要
  讓 Swift 檔留在 `RunnerUITests` target 裡。
- **註冊必須在 `+load`**(`ios/RunnerUITests/RunnerUITests.m:28-36`)—— Patrol 的 server 在
  `+testInvocations` 啟動,晚一步註冊就掛不上去。
- **XCUI 只能在主執行緒操作**(`ios/RunnerUITests/TriplineGestureExtension.swift:37-49`)。直接
  在 HTTP handler 的執行緒上呼叫會讓 XCTest runner 崩潰,症狀在 Dart 端是
  `Connection closed before full header was received`、JUnit 則多一筆空名稱 0.0 秒的 FAIL
  (run 30178220082)—— 看起來完全不像執行緒問題。
- **兩平台的注入路徑不同,而 Android 是靠「route 不存在」走掉的**:`_requestNativeGesture` 收到
  非 2xx 或連線錯誤時只 `debugPrint` 不 throw(`patrol_test/native_map_smoke_test.dart:510-513`)。
  好處是同一份 Dart 測試兩平台共用,代價是 **iOS route 壞掉的外觀和 Android 正常運作一模一樣**,
  只能靠手勢有沒有被觀察到來分辨。
- 判定證據取自地圖自己的 `onCameraIdle`(zoom 差 `>= 0.25`、bearing 差 `>= 5°`,
  `patrol_test/native_map_smoke_test.dart:241-251`),不是「手勢有沒有送出」。這一層與注入方式
  無關,換注入管道不必改判定。
- `test/workflows/mobile_e2e_workflow_test.dart:683-706` 以字串斷言把這個結構釘住(必須有
  `patrolNativeServerUri`、`registerExtensionClass`,不得有 `NSTimer`、`ensureSemantics`)。
  要改架構就要同時改這組守門測試 —— 那是刻意的,避免有人默默把輪詢加回來。
- **Android 的綠燈來自 Test Lab 虛擬機 `MediumPhone.arm`**(`.github/workflows/mobile-e2e.yml:75`),
  只有 iOS 那側是實體機。宣稱「真機證據」時兩者不可混為一談。

## 方法論備註

調查報告把 `setSemanticsTreeEnabled` 列為建議路徑 A、`ensureSemanticsEnabled` 列為 B,把本次
實際採用的 server extension 列為 C 並註明「體質改善,不該擋在證據前面」。**實際結果是 A 與 B
都被證偽,C 才是唯一走得通的。** 報告的推論本身沒問題(它正確地找出了 iOS 與 Android 的 a11y
差異),錯的是把「找到一個看似充分的解釋」當成「找到根因」—— 那棵 tree 一直可以 dump,如果先
dump 再排路徑,順序從一開始就會不一樣。**先取事實,再排優先序。**
