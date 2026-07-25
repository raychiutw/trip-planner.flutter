# 原生地圖手勢自動化調查報告（issue #104：pinch／rotate／iOS double-tap）

調查日期：2026-07-25。所有結論只採 primary source：Patrol 官方 repo 與 pub.dev 套件原始碼、Flutter framework／engine 原始碼、Apple Xcode SDK header、AndroidX UiAutomator 原始碼、本 repo 程式碼。

---

## 0. 結論摘要

1. **Patrol 到最新的 4.8.0（2026-07-24 發布）為止，完全沒有 pinch／rotate／multi-touch 的原生自動化 API**；升級 Patrol 不能解決 issue #104。但 4.8.0 新增的 **server extension** 機制，提供了比目前「輪詢 accessibility label」更可靠的橋接架構。
2. **iOS 看不到 `Semantics(label:)` 的根因有兩層，而且第二層是 Flutter 自身的缺口**：實機上 iOS embedder 只在 VoiceOver／Switch Control／Speak Screen 開啟時才建立 accessibility bridge；而 framework 用來從 Dart 端打開它的 `PlatformDispatcher.setSemanticsTreeEnabled()`，在 `flutter_test` 的 `TestPlatformDispatcher` **沒有被轉發**，被 `noSuchMethod` 靜默吞掉 —— 所以 integration_test／Patrol 環境下 `ensureSemantics()` 在 iOS 實機上永遠打不開 a11y tree。這同時解釋了「Android 會過、iOS 不會」與「simulator 會過、實機不會」。
3. **本 repo 在 HEAD 已經有兩端最小原生橋接**（`android/app/src/androidTest/.../MainActivityTest.java`、`ios/RunnerUITests/RunnerUITests.m`，PR #109 引入），缺的不是實作而是「跑得出綠燈的證據」。Android 端用 UiAutomator 多指注入（與 Patrol 自己用的是同一層），iOS 端用 `XCUIElement` pinch／rotate，兩者都是各平台唯一的公開多指注入管道。
4. iOS 端因為根因 2 而卡在「找不到觸發旗標元素」，**不是**卡在「XCUITest 不會 pinch」。
5. 因此本 issue **不是無解**，卡點是一個可以用一行 Dart 驗證的假說。建議路徑見第 5 節。

---

## 1. （a）Patrol 是否已有新版支援原生 pinch／rotate？

### 1.1 版本現況

| 套件 | 專案目前 | 最新 | 最新發布時間 |
|---|---|---|---|
| `patrol` | 4.6.1 | **4.8.0** | 2026-07-24 |
| `patrol_cli` | 4.4.0（workflow env） | **4.6.1** | 2026-07-24 |
| `patrol_finders` | 3.5.0（transitive） | 3.6.0 | 2026-07-09 |

—— 來源：`https://pub.dev/api/packages/patrol`、`https://pub.dev/api/packages/patrol_cli`、`https://pub.dev/api/packages/patrol_finders`（pub.dev 官方 API，2026-07-25 查詢）；專案版本見 `pubspec.yaml:70`、`.github/workflows/mobile-e2e.yml:59`。

4.6.1 之後的版本序列：`4.7.0-dev.1/2/3` → `4.7.0`（2026-07-13）→ `4.7.1`（2026-07-14）→ `4.8.0`（2026-07-24）。

### 1.2 沒有 pinch／rotate —— 以原始碼確認，不是看 release notes 措辭

把 pub.dev 上的 `patrol-4.8.0.tar.gz` 解開後，對整包（Dart `lib/`、Android `android/src/main/kotlin/`、iOS／macOS `darwin/patrol/Sources/`）做 case-insensitive 搜尋 `pinch|rotate|multitouch|twoPointer`：

- **除了套件內附的 DevTools extension build 產物（`extension/devtools/build/**`，那是 Flutter Web engine 的 JS，與 automation 無關）之外，零命中。**
- Android 端 `Automator.kt` 的手勢實作只有 `uiDevice.click()`、`uiDevice.swipe()`、`pressKeyCode` 等單指／按鍵操作。
- iOS 端 `MobileAutomatorServer.swift`／`IosAutomatorServer.swift` 同樣沒有任何多指 API。
- Dart 公開介面（`lib/src/platform/android/android_automator.dart`、`lib/src/native/native_automator2.dart`）的手勢面只有 `tap`、`doubleTap`、`tapAt`、`swipe`、`swipeBack`、`longPress` 這幾支。

—— 來源：`patrol` 4.8.0 套件原始碼（pub.dev archive `https://pub.dev/api/archives/patrol-4.8.0.tar.gz`），檔案 `android/src/main/kotlin/pl/leancode/patrol/Automator.kt`、`lib/src/platform/android/android_automator.dart`、`lib/src/native/native_automator2.dart`。

