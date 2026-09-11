# Mobile E2E automation

Tripline uses two complementary test layers:

- `flutter_test` and `integration_test` for deterministic app-owned state and navigation;
- Patrol package 4.8.0、`patrol_cli` 4.6.1 與 Firebase Test Lab，用於原生 Google Maps、platform views、system theme 與 real-device behavior。

The external device workflow is `.github/workflows/mobile-e2e.yml`. A weekday schedule runs one Android matrix. iOS is manual because Firebase iOS devices are physical and require Apple Development signing. Store uploads are independent: a manual `Mobile CI / Releases` dispatch starts the selected store jobs directly. Both Test Lab jobs remain master-only and use the `mobile-e2e` GitHub Environment; configure that environment to allow deployments only from `master`.

Android Test Lab first runs the standard Flutter
`integration_test/app_smoke_test.dart` instrumentation APKs, then runs the
Patrol bundle below. The two runs use separate result directories and logs.
This keeps the required Flutter integration gate independent from Patrol while
reusing the same deterministic app-owned fixture.

The Patrol bundle contains two independent evidence suites:

- `app_owned_flow_test.dart` runs Welcome／Login, four root tabs, trips, itinerary and Day fallback, notes, map/itinerary switching, Tripline and external POIs, Account 與本機 appearance 三選一（確認立即套用後可切回跟隨系統）, chat draft retention, favorites branch restoration, forms, destructive confirmation, offline state, error, and recovery against deterministic repository fixtures. It never calls production services.
- `native_map_smoke_test.dart` checks real native map creation, dispose／recreate lifecycle, zoom 13 before and after remount, overlays, theme switching, location permission, pan／pinch／rotate／double-tap gestures, and native POI callbacks. Test Lab builds with `E2E_EXPECT_GOOGLE_POI=true`, so CI fails unless a Google native POI produces the platform callback.

Separating the deterministic product flow from the native map boundary makes failures actionable while keeping both cases in the same external-device matrix.

`app_owned_flow_test.dart` 另含第二個 Patrol test「app-owned visual evidence walks
production chrome on a real map」（#314／#319 的真機視覺證據，共用
`runAppOwnedVisualEvidenceFlow`）：同一份 Test Lab artifact 內，production App 的
行程卡「⋯」／長按選單、帳號面板進出、時間軸 header 選單、聊天 composer 與
「真實 Google 地圖背景 + header／日期選擇器／root tabs／POI accessory／定位鈕／
行程切換 sheet」逐一停留錄影。API／認證／聊天／收藏仍是替身；只有地圖 canvas
改用 production `buildTripMapCanvas`，且每次進地圖都等畫面上那張 canvas 真正回報
過 `onMapReady`（production 只在 view 建立時回報一次，回到保留中的地圖不強制
重建）。真機 bootstrap 沿用 `LiquidGlassWidgets.initialize()` 與
`wrap(adaptiveQuality: true)`，光暈主題以公開值等值重現 `lib/main.dart` 的設定。
判讀 `syslog.txt`／`xcodebuild_output.log` 裡的 `flutter: Tripline visual evidence |`
行：`scene=<外觀[+注入設定]>/<畫面>` 是停留點名稱（例如 `light/trip-card-menu`、
`dark+reduce-motion/account-sheet`），同一行記錄 App 實際觀察到的 `appearance`、
`App 外觀`（淺色由 fixture 啟動即選定，深色走帳號 → 外觀）、`observed reduceMotion／
increasedContrast／reduceTransparency` 與 `dwell`；`injected accessibility=` 表示
該無障礙設定由測試 wrapper 注入，**不是** OS 設定，也不涵蓋 iOS 降低透明度
channel 橋接與 VoiceOver。`build identity` 行是帳號 footer 讀到的平台版本
（`PackageInfo.fromPlatform`，不是 release flow 的 `0.9.1（12）` 替身），供對照
Actions run 的 build metadata。host 端對應 `test/flows/app_owned_visual_evidence_flow_test.dart`
以假地圖走同一流程，只驗流程與 log 標記，不能代替真機材質證據。
時間預算：gcloud 的 `--timeout` 是整組 execution 的執行上限（官方文件明說不含裝置
準備與清理）。iOS XCTest bundle 設 `7m`；Android Patrol 矩陣設 `15m`（`android_test_lab`
job `timeout-minutes` 同步放寬到 60）；Android 標準 integration 矩陣維持 `5m`。三個值都
由 run 34582660390（0.26.7+38，platform=all）的證據推導；外層逾時的 run 仍算失敗
run，放寬只是不讓已確認的執行時間再被同一個上限截斷：