CHANGELOG 也佐證同一件事：4.7.0／4.7.1／4.8.0 的內容集中在 SPM 支援、Web runner（Playwright）選項、extension 機制、多分頁瀏覽器 API，沒有任何手勢新增。—— 來源：`https://raw.githubusercontent.com/leancodepl/patrol/master/packages/patrol/CHANGELOG.md`。

GitHub 上游也查不到需求票：`repo:leancodepl/patrol` 搜尋 `pinch`／`multitouch`／`zoom gesture`／`rotate gesture` 全部 `total_count=0`（同一支 search API 查 `permission` 有 179 筆，可證搜尋本身有效）。**上游沒有 roadmap、沒有 issue、沒有 PR**，等官方支援等於無限期等待。—— 來源：GitHub Search API `search/issues`，2026-07-25 查詢。

### 1.3 4.8.0 真正有價值的新東西：server extension

4.8.0 的 `Add support for Patrol extensions (#3160)` 開了一個泛用擴充點：外部套件可以把自己的 HTTP route 掛到**同一台** Patrol automation server（預設 `localhost:8081`，就是 `$.platform.mobile.*` 走的那台）。

- Android：實作 `pl.leancode.patrol.PatrolServerExtension` 介面（`val name`、`fun routes(): RoutingHttpHandler`），透過 `META-INF/services` 由 `ServiceLoader` 探索，`PatrolServer.kt:38` 在啟動時 `PatrolServerExtensions.discover()` 後掛載。
- iOS：實作 `@objc PatrolServerExtension` protocol（`register(on registrar: PatrolRouteRegistrar)`），用 `PatrolServerExtensions.registerExtensionClass(_:)` 註冊，`PatrolServer.swift:61-74` 在啟動時把 route 掛上去。
- Dart 端：`patrolNativeServerUri`（`lib/src/extensions/patrol_extension.dart`）已經幫忙解好 `PATROL_HOST`／`PATROL_TEST_SERVER_PORT`，直接 HTTP POST 就能呼叫自訂原生指令。

—— 來源：`patrol` 4.8.0 之 `android/src/main/kotlin/pl/leancode/patrol/PatrolServerExtension.kt`、`darwin/patrol/Sources/PatrolImpl/AutomatorServer/PatrolServerExtension.swift`、`darwin/patrol/Sources/PatrolImpl/AutomatorServer/PatrolServer.swift`、`lib/src/extensions/patrol_extension.dart`。

**這個機制的意義**：iOS 的 Patrol server 跑在 **XCTest runner 行程**內（`PATROL_INTEGRATION_TEST_IOS_RUNNER` 巨集在測試方法裡 `[[PatrolServer alloc] init]` 並啟動），因此 extension handler 裡可以直接操作 `XCUIApplication`；Android 的 server 跑在 instrumentation 行程內，可直接用 `UiDevice`。也就是說 pinch／rotate 可以做成**同步 request／response 的原生指令**，取代目前「Dart 改 label → 原生輪詢看到 label → 注入手勢」的單向、無回覆、無錯誤傳遞的設計。

—— 來源：`patrol` 4.8.0 之 `darwin/patrol/Sources/patrol/include/PatrolIntegrationTestIosRunner.h:194`（server 於 runner 行程建立）。

### 1.4 升級路徑與 breaking change

- `patrol` 4.7.0 的 CHANGELOG 明寫 **「This version requires version `4.5.0` of `patrol_cli` package」**；`patrol_cli` 4.5.0 也反向要求 `patrol` 4.7.0。所以 `patrol` 與 `patrol_cli` 必須**同時**升（本專案 workflow 目前釘 `PATROL_CLI_VERSION: '4.4.0'`）。—— 來源：`patrol`／`patrol_cli` 官方 CHANGELOG。
- 4.7.0 加入 SPM 支援，但明寫 **「CocoaPods remains supported for projects that have not migrated to SPM」**；4.6.1 與 4.8.0 的 iOS 目錄結構同樣是 `darwin/` + `darwin/patrol.podspec`，本專案的 CocoaPods 流程不受影響。—— 來源：CHANGELOG 4.7.0；兩版套件目錄比對（`~/.pub-cache/hosted/pub.dev/patrol-4.6.1/darwin/patrol.podspec` vs 4.8.0 同名檔）。
- 本專案自訂橋接依賴的原生 API 在 4.8.0 沒有簽名變動：`PatrolJUnitRunner.setUp(Class)`／`waitForPatrolAppService()`／`listDartTests()`／`runDartTest(String)` 四支皆在（4.6.1 在第 69/112/121/145 行，4.8.0 在第 81/124/133/157 行）；`PATROL_INTEGRATION_TEST_IOS_RUNNER` 巨集差異是既有流程擴充，沒有移除本專案 category 用到的 `setUp`／`tearDown` 覆寫點。—— 來源：兩版 `android/src/main/kotlin/pl/leancode/patrol/PatrolJUnitRunner.java`、`darwin/patrol/Sources/patrol/include/PatrolIntegrationTestIosRunner.h` 比對。
- 順帶：`patrol_cli` 4.5.0 修了 **「`--clear-permissions` being ignored by `patrol build ios`」**，該 bug 正好命中「預先建 bundle 丟 Firebase Test Lab」這種用法（本專案就是這樣跑）。—— 來源：`patrol_cli` CHANGELOG 4.5.0。
- SDK 相容性：`patrol` 4.8.0 要求 `sdk >=3.8.0 <4.0.0`、`flutter >=3.32.0`，本機 Flutter 3.44.6／Dart 3.12.2 滿足。—— 來源：`patrol` 4.8.0 `pubspec.yaml`；`flutter --version`。

**小結（a）**：升級「不會」拿到 pinch／rotate，但會拿到把自製橋接做乾淨的官方擴充點，以及 iOS prebuilt bundle 的 `--clear-permissions` 修正。

---

## 2. （b）iOS：為什麼 `Semantics(label:)` 不出現在 XCTest accessibility tree

這一段是本次調查最重要的發現，因為它同時是 iOS pinch／rotate 與 iOS double-tap 兩個缺口的共同卡點。

### 2.1 第一層：iOS embedder 只在輔助科技開啟時建立 accessibility bridge

```objc
- (void)onAccessibilityStatusChanged:(NSNotification*)notification {
  ...
#if TARGET_OS_SIMULATOR
  enabled = YES;                      // simulator 一律開
#else
  _isVoiceOverRunning = [self.accessibilityFeatures isVoiceOverRunning];
  enabled = _isVoiceOverRunning || [self.accessibilityFeatures isSwitchControlRunning] ||
            [self.accessibilityFeatures isSpeakScreenEnabled];
#endif
  [self.engine enableSemantics:enabled withFlags:flags];
}
```

—— 來源：`engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterViewController.mm`（flutter/flutter master，2026-07-25 取）。

`enableSemantics:` → `PlatformViewIOS::SetSemanticsTreeEnabled(true)` 才會 `std::make_unique<AccessibilityBridge>(...)`；而 `PlatformViewIOS::UpdateSemantics()` 開頭就是 `if (accessibility_bridge_)` —— **bridge 不存在時，framework 送來的 semantics update 會被直接丟掉**，App 在 XCTest 眼中就是一個沒有任何子元素的殼。

—— 來源：`engine/src/flutter/shell/platform/darwin/ios/platform_view_ios.mm`（`UpdateSemantics` 第 141-150 行、`SetSemanticsTreeEnabled` 第 158-170 行）。

XCUITest **不會**打開 VoiceOver／Switch Control／Speak Screen。Firebase Test Lab 的 iOS 一律是實體機（`gcloud firebase test ios run`，見 `.github/workflows/mobile-e2e.yml:386`），所以走的是 `#else` 分支 → 永遠 `enabled = NO`。這也解釋了為什麼同一份測試在 simulator 上看得到元素、在 Test Lab 上看不到。

### 2.2 第二層：`ensureSemantics()` 在 flutter_test 環境下打不到 engine（Flutter 的缺口）

Flutter 有一條「framework 主動通知 engine 要產生 semantics tree」的路徑，正是為了 UI 測試這種沒有輔助科技的情境：

- `SemanticsBinding._handleFrameworkSemanticsEnabledChanged()` → `platformDispatcher.setSemanticsTreeEnabled(semanticsEnabled)`
  —— 來源：`/opt/homebrew/share/flutter/packages/flutter/lib/src/semantics/binding.dart:172-174`（Flutter 3.44.6）；master 同段在 `packages/flutter/lib/src/semantics/binding.dart:189`。
- `dart:ui` 的 `PlatformDispatcher.setSemanticsTreeEnabled(bool)` 是 `@Native` 直通 `PlatformConfigurationNativeApi::SetSemanticsTreeEnabled`，文件寫明「Informs the engine whether the framework is generating a semantics tree… One must call this method with true before sending update through `updateSemantics`」。
  —— 來源：`/opt/homebrew/share/flutter/bin/cache/pkg/sky_engine/lib/ui/platform_dispatcher.dart:722-742`。
- 這條路徑在 engine 端接到 `Shell::OnEngineSetSemanticsTreeEnabled` → `PlatformView::SetSemanticsTreeEnabled` → iOS 建立 `AccessibilityBridge`。
  —— 來源：`engine/src/flutter/shell/common/shell.cc:1503-1514`、`engine/src/flutter/lib/ui/window/platform_configuration.cc:727-733`。這條 API 就是 flutter/flutter PR **#161265「Add set semantics enabled API and wire iOS a11y bridge」**（merged 2025-03-24）加的，後續 PR **#174845「Ensures initial semantics state is sent to engine」**（merged 2025-09-02）修掉 issue **#174842「[iOS] Flakey race condition between SetSemanticsTreeEnabled and UpdateSemantics」**。三者都早於 Flutter 3.44.6。