- iOS（iPhone 14 Pro／iOS 16.6）：`test_result_0.xml` 4 tests、0 failures／errors／
  skipped，suite `time` 267.121s（app-owned release flow 77.664s、visual evidence
  155.224s、native map smoke 34.228s）；`xcodebuild_output.log` 末尾
  `** TEST EXECUTE SUCCEEDED **`、整體 294.480s，已接近 300s，外層仍回報
  `Test timed out`。`7m` 給整組 XCTest 執行時間的變動餘裕。
- Android（MediumPhone.arm／API 34）：integration 矩陣單一 case PASS（XML 的 0.279s
  不是完整流程耗時，不能拿來推估）。Patrol 矩陣 `test_result_1.xml` 第一個 app-owned
  flow PASS 208.613s，已占掉 `5m` 的大部分；第二個 visual evidence 在 65.284s 被外層
  截斷（`instrumentation.results` `ANDROID_INSTRUMENTATION_COMMAND_EXEC_TIMEOUT|100302`），
  logcat 的 `Tripline visual evidence` 推進到 `light/map-day-1`，當前 log 未定位到產品
  assertion 失敗；native map smoke 沒有輪到。已確認的是外層 timeout；後續兩個 case
  仍待新 run 驗證，不能據此宣稱整組通過。`15m` 是 gcloud 對 Android 的預設值，涵蓋
  整組三個 case 的餘裕，並保留所有內層限制。