**但是**在 `flutter_test`／`integration_test`／Patrol 環境下，binding 的 `platformDispatcher` 不是真的 `PlatformDispatcher`，而是 `TestPlatformDispatcher`：

```dart
TestWidgetsFlutterBinding()
  : platformDispatcher = TestPlatformDispatcher(platformDispatcher: PlatformDispatcher.instance) { ... }
```
—— 來源：`/opt/homebrew/share/flutter/packages/flutter_test/lib/src/binding.dart:1074-1075`。

而 `TestPlatformDispatcher implements PlatformDispatcher`，**它轉發了 `updateSemantics`，卻沒有轉發 `setSemanticsTreeEnabled`**，缺的成員由這段 catch-all 吃掉：

```dart
/// This gives us some grace time when the dart:ui side adds something to
/// [PlatformDispatcher], and makes things easier when we do rolls to give
/// us time to catch up.
@override
dynamic noSuchMethod(Invocation invocation) {
  return null;
}
```
—— 來源：`/opt/homebrew/share/flutter/packages/flutter_test/lib/src/window.dart:179`（class 宣告）、`:979-990`（`updateSemantics` 有轉發、`noSuchMethod` 回 `null`）。整份檔案 `setSemanticsTreeEnabled` 出現次數為 **0**；flutter/flutter **master 版同樣是 0**（2026-07-25 取 `packages/flutter_test/lib/src/window.dart` 確認），代表這個缺口目前上游仍在。

結論：**在 Patrol／integration_test 裡呼叫 `$.tester.ensureSemantics()`（或 `patrolTest` 預設的 `semanticsEnabled: true`）只會打開 framework 端的 semantics 產生，通知 engine 的那一步被靜默吞掉。** 在 iOS 實機上因此永遠建不出 accessibility bridge。

補充：`patrolTest` 預設 `semanticsEnabled = true`，會傳給 `testWidgets`，後者在 `widget_tester.dart:180-181` 呼叫 `tester.ensureSemantics()`。所以 `patrol_test/native_map_smoke_test.dart:85` 那行 `$.tester.ensureSemantics()` 是重複的，不是漏做 —— 問題不在測試碼漏呼叫。
—— 來源：`patrol` 4.8.0 `lib/src/common.dart:90,127`；`/opt/homebrew/share/flutter/packages/flutter_test/lib/src/widget_tester.dart:153,180-181`。

### 2.3 為什麼 Android 會過、iOS 不會

- Android embedder 的 accessibility bridge **一直**在聽 `updateSemantics`。flutter/flutter PR **#177954「wires up SetSemanticsTreeEnabled to android accessibility bridge」**（merged 2025-12-18）的說明原文：「Before the change, the bridge only listens to updateSemantics when it receives signal from the OS. After the change, the bridge always listens to updateSemantics」。所以 framework 端 `ensureSemantics()` 產生的 tree 一定看得到。
- 另外 UiAutomator 本身就是以 accessibility service 身分連上系統，`AccessibilityManager.isEnabled()` 為真時 `AccessibilityBridge` 會呼叫 `accessibilityChannel.onAndroidAccessibilityEnabled()` → `flutterJNI.setSemanticsEnabled(true)`，這是**平台→framework** 方向，完全不經過被吞掉的那條 API。
  —— 來源：`engine/src/flutter/shell/platform/android/io/flutter/view/AccessibilityBridge.java:394-412,552-553`、`.../systemchannels/AccessibilityChannel.java:124-125`。
- iOS 沒有等價的「測試工具順手打開 a11y」機制（第 2.1 節），`#else` 分支永遠關閉。

一句話：**Android 的 a11y 是「寬鬆的」，iOS 的是「嚴格的」，而 Flutter 用來在 iOS 上手動放行的那個開關，在測試 binding 裡被 wrapper 吞了。**

### 2.4 要讓 XCUITest 看得到 Flutter widget，正確作法

| 手段 | 說明 | 評價 |
|---|---|---|
| **Dart 端直接呼叫真 dispatcher**：`ui.PlatformDispatcher.instance.setSemanticsTreeEnabled(true)` | `PlatformDispatcher.instance` 是 dart:ui 的真 singleton，不經過 `TestPlatformDispatcher` wrapper，直達 `PlatformConfigurationNativeApi::SetSemanticsTreeEnabled` | **最低成本**，只動測試碼，零 production 風險。需在 Test Lab 實機驗證 |
| **原生端呼叫公開 API**：`[flutterEngine ensureSemanticsEnabled]` | header 文件明寫用途：「This method allows a user to turn semantics on when they would not ordinarily be generated and the performance overhead is not a concern, **e.g. for UI testing**」，並可用 `FlutterSemanticsUpdateNotification` 觀察 tree 就緒 —— 來源：`engine/src/flutter/shell/platform/darwin/ios/framework/Headers/FlutterEngine.h:287-311` | 官方認可、最穩，但必須改 `ios/Runner/AppDelegate.swift`（production target），需要 build-flag 或 launch-argument 把關 |
| 在裝置上打開 VoiceOver／Switch Control | 符合 2.1 的判斷式 | Test Lab 上不可行（無法在受管實機改系統設定），且 VoiceOver 會攔截手勢，反而破壞測試 |
| `accessibilityIdentifier` | Flutter 的 `Semantics(identifier:)` 會映射到 iOS `accessibilityIdentifier`，但它一樣要 accessibility bridge 存在才會出現 | 不能繞過根因，只能在根因解掉後改善選取穩定度 |

**Patrol 本身沒有提供打開 semantics 的機制**：`patrol` 4.8.0 全套原始碼裡與 semantics 相關的只有 `lib/src/common.dart` 的 `semanticsEnabled` 參數（轉給 `testWidgets`）與 `lib/src/binding.dart` 的 `ExcludeSemantics`（用在自家 overlay），沒有任何 engine 層開關。附帶一提，`common.dart:131` 把 `onSemanticsEnabledChanged` 設成空 callback（Patrol issue #1474 的 workaround），等於也接管了平台→framework 那條通知。
—— 來源：`patrol` 4.8.0 `lib/src/common.dart:88-136`、`lib/src/binding.dart:278`。

---

## 3. （c）自建最小原生橋接：現況與作法

### 3.1 先講現況：**橋接已經存在於 HEAD**

issue #104 的敘述停在「需要增加最小橋接」，但 PR #109（`v0.10.1`，2026-07-24 merged）已經把兩端都做了，只是沒有取得綠燈證據就以 waiver 發版：

- Dart 端：`patrol_test/native_map_smoke_test.dart` 用「按鈕文字＝手勢請求旗標」當單向通道 —— `armPinchCheck` 被點下後，按鈕文字變成 `Tripline native map pinch request`，原生端輪詢到這個 accessibility label 就注入手勢；成功與否由 `onCameraIdle` 的 zoom／bearing 差值判定（pinch／doubleTap 要 `|Δzoom| >= 0.25`、rotate 要 `bearing` 差 `>= 5°`），再以 `nativeMapPinchObserved` 等 key 回報給測試。
- Android 端：`android/app/src/androidTest/java/com/raychiu/tripline/MainActivityTest.java` 在 `runDartTest` 期間另開一條 bridge thread，用 `UiDevice.findObject(UiSelector().description(...))` 找旗標與地圖，pinch 用 `UiObject.pinchOut(60, 30)`、rotate 用 `performTwoPointerGesture` 兩指反向旋轉、double-tap 用兩次 `UiDevice.click()` 間隔 `100ms`。
- iOS 端：`ios/RunnerUITests/RunnerUITests.m` 以 category 覆寫 `setUp`／`tearDown`，掛一個 0.25s 的 `NSTimer` 輪詢 label，命中就對 `XCUIApplication` 發 `pinchWithScale:2.0 velocity:1.0`／`rotate:M_PI_2 withVelocity:1.0`／`doubleTap`。