放寬後的第一個 run [34591742975](https://github.com/raychiutw/trip-planner.flutter/actions/runs/34591742975)
（0.26.8+39，platform=all）已確認每個 case 都完整跑完、XML 寫完：iOS 兩次 attempt 的
Xcode 測試執行分別 302.2s 與 291.6s（attempt 2：app-owned 80.5s、visual evidence 134.8s、
native map smoke 55.9s），都在 `7m` 內；Android Patrol 三個 case 都在 `15m` 內結束
（app-owned 158.35s、visual evidence 230.966s PASS；native map smoke 40.26s FAIL）。
兩平台的 native map smoke 都是斷言失敗而非外層逾時：iOS `onMapClicked` 9 次但 POI
callback null；Android `native_map_smoke_test.dart:119` 15 秒內沒有
`nativeMapDoubleTapObserved`（測試橋接時序，記錄在 #310）。預算有效，失敗紀錄保留，
不視整組 E2E 為通過。

兩個平台的 per-test 操作 timeout（30s／15s 等）與所有 target、assertion、gcloud 非零
失敗、branch／environment guard 都不因此調整。新 source 的裝置驗證是必要 gate：預算
放寬後仍要以新 run 的 XML 與 log 確認每個 case 完整跑完。若某次 run 的 XML 沒有寫完或
suite `time` 逼近上限的七成，優先縮短 `dwell`（`runAppOwnedVisualEvidenceFlow` 參數）
而不是刪情境或再加預算。

On iOS, both Patrol suites inspect SpringBoard before their first app
interaction and dismiss a stale `Edit Home Screen` tutorial by its native alert
and button labels. The guard confirms that the alert disappears; otherwise the
test fails at setup instead of being misreported as an app navigation or map
failure. App-owned post-submit login verification failures also attach the
currently visible screen text to the assertion reason so the Firebase Test Lab
report identifies the blocking UI.

The app-owned Patrol target injects Patrol's text-entry driver for every form
field instead of calling `WidgetTester.enterText` directly. Patrol registers and
attaches the text-input connection required by release-mode tests on physical
iOS devices; the host-runner integration test keeps the standard Flutter test
driver through the same shared flow.

一般 PR／push 到 `master` 的 CI 是 `.github/workflows/mobile.yml` 的 `ci` job：actionlint、`dart format` 檢查（排除 Patrol 產生的 `patrol_test/test_bundle.dart`）、`flutter analyze --no-fatal-infos`，以及**完整 `flutter test`**（整個 `test/`，含 HIG 十態矩陣、host 端 app-owned release／視覺證據流程與 mobile workflow 契約測試），不再只挑選少數檔案。`integration_test/` 與 `patrol_test/` 不在 `flutter test` 預設範圍：Flutter integration APK 與 Patrol bundle 只在 Firebase Test Lab（`mobile-e2e.yml`）執行。`ship` 在合併前於本機再跑同一套完整測試。host 端結果不能代替平台字型可讀性、原生地圖圖磚或人工真機無障礙證據。

## 發布證據格式

獨立人工驗收可建立一份透過 HTTPS 存取、UTF-8 編碼且 machine-readable 的 JSON 報告；Markdown、HTML、登入頁或舊版自由格式報告都不接受。最上層必須是 `{"schema_version": 1, "cases": [...]}`。報告的 `source_sha` 必須是驗收版本的完整 40 字元 commit SHA；所有 case 必須針對同一個 SHA、`version` 與 `build`。`cases` 不得有重複的 `case_id`，每筆 case 使用以下必填字串欄位：

| 欄位 | 內容 |
| --- | --- |
| `case_id` | 下表固定 ID |
| `result` | `PASS | FAIL | BLOCKED` |
| `source_sha` | 完整 commit SHA |
| `version` | App 顯示版本 |
| `build` | App build number |
| `install_source` | TestFlight、App Store、Firebase Test Lab 或其他可追溯安裝來源 |
| `tester` | 驗收者 |
| `device` | 真機型號 |
| `os_version` | iOS／iPadOS 版本 |
| `viewport` | compact／regular、直向／橫向與 split width |
| `setting_or_assistive_technology` | 本 case 開啟的系統設定或輔助使用技術 |
| `flow` | 實際操作步驟與起訖畫面 |
| `expected` | 預期行為與通過條件 |
| `observation` | 實際觀察、焦點順序、尺寸與遮擋情形 |
| `blocker` | `FAIL`／`BLOCKED` 的具體阻礙；`PASS` 填 `N/A` |
| `remediation` | 修正方向或解除阻礙所需動作；`PASS` 填 `N/A` |
| `started_at` | 含時區的 ISO 8601 時間 |
| `evidence` | 截圖、錄影或測試紀錄的 HTTPS URL |

人工報告至少包含以下 case；不得以 widget test 或模擬的 accessibility flag 取代真機操作：

| Case ID | 必驗內容 |
| --- | --- |
| `A11Y-VOICEOVER` | 四個 root tabs、Header、sheet、表單、POI accessory 的朗讀順序、名稱、狀態與操作 |
| `A11Y-VOICE-CONTROL` | 可見控制項名稱可被語音準確觸發 |
| `A11Y-SWITCH-CONTROL` | 掃描順序、群組與離開 sheet／錯誤狀態 |
| `A11Y-FULL-KEYBOARD` | 完整鍵盤操作、焦點可見性與 logical order |
| `A11Y-POINTER` | iPad pointer hover、點擊目標與 44×44pt controls |
| `A11Y-BUTTON-SHAPES` | Button Shapes 開啟後仍能辨識可操作項目 |
| `A11Y-BOLD-TEXT` | Bold Text 開啟後 Header、tab、sheet、表單、聊天與 POI accessory 不裁切、不重疊 |
| `A11Y-DIFFERENTIATE-WITHOUT-COLOR` | 不依賴顏色表達 tab、Day、錯誤、離線與選取狀態 |
| `APPEARANCE-LIGHT-DARK` | Light／Dark 下以 iPhone compact、landscape、iPad regular／split width 完成核心流程 |
| `A11Y-INCREASE-CONTRAST` | Increase Contrast 開啟後文字、邊界、選取與錯誤狀態仍清楚可辨 |
| `A11Y-REDUCE-TRANSPARENCY` | Reduce Transparency 開啟後 Header、tab bar、sheet、卡片與文字對比 |
| `A11Y-REDUCE-MOTION` | Reduce Motion 開啟後核心流程不依賴位移、縮放或彈性動畫 |
| `LAYOUT-SAFE-AREA` | compact、landscape、regular／split width 的瀏海、Home Indicator 與工具列避讓 |
| `LAYOUT-KEYBOARD` | 搜尋／對話輸入時 keyboard、composer、焦點與 root navigation 不互相遮擋 |
| `NAV-EDGE-BACK` | iOS edge-back、sheet 關閉與返回後原 branch 狀態 |

上表所有 case 與欄位都是必要項目。每筆 case 的 `result` 都必須是 `PASS`；任一 case 為 `FAIL` 或 `BLOCKED`、case ID 重複、缺少必要 case、缺少必要欄位、`source_sha` 不符、`version`／`build` 不一致、`evidence` 不是 HTTPS URL、內容裁切、焦點被 Header／keyboard／tab bar／sheet／POI accessory 遮住，或 control 小於 44×44pt，都不得將整份報告標記為 PASS。

使用保留的獨立 validator 檢查報告：

```bash
bash tool/validate_manual_evidence.sh <https-report-url> <full-source-sha>
```

商店上傳不等待這份報告；結果應另外連回對應 issue 或 release record。

## One-time Google Cloud setup

1. Enable Firebase Test Lab, Cloud Tool Results, Maps SDK for Android/iOS, and Navigation SDK (`navigationsdk.googleapis.com`) in the Firebase/Google Cloud project.
2. Create a dedicated service account and grant both:
   - `roles/cloudtestservice.testAdmin`
   - `roles/firebase.analyticsViewer`
3. Configure GitHub Actions Workload Identity Federation for this repository. Do not create a long-lived JSON service-account key.
4. Add these GitHub repository variables:
   - `FIREBASE_TEST_LAB_PROJECT_ID`
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - `GCP_TEST_LAB_SERVICE_ACCOUNT`
   - `FIREBASE_TEST_RESULTS_BUCKET` (bucket name only, without `gs://`)
   - `FIREBASE_ANDROID_MODEL` (optional; default `MediumPhone.arm`)
   - `FIREBASE_ANDROID_VERSION` (optional; default `34`)
   - `FIREBASE_IOS_MODEL` (required for iOS)
   - `FIREBASE_IOS_VERSION` (required for iOS and supported by both the selected model and the workflow's pinned Xcode version)
5. Keep `GOOGLE_MAPS_ANDROID_API_KEY` and `GOOGLE_MAPS_IOS_API_KEY` as repository secrets. Restricted keys must allow both the platform Maps SDK and Navigation SDK service while retaining the app package/bundle restriction.

Create the dedicated result bucket with uniform access, grant the Test Lab CI service account object-admin access on that bucket, and apply the checked-in 14-day lifecycle policy:

```bash
gcloud storage buckets update gs://BUCKET_NAME \
  --lifecycle-file=.github/test-lab-results-lifecycle.json
```

The current Tripline bucket is `trip-planner-490413-test-lab-results` in `ASIA-EAST1`. Its soft-delete retention is disabled so the lifecycle rule actually caps raw Test Lab storage. GitHub artifacts retain the same evidence for seven days.

The Android job reuses the existing upload-keystore secrets to sign Patrol's debug APK. This is required because the Maps key is restricted to the Tripline package and signing SHA-1; an ephemeral GitHub debug key would render an unauthorized blank map. Keep three `com.raychiu.tripline` SHA-1 allowlist entries on the Android key: local debug, CI/upload, and the distinct Google Play app-signing certificate. Firebase Test Lab proves only the debug/upload-signed path; a successful Test Lab map smoke does not prove that the Play-delivered APK can load map tiles. Every Android store release therefore needs one final install/update from the internal-track opt-in page and a map-render check on that Play-signed build.

### Android upload key 與 Maps key 的既成事實

這些值無法從 repo 或 git history 逆推,遺失就得重新申請並重新設定 Play 與 Google Cloud。

| 項目 | 值 |
|---|---|
| Upload key alias | `tripline-upload` |
| Keystore 檔 | `android/upload-keystore.jks`(已在 `.gitignore`,**永不覆寫**) |
| Upload-certificate SHA-1 | `58:EC:91:65:F1:A7:CF:8C:C6:B6:BB:B2:B4:1A:3F:6B:27:8C:EB:FA` |
| macOS Keychain 項目(keystore 密碼) | `tripline-android-upload-keystore` |
| macOS Keychain 項目(Maps key) | `tripline-google-maps-android` |
| Package name | `com.raychiu.tripline` |

SHA-1 是公開的憑證指紋,不是密鑰;密碼只存在 macOS Keychain 與 GitHub secrets。

Upload key 的產生參數(需要重建時照這組,否則指紋對不上 Play 已登記的值):PKCS12
storetype、RSA 2048、`SHA256withRSA`、validity 10000、
`CN=Tripline Android Upload, OU=Mobile, O=Tripline, L=Taipei, ST=Taiwan, C=TW`。
密碼用 `openssl rand -base64 36` 產生後直接寫進 Keychain,不落地、不印出。

Google Cloud 的 Android Maps 憑證設定:**Application restrictions → Android apps**
填 package `com.raychiu.tripline` 加上上表的 upload-certificate SHA-1;
**API restrictions → Restrict key** 只勾 Maps SDK for Android。
CI 與商店發布**不要建立 `android/maps.properties` 或 `android/key.properties`** —— 簽章與
金鑰一律走 Gradle 的環境變數契約，由 GitHub secrets 供應。本機 Maps 建置可依下方
「Local build checks」從 example 複製 `android/maps.properties`；本機簽章仍由 Keychain
注入 `ANDROID_KEYSTORE_*`，不建立 `android/key.properties`。

若 `android/upload-keystore.jks` 已存在,先檢查它的 alias 與指紋是否與上表相符,
**絕不覆寫** —— 覆寫等於失去對已上架 app 的上傳權,只能走 Play 的 upload key reset 流程。

Refresh device variables before changing the matrix:

```bash
gcloud firebase test android models list --project PROJECT_ID
gcloud firebase test ios models list --project PROJECT_ID
gcloud firebase test ios models describe MODEL_ID --project PROJECT_ID
```

## One-time Apple setup for Firebase iOS devices

1. Register the explicit XCTest runner App ID
   `com.raychiu.tripline.RunnerUITests.xctrunner` in Apple Developer. Xcode
   appends `.xctrunner` to the UI test target bundle identifier when it builds
   the runner application.
2. Create iOS App Development provisioning profiles for both:
   - `com.raychiu.tripline`
   - `com.raychiu.tripline.RunnerUITests.xctrunner`
3. Export an Apple Development certificate as a password-protected P12.
4. Add repository secrets:
   - `APPLE_DEVELOPMENT_CERTIFICATE_P12`
   - `APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD`
   - existing `APPSTORE_ISSUER_ID`
   - existing `APPSTORE_API_KEY_ID`
   - existing `APPSTORE_API_PRIVATE_KEY`

The workflow validates and downloads both development profiles before any
repository build script runs. `ios/Flutter/TestLabSigning.xcconfig` then uses
manual signing and selects the matching profile by Xcode target: `Runner` uses
`Tripline App Development CI 2026-07-19`, while `RunnerUITests` uses
`Tripline XCTest Runner Development CI 2026-07-19`. The signing identity is
also pinned to the certificate embedded by those profiles, so runner keychain
ordering cannot select a different Development certificate. The App Store
Connect key is provided only to the pinned profile-download actions; Patrol,
Xcode build phases, CocoaPods scripts, and repository code never receive the
key or its path. CI builds a release XCTest bundle, verifies the signatures of
`Runner.app` and `RunnerUITests-Runner.app`, packages the result, and uploads it
to Test Lab. Firebase re-signs valid inputs for its own physical devices.
The workflow pins both the CI `DEVELOPER_DIR` and Test Lab
`--xcode-version` to 26.2; update both together only after the selected iOS
version reports support for the replacement Xcode version. Verify the live
catalog before changing either pin:

```bash
gcloud firebase test ios versions describe "$FIREBASE_IOS_VERSION" \
  --project "$FIREBASE_PROJECT_ID" \
  --format=json
```

The replacement must appear in `supportedXcodeVersionIds`; CI performs the
same check before importing Apple signing material or starting the iOS build.

When rotating the Development certificate or either profile, update the exact
certificate and profile names in `ios/Flutter/TestLabSigning.xcconfig` in the
same change as the protected GitHub secrets.

## Run and interpret

In GitHub Actions, select **Mobile E2E / Firebase Test Lab** and choose `android`, `ios`, or `all`. Test Lab keeps device video, screenshots, logs, JUnit results, and submitted test binaries in the private result bucket. Before GitHub uploads the seven-day artifact, `tool/sanitize_test_lab_evidence.sh` applies an evidence-only allowlist and removes signed APK/XCTest archives plus unknown binary formats. GitHub therefore retains the matrix log, JUnit/XML results, logcat, video, screenshots, and text metadata without republishing installable test inputs.

Manual **Mobile CI / Releases** dispatches are accepted only from `master`. Select `release_target=both` for the normal release path: TestFlight on `macos-26` and Google Play on Ubuntu start in parallel and share one `GITHUB_RUN_NUMBER`／`GITHUB_RUN_ATTEMPT` pair, so they receive the same build number. Use a platform-specific target only to recover or republish one store. TestFlight waits for App Store processing; Google Play uploads the signed AAB directly without retaining a public GitHub artifact. CI, Firebase Test Lab, and manual evidence remain independent workflows and do not delay store jobs.

收藏已採不可復原刪除，release workflow 不再執行收藏 restore staging
contract，也不再向 release build 注入 restore feature flag。已部署的後端
restore endpoint 是否退休不屬於 Flutter release pipeline 的責任範圍。

以下依日期排列的 release records 是當時版本的歷史證據。凡其中提到
Account 外觀頁、第五個 root tab、favorite restore App wiring、restore staging
contract 或 restore feature flag，均已由 #96 與現行 `DESIGN.md` 取代，不代表
目前 App 或 release workflow 的契約。

Test Lab exit codes are not swallowed:

- `0`: all tests passed;
- `10`: a test failed;
- `15`, `18`, `20`: inconclusive, unsupported matrix, or infrastructure failure; these remain failed CI jobs.

Use one device per default matrix to protect quota. Before increasing the matrix, add a Google Cloud budget alert and check the current [Firebase Test Lab quotas and pricing](https://firebase.google.com/docs/test-lab/usage-quotas-pricing).

## Local build checks

`ios/Flutter/Secrets.xcconfig` and `android/maps.properties` are intentionally
gitignored. Before a local platform build, copy the corresponding checked-in
`ios/Flutter/Secrets.xcconfig.example` or
`android/maps.properties.example`, fill it privately, and never log the key
value. A missing iOS file causes `AppDelegate` to stop at launch because the
native map key is required.

`patrol_cli` 4.6.1 can automate the iOS location permission dialog only when the
simulator uses one of its supported languages. CI pins the Firebase iOS matrix
to `en_US`; the SpringBoard tutorial guard also matches the English
`Edit Home Screen` and `Dismiss` labels. For a local run, use an English
simulator or temporarily switch the simulator to `en-US`, then restore the
developer's original locale after the test. These are test automation
limitations, not Tripline localization requirements.

```bash
dart pub global activate patrol_cli 4.6.1
export PATH="$PATH:$HOME/.pub-cache/bin"
patrol build android \
  --target patrol_test/native_map_smoke_test.dart \
  --target patrol_test/app_owned_flow_test.dart
patrol build ios \
  --target patrol_test/native_map_smoke_test.dart \
  --target patrol_test/app_owned_flow_test.dart \
  --debug --simulator

patrol test -t patrol_test/app_owned_flow_test.dart --device DEVICE_ID
patrol test -t patrol_test/native_map_smoke_test.dart --device DEVICE_ID
```

iOS 真機需要 release XCTest build。本機 development signing 必須與 App Store、
Test Lab 的 profiles 分開：

```bash
XCODE_XCCONFIG_FILE="$PWD/ios/Flutter/LocalDeviceSigning.xcconfig" \
  patrol test \
  --release \
  --target patrol_test/native_map_smoke_test.dart \
  --device DEVICE_ID
```

請保持裝置解鎖。若 Wi-Fi 配對的裝置無法在 Patrol CLI 的一秒
destination timeout 內就緒，先 build 一次，再交由 Xcode 等待 tunnel：

```bash
XCODE_XCCONFIG_FILE="$PWD/ios/Flutter/LocalDeviceSigning.xcconfig" \
  patrol build ios \
  --release \
  --target patrol_test/native_map_smoke_test.dart

xcodebuild test-without-building \
  -xctestrun XCTESTRUN_PATH \
  -only-testing RunnerUITests/RunnerUITests \
  -destination "platform=iOS,id=DEVICE_ID" \
  -destination-timeout 120
```

Run the deterministic product flow directly on a local Flutter device:

```bash
flutter test integration_test/app_smoke_test.dart -d DEVICE_ID
```

Run the host flow and regenerate its review artifact locally:

```bash
flutter test test/flows/app_owned_release_flow_test.dart
flutter test test/flows/app_owned_release_flow_artifacts_test.dart
flutter test test/flows/app_owned_visual_evidence_flow_test.dart
```

To run the same strict native-POI assertion locally, supply a valid platform Maps key and add:

```bash
patrol test \
  --target patrol_test/native_map_smoke_test.dart \
  --dart-define E2E_EXPECT_GOOGLE_POI=true \
  --device DEVICE_ID
```

Official references:

- [Patrol Firebase Test Lab integration](https://patrol.leancode.co/documentation/integrations/firebase-test-lab)
- [Firebase Android command line testing](https://firebase.google.com/docs/test-lab/android/command-line)
- [Firebase iOS XCTest packaging and signing](https://firebase.google.com/docs/test-lab/ios/run-xctest)
- [Google Navigation cross-platform setup](https://developers.google.com/maps/documentation/cross-platform/navigation)

## 2026-07-26 原生地圖多指手勢真機驗證紀錄（issue #104）

`nativeMapPinchObserved`／`nativeMapRotateObserved`／`nativeMapDoubleTapObserved`
三個缺口已補齊，兩平台都取得綠燈證據。原本的 `BLOCKED` release waiver 依據
（「缺少可用的原生自動化注入能力」）不再成立。

| Platform | Result | Evidence |
| --- | --- | --- |
| Android Firebase Test Lab | PASS | [Run 30164616330](https://github.com/raychiutw/trip-planner.flutter/actions/runs/30164616330) 與 [30165755093](https://github.com/raychiutw/trip-planner.flutter/actions/runs/30165755093) 連續兩輪 `native_map_smoke_test` 通過 |
| iOS Firebase Test Lab | PASS | [Run 30181732102](https://github.com/raychiutw/trip-planner.flutter/actions/runs/30181732102)，iPhone 14 Pro／iOS 16.6，`native_map_smoke_test` 通過（34.3s），四個手勢旗標與 Google POI callback 都觀察到 |

**Android 這一側用的是 `MediumPhone.arm`，那是虛擬機而非實體裝置。** 宣稱
「真機證據」時只有 iOS 的 `iphone14pro` 算數，兩者不可混為一談。

iOS 的注入方式：Patrol 4.8.0 的 server extension
（`ios/RunnerUITests/TriplineGestureExtension.swift`）跑在 XCTest runner 行程內，
Dart 端以 HTTP POST 請求手勢，由 `XCUIElement` 的公開多指介面執行。**不**依賴
accessibility tree —— iOS 實機的 XCUI a11y tree 裡沒有任何 Flutter `Semantics`
節點，`setSemanticsTreeEnabled()` 與 `ensureSemanticsEnabled()` 都無法改變這點
（詳見 issue #104 與 [ADR-0012](adr/0012-custom-patrol-extension-for-map-gestures.md)）。

⚠️ **Google POI 斷言依賴裝置的對外網路。**
[Run 30178928266](https://github.com/raychiutw/trip-planner.flutter/actions/runs/30178928266)
曾因該台 iPhone 整台 DNS 失效（`SlowWiFiDnsFailure` 49 次、`-1001` 逾時 79 次）
而完全載不到地圖圖磚，九次 tap 點在空白畫布上、POI 斷言失敗 —— 那是基礎設施
故障，不是產品缺陷。現在測試會分流回報（觸控未抵達 vs 底圖不可用），CI 也會在
DNS 全黑時發出 `::warning::`。