—— 來源：本 repo 上述三個檔案（`master`，commit `903e995`「v0.10.1 fix: 完成原生地圖真機證據與 agent 安全設定 (#109)」引入）。

架構上這個設計沒有明顯錯誤，兩點可以確認：

- iOS 的 `NSTimer` 會被觸發：Patrol 的 runner 巨集在等待 Dart test 期間是用 `[NSRunLoop.currentRunLoop runUntilDate:...]` 逐秒 spin，main run loop 有在轉。—— 來源：`patrol` 4.8.0 `darwin/patrol/Sources/patrol/include/PatrolIntegrationTestIosRunner.h:278-293`。
- Android 的注入層與 Patrol 自己完全相同（都是 `UiDevice`／UiAutomator），不需要改用 Espresso；Patrol 的 `Automator.kt` 也是 `UiDevice.swipe()`／`UiDevice.click()`。—— 來源：`patrol` 4.8.0 `android/src/main/kotlin/pl/leancode/patrol/Automator.kt:434-458`。

**所以 issue #104 的實際狀態是「已實作、未取得證據」，而不是「無實作」。** iOS 端明確卡在第 2 節的根因；Android 端 pinch／rotate 則是「在含橋接的 SHA 上沒有跑出過綠燈紀錄」（`903e995` 只有 Mobile CI 跑過，沒有對應的 Test Lab run；issue 的最後一則發布紀錄是 `v0.10.0` 的 `a71830d`，那時橋接還沒進 master）。

### 3.2 Android：多指注入的正確寫法與可行性

- `UiObject.pinchOut(int percent, int steps)`：以物件可見範圍中心為起點，兩指**水平**向外張開 `percent%` 的寬度；`steps` 每步約 5ms（100 steps ≈ 0.5s）。底層走 `performTwoPointerGesture` → `performMultiPointerGesture`，也就是 `UiAutomation.injectInputEvent` 的真實多指 `MotionEvent`。`pinchIn` 為反向。
- `UiObject.performTwoPointerGesture(Point s1, Point s2, Point e1, Point e2, int steps)`：任意起訖點的兩指手勢 —— rotate 就是靠它（本 repo 已採此法）。
- 注意 `pinchOut`／`pinchIn` 會在物件寬度 `<= FINGER_TOUCH_HALF_WIDTH * 2` 時丟 `IllegalStateException`，且 `percent` 必須在 0–100。

—— 來源：AndroidX UiAutomator 原始碼 `test/uiautomator/uiautomator/src/main/java/androidx/test/uiautomator/UiObject.java:851-950`（`https://android.googlesource.com/platform/frameworks/support/+/androidx-main/...`）。

**手勢能不能穿到 PlatformView？** `google_navigation_flutter` 0.10.0 在 Android 用的是 `AndroidView`（virtual display 模式），touch 先進 FlutterView，再由 framework 轉成 `AndroidMotionEvent` 回送給嵌入的原生 view。這條轉換路徑**支援多指**：`AndroidMotionEvent` 帶 `pointerCount`／`pointerProperties`／`pointerCoords` 陣列，`_AndroidMotionEventConverter` 會逐一維護多個 pointer id。—— 來源：`~/.pub-cache/hosted/pub.dev/google_navigation_flutter-0.10.0/lib/src/google_navigation_flutter_android.dart:89`；`/opt/homebrew/share/flutter/packages/flutter/lib/src/services/platform_views.dart:447-460,559-680`。

也就是說「Flutter 端合成手勢送不進去」與「系統層注入的真實多指送不進去」是兩件事：前者已被 issue #104 證偽，後者在架構上是通的，但**必須用一次 Test Lab run 取得證據**。可調參數（若第一次注入沒被 Google Maps 判定為 pinch）：加大 `percent`、加大 `steps`（目前 30 steps ≈ 150ms 偏快）、rotate 的角度與半徑。這與 double-tap 之前踩到的「預設點擊間隔不被判定為 double-tap，改成 100ms 才過」是同一類問題。—— 來源：issue #104 comment（2026-07-24 發布重跑紀錄）與 commit `02b9a6f`「test: tighten native map double tap cadence」。

另一個要據實記錄的點：Android 的 Test Lab 預設裝置是 `MediumPhone.arm`（虛擬裝置），iOS 才是實體機。—— 來源：`.github/workflows/mobile-e2e.yml:75-76,386-389`。宣稱「真機證據」時，Android 這側要註明是 Test Lab 虛擬裝置。

### 3.3 iOS：XCUITest 的多指 API 與掛載點

Xcode 26.6 SDK header 對這兩支的原文：

```objc
/*! Sends a pinching gesture with two touches.
 *  The system makes a best effort to synthesize the requested scale and velocity: absolute accuracy is not guaranteed.
 *  Some values may not be possible based on the size of the element's frame - these will result in test failures.
 *  @param scale  Use a scale between 0 and 1 to "pinch close" or zoom out and a scale greater than 1 to "pinch open" or zoom in.
 *  @param velocity  The velocity of the pinch in scale factor per second. */
- (void)pinchWithScale:(CGFloat)scale velocity:(CGFloat)velocity;

/*! Sends a rotation gesture with two touches.
 *  @param rotation  The rotation of the gesture in radians.
 *  @param velocity  The velocity of the rotation gesture in radians per second. */
- (void)rotate:(CGFloat)rotation withVelocity:(CGFloat)velocity;
```

—— 來源：`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Frameworks/XCUIAutomation.framework/Headers/XCUIElement.h:228-253`（Xcode 26.6，Build 17F113）。

三個要點：

1. **手勢是「對 element」發的，取不到 element 就發不出手勢**，而且「Some values may not be possible based on the size of the element's frame」—— 元素 frame 不合理時直接算測試失敗。這正是根因 2 的下游影響。
2. XCUITest **沒有**以純座標做多指的公開 API（`XCUICoordinate` 只有單指 `press:thenDragTo:`），所以 `pinchWithScale:`／`rotate:withVelocity:` 是 iOS 唯一的公開多指管道 —— 本 repo 的選擇是對的。
3. 掛載點有兩種：現行的 `RunnerUITests` category（`setUp` 起 timer 輪詢）可以續用；或改用 3.4 的 Patrol extension，把手勢做成可呼叫的 route。

**iOS 待釐清的一點**：issue 記錄的是「改以 `IOSElementType.application` 定位後，Patrol 回報 application element 不存在」。那是 **Patrol 的 selector 查詢**（查 `XCUIElementTypeApplication` 型別的**後代**元素），與「`[[XCUIApplication alloc] init]` 這個物件本身可不可用、`frame` 對不對」是兩回事。建議在下一次 run 直接輸出 `app.exists`、`NSStringFromCGRect(app.frame)`、`app.debugDescription` 三個值當診斷 —— 若在 a11y bridge 關閉時 `app.frame` 就已經是整個畫面，那 iOS 甚至可能不需要打開 semantics 就能 pinch（只是仍然需要另一條「何時該 pinch」的觸發通道，見 3.4）。

### 3.4 與 Flutter 側 camera callback 的對接

現行對接方式（旗標 + label 輪詢 + camera callback 判定）可以保留，但有三個結構性弱點：原生端無法把「我注入了、但失敗了」回報給 Dart（只能等 Dart 端 15 秒逾時）、輪詢有 0.25s 顆粒度、以及 iOS 端整條路依賴 a11y tree。

用 Patrol 4.8.0 extension 改成請求／回應後，流程會變成：

1. Dart：`_armGesture(pinch)` 記下 `_gestureStartPosition` →
2. Dart：`POST patrolNativeServerUri.resolve('triplineNativePinch')`，body 帶 `scale`／`velocity`（Android 帶 `percent`／`steps`）→
3. 原生 handler 同步注入手勢，回 `{"injected": true}` 或錯誤 →
4. Dart 收到回應後才開始等 `onCameraIdle`，逾時就能明確區分「沒注入」與「注入了但相機沒動」。

判定條件沿用現有的 `_handleCameraIdle`（zoom 差 `>= 0.25`、bearing 差 `>= 5°`）即可，這部分設計本來就正確：**用地圖自己的 camera callback 當證據，而不是用「手勢有沒有送出」當證據**。

—— 來源：`patrol` 4.8.0 extension 三個檔案（見 1.3）；本 repo `patrol_test/native_map_smoke_test.dart:196-244`。

---

## 4. 各路徑的成本與風險

| 路徑 | 內容 | 成本 | 風險 | 解掉哪些缺口 |
|---|---|---|---|---|
| **A. 一行 Dart 打開 semantics** | 在 `native_map_smoke_test.dart` 加 `ui.PlatformDispatcher.instance.setSemanticsTreeEnabled(true)`（測試碼，非 production） | 極低（1 行 + 1 次 Test Lab run） | 低。若 Flutter 之後補上 `TestPlatformDispatcher` 轉發，這行變成冗餘但無害。需注意 issue #174842 那類 race，建議加 retry／等待 | iOS pinch／rotate／double-tap 的**共同**卡點 |
| **B. AppDelegate 呼叫 `ensureSemanticsEnabled`** | iOS 原生端用官方公開 API 開啟 semantics，以 launch argument／build config 把關 | 低－中（改 `ios/Runner/AppDelegate.swift` + gating + 測試） | 中：碰到 production target；gating 寫錯會讓正式版一直開著 semantics（多餘開銷，但不影響正確性） | 同 A，但更「官方」且不依賴測試 binding 細節 |
| **C. 橋接改用 Patrol 4.8.0 extension** | 升 `patrol` 4.6.1→4.8.0、`patrol_cli` 4.4.0→4.6.1，把兩端橋接改成 server route | 中（升版 + 兩端 extension + workflow 版本號 + 迴歸） | 中：升版牽動 iOS／Android build；但 API 相容性已查（1.4），CocoaPods 仍支援 | 去掉輪詢與單向通道，錯誤可回傳；順帶拿到 `--clear-permissions` 修正。**不會**單獨解掉 iOS a11y 根因（除非搭配 3.3 的診斷確認 `XCUIApplication` 可直接 pinch） |
| **D. 等 Patrol 官方支援** | 等上游加 pinch／rotate | 0 | 極高：上游零 issue／零 PR／零 roadmap 訊號（1.2） | 不可規劃 |
| **E. 降級證據** | 放棄原生手勢，只用 `TripMapController` API 改 camera 再驗 callback | 低 | 高（語意上）：那是驗 SDK 的 camera API，不是驗使用者手勢，不能宣稱 gesture 已驗證 | 只能維持現有 `BLOCKED` 記錄的誠實性 |

**建議路徑：A → 驗證 → (必要時) B → 之後再視需求做 C。**

理由：A 的成本是所有路徑裡最低的，而它針對的是本次調查找出的**唯一**已知阻斷點；A 若成立，現有 iOS 橋接一行不改就會活過來，pinch／rotate／double-tap 三個 iOS 缺口一起解。B 是 A 失敗時的正規備案（例如 engine 端另有限制）。C 是體質改善，不該擋在證據前面。

### 建議的執行順序（含驗證關卡）

1. **診斷 run**：iOS 橋接加三行 log（`app.exists`／`app.frame`／找不找得到 `Tripline native map evidence canvas`），Android 保持不動 —— 一次 Test Lab run 就能同時確認「A 是否有效」與「XCUIApplication 是否本來就可 pinch」。
2. 套 A，重跑 iOS 原生地圖測試；同一輪順便取 Android pinch／rotate 的第一份證據（HEAD 已有橋接但從未在 Test Lab 跑過含橋接的 SHA）。
3. Android 若 pinch 沒被 Google Maps 判定：調 `pinchOut(percent, steps)` 的 `percent`／`steps`（目前 `60, 30`），比照 double-tap 當初調 cadence 的作法。
4. 全綠後才移除 issue #104 的 evidence gap 分支與 `BLOCKED` 記錄；Android 那側的證據要註明裝置是 Test Lab 虛擬機 `MediumPhone.arm`。

---

## 5. 若最後仍不通，卡在哪、需要什麼

依調查結果，「目前無解」只在下列情況成立，且每種都有明確的下一步：

- **A 與 B 都無法在實機建立 a11y bridge**（例如 `SetSemanticsTreeEnabled` 在該 engine 版本另有前置條件）：需要對 flutter/flutter 開 issue，主題是「`TestPlatformDispatcher` 未轉發 `setSemanticsTreeEnabled`，導致 integration_test／Patrol 無法在 iOS 實機產生 semantics tree」，並附本報告第 2.2 節的引用；在修好之前，iOS 只能靠 B 的原生 API。
- **`XCUIApplication` 在無 a11y tree 時 frame 不可用，且 semantics 又打不開**：iOS 就真的沒有公開的多指注入管道（第 3.3 節第 2 點），只能走 waiver。
- **Android 多指 MotionEvent 被 virtual display 轉發丟失**：需要把 `google_navigation_flutter` 的 Android 端改成 hybrid composition／TLHC（`PlatformViewLink` + `initSurfaceAndroidView`），那是上游套件的變更，不是本 repo 能單獨處理的；屆時要對 `googlemaps/flutter-navigation-sdk` 提 issue 並附具體重現。

三種情況都不必再等 Patrol —— 上游對多指手勢**沒有**任何進行中的工作。

---

## 附錄：本報告引用的關鍵檔案

**本 repo**：`patrol_test/native_map_smoke_test.dart`、`android/app/src/androidTest/java/com/raychiu/tripline/MainActivityTest.java`、`ios/RunnerUITests/RunnerUITests.m`、`.github/workflows/mobile-e2e.yml`、`pubspec.yaml`。

**Patrol 4.8.0**（pub.dev archive）：`lib/src/common.dart`、`lib/src/extensions/patrol_extension.dart`、`android/src/main/kotlin/pl/leancode/patrol/{Automator.kt,PatrolServer.kt,PatrolServerExtension.kt,PatrolJUnitRunner.java}`、`darwin/patrol/Sources/PatrolImpl/AutomatorServer/{PatrolServer.swift,PatrolServerExtension.swift}`、`darwin/patrol/Sources/patrol/include/PatrolIntegrationTestIosRunner.h`、`CHANGELOG.md`。

**Flutter 3.44.6（本機 SDK）**：`packages/flutter/lib/src/semantics/binding.dart`、`packages/flutter_test/lib/src/{window.dart,binding.dart,widget_tester.dart}`、`packages/flutter/lib/src/services/platform_views.dart`、`bin/cache/pkg/sky_engine/lib/ui/platform_dispatcher.dart`。

**Flutter engine（flutter/flutter master，2026-07-25）**：`engine/src/flutter/shell/platform/darwin/ios/framework/Source/{FlutterViewController.mm,FlutterEngine.mm}`、`engine/src/flutter/shell/platform/darwin/ios/framework/Headers/FlutterEngine.h`、`engine/src/flutter/shell/platform/darwin/ios/platform_view_ios.mm`、`engine/src/flutter/shell/common/{shell.cc,platform_view.cc}`、`engine/src/flutter/lib/ui/window/platform_configuration.cc`、`engine/src/flutter/shell/platform/android/io/flutter/view/AccessibilityBridge.java`、`.../systemchannels/AccessibilityChannel.java`。相關 PR／issue：flutter/flutter #161265、#174842、#174845、#177954。

**Apple**：Xcode 26.6 SDK `XCUIAutomation.framework/Headers/XCUIElement.h`。

**AndroidX**：`androidx.test.uiautomator.UiObject`（android.googlesource.com，`androidx-main`）。
