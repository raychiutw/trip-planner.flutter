# Mobile E2E automation

Tripline uses two complementary test layers:

- `flutter_test` and `integration_test` for deterministic app-owned state and navigation;
- Patrol 4.6.1 plus Firebase Test Lab for native Google Maps, platform views, system theme, and real-device behavior.

The external device workflow is `.github/workflows/mobile-e2e.yml`. A weekday schedule runs one Android matrix. iOS is manual because Firebase iOS devices are physical and require Apple Development signing. Store uploads are independent: a manual `Mobile CI / Releases` dispatch starts the selected store jobs directly. Both Test Lab jobs remain master-only and use the `mobile-e2e` GitHub Environment; configure that environment to allow deployments only from `master`.

Android Test Lab first runs the standard Flutter
`integration_test/app_smoke_test.dart` instrumentation APKs, then runs the
Patrol bundle below. The two runs use separate result directories and logs.
This keeps the required Flutter integration gate independent from Patrol while
reusing the same deterministic app-owned fixture.

The Patrol bundle contains two independent evidence suites:

- `app_owned_flow_test.dart` runs Welcome／Login, four root tabs, trips, itinerary and Day fallback, notes, map/itinerary switching, Tripline and external POIs, Account 與跟隨系統的 appearance（確認沒有 App 內 Appearance 設定頁）, chat draft retention, favorites branch restoration, forms, destructive confirmation, offline state, error, and recovery against deterministic repository fixtures. It never calls production services.
- `native_map_smoke_test.dart` checks real native map creation, dispose／recreate lifecycle, zoom 13 before and after remount, overlays, theme switching, location permission, pan／pinch／rotate／double-tap gestures, and native POI callbacks. Test Lab builds with `E2E_EXPECT_GOOGLE_POI=true`, so CI fails unless a Google native POI produces the platform callback.

Separating the deterministic product flow from the native map boundary makes failures actionable while keeping both cases in the same external-device matrix.

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

The regular PR/push CI runs formatter, analyzer, the root-app smoke test, the host-runner app-owned release flow, and the mobile workflow contract test. Full tests and the complete deterministic visual matrix run in `ship` before landing. Host smoke results are not a substitute for readable platform typography, native map tiles, or manual-device accessibility evidence.

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
contract 或 restore feature flag，均已由 #96 與現行 `design.md` 取代，不代表
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

`patrol_cli` 4.4.0 can automate the iOS location permission dialog only when the
simulator uses one of its supported languages. CI pins the Firebase iOS matrix
to `en_US`; the SpringBoard tutorial guard also matches the English
`Edit Home Screen` and `Dismiss` labels. For a local run, use an English
simulator or temporarily switch the simulator to `en-US`, then restore the
developer's original locale after the test. These are test automation
limitations, not Tripline localization requirements.

```bash
dart pub global activate patrol_cli 4.4.0
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

請保持裝置解鎖。若 Wi-Fi 配對的裝置無法在 Patrol CLI 4.4.0 的一秒
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

## 歷史 release records

## 2026-07-23 v0.9.6 store release record

Final source SHA `4ac7776d95135cbcf1baded91511a11d28d171c9` was released from
[workflow run 29964801571](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29964801571).
Run number `127`, attempt `1`, produced shared iOS／Android build `12701` for
version `0.9.6`. The final Test Lab navigation fix was merged through
[PR #80](https://github.com/raychiutw/trip-planner.flutter/pull/80) after
[PR CI run 29963049945](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29963049945)
completed successfully; the exact merge commit then passed
[master CI run 29963722375](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29963722375).

| Layer | Result | Evidence |
| --- | --- | --- |
| Analyzer／full Flutter suite | PASS | Analyzer reported 0 issues; 1,402 tests passed locally, in PR CI, on the merge commit, and independently in both store jobs |
| Local Patrol product flow | PASS | iOS simulator completed 1 app-owned flow covering login, chat input, all five root tabs, and favorites search |
| iOS Firebase Test Lab | PASS | [Run 29963749443](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29963749443) tested the exact final SHA on iPhone 14 Pro／iOS 16.6 and reported `3 test cases passed` |
| TestFlight | PASS | Build `12701` uploaded through the App Store API; processing returned `VALID` |
| Google Play internal | PASS | Signed AAB uploaded to `com.raychiu.tripline`, track `internal`, status `completed`; Play edit `14630000200256184012` committed |

The `mobile-release` Environment approved both store jobs. The release dispatch
kept `run_optional_evidence=false` to avoid rerunning the already-passing iOS
matrix; Android Test Lab and the staging favorite-restore contract were not
claimed as part of this release record.

## 2026-07-21 v0.9.4 store release record

Source SHA `e9517dd131836e80424b3aae6a7046df75f8a053` was released from
[workflow run 29848648325](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29848648325).
Run number `112`, attempt `1`, produced shared iOS／Android build `11201` for
version `0.9.4`. The source was merged through
[PR #73](https://github.com/raychiutw/trip-planner.flutter/pull/73) after
[PR CI run 29846766960](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29846766960)
completed successfully; the exact merge commit then passed
[master CI run 29847777356](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29847777356).

| Layer | Result | Evidence |
| --- | --- | --- |
| Analyzer／format／workflow lint | PASS | Flutter analyzer reported 0 issues; Dart format, actionlint, and `git diff --check` passed |
| Full Flutter suite | PASS | 1,355 tests passed locally, in PR CI, on the merge commit, and independently in both store jobs |
| Android build evidence | PASS | PR and master CI each completed the Android debug build; the release job produced and preserved the signed AAB |
| iOS simulator evidence | PASS | Timeline rail, exact duration, compact map links, large-text cancel action, native Google POIs, light map style, and zoom `13` were visually and semantically verified |
| TestFlight | PASS | Build `11201` uploaded through the App Store API; processing returned `VALID` |
| Google Play internal | PASS | Signed AAB uploaded to `com.raychiu.tripline`, track `internal`, status `completed`; Play edit `03552382695613245559` committed |

The `mobile-release` Environment approved both store jobs. Optional Firebase
and staging evidence was disabled for this publish-first run and remains an
independent evidence path rather than a claimed pass.

## 2026-07-21 v0.9.3 store release record

Source SHA `eb4c493bb16c9317017c268fe225b43fa6fa801e` was released from
[workflow run 29830338702](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29830338702).
Run number `107`, attempt `1`, produced shared iOS／Android build `10701` for
version `0.9.3`. The source was merged through
[PR #71](https://github.com/raychiutw/trip-planner.flutter/pull/71) after
[PR CI run 29829527458](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29829527458)
completed successfully.

| Layer | Result | Evidence |
| --- | --- | --- |
| Analyzer／format／workflow lint | PASS | Flutter analyzer reported 0 issues; Dart format, actionlint, and `git diff --check` passed |
| Full Flutter suite | PASS | 1,347 tests passed locally and in PR CI, including POSIX release contracts and timeline drag-feedback geometry |
| PR build evidence | PASS | Run 29829527458 completed analyzer, full tests, named UI artifacts, and Android debug build |
| TestFlight | PASS | Build `10701` uploaded through the App Store API; processing returned `VALID` |
| Google Play internal | PASS | Signed AAB uploaded to `com.raychiu.tripline`, track `internal`, status `completed`; Play edit `06867052877178981510` committed |

The `mobile-release` Environment approved both store jobs. Optional Firebase
and staging evidence was disabled for this publish-first run and remains an
independent evidence path rather than a claimed pass.

## 2026-07-21 v0.9.2 store release record

Source SHA `12a8721c1f8361e244af6395fcad51df4745b002` was released from
[workflow run 29802745365](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29802745365).
Run number `101`, attempt `1`, produced the shared iOS／Android build number
`10101` for version `0.9.2`. This release standardizes local and GitHub Actions builds on Flutter
3.44.7 stable／Dart 3.12.2. The public privacy policy returned HTTP 200 at
`https://trip-planner-dby.pages.dev/privacy`; signup forwards the user's actual
`privacyConsent`, account settings link to the same policy, and in-app account
deletion uses an uncached preview followed by `DELETE /api/account`.

| Layer | Result | Evidence |
| --- | --- | --- |
| Analyzer | PASS | Flutter 3.44.7, 0 issues |
| Focused release／API／account／trip tests | PASS | 218 tests, including the four stale assertions from the previous failed Linux run |
| Full Windows host run | PARTIAL | 1,314 passed; 12 Bash-invocation cases in the two workflow contract files are not reliable under Windows/MSYS and remain mandatory Ubuntu CI gates |
| Push CI | PASS | [Run 29802168723](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29802168723): actionlint, analyzer, complete Ubuntu suite including Bash contracts, and Android debug build |
| Workflow／signing configuration | PASS | Flutter version pinned to 3.44.7; App Store, Play, Maps, and signing secrets produced valid signed artifacts |
| Public privacy policy | PASS | Anonymous HTTPS GET returned 200 on 2026-07-21 |
| Favorite restore staging contract | BLOCKED | Protected staging credentials and reviewed real staging allowlist are still absent; publish with `run_optional_evidence=false` |
| TestFlight | PASS | Build `10101` uploaded through the App Store API; processing returned `VALID` |
| Google Play internal | PASS | Build `10101` uploaded to `com.raychiu.tripline`, track `internal`, status `completed`; Play edit `06752822212770581126` committed |

The `mobile-release` Environment approved both store deployments. Optional
Firebase and staging evidence was deliberately disabled for this publish-first
run; the blocked restore contract remains an independent evidence task and is
not represented as passed.

## 2026-07-20 HIG／offline／restore implementation verification

The 2026-07-20 App implementation completed the HIG navigation, typography,
search, swipe-delete, sheet semantics, map POI interaction, and reconnect-sync
tasks. Local verification used Flutter 3.44.6:

| Layer | Result | Evidence |
| --- | --- | --- |
| Dart formatting and analyzer | PASS | All changed Dart files formatted; analyzer reported 0 issues |
| Product Flutter suite | PASS | 1,284 tests across API, app, features, flows, models, platform, theme, and UI |
| Android native compile | PASS | `flutter build apk --debug` produced `app-debug.apk` |
| Favorite restore App wiring | PASS | `POST /poi-favorites/{id}/restore`; release builds enable `FAVORITE_RESTORE_ENABLED=true` |
| Real staging restore contract | BLOCKED | The protected `mobile-release` environment has no real staging secrets or variables, and the reviewed allowlist contains only the reserved `.test` fixture |

The two Bash-based workflow test files are not a Windows/MSYS verification
surface because Dart-launched Git Bash does not preserve their POSIX path and
environment assumptions. They remain mandatory Linux CI gates. Do not interpret
this host limitation as staging contract evidence.

## 2026-07-20 store release record

Source SHA `e4ebcb5f60ce0eaaa9b397683d793da0e3b8eb96` was released from one approved `release_target=both` dispatch. Workflow run [29699386889](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29699386889) used run number `92`, attempt `1`, and the shared build-number formula to produce iOS and Android build `9201` for version `0.9.1`.

| Store | Result | Evidence |
| --- | --- | --- |
| TestFlight | PASS | Build `9201` uploaded through the App Store API; App Store processing returned `VALID` |
| Google Play internal | PASS | Signed AAB uploaded to package `com.raychiu.tripline`, track `internal`, status `completed`; Play edit `08259896710714327432` committed |

Optional Firebase and staging evidence was deliberately disabled for this publish-first run. Those independent gates remain tracked below and can be collected without invalidating the completed store release.

## 2026-07-19 pre-release verification record

Source SHA `fec66f90` (the `master` head at verification time) was verified with
the following layered evidence. A blocked external gate is deliberately not
counted as a pass.

| Layer | Result | Evidence |
| --- | --- | --- |
| Dart formatting | PASS | 335 files checked, no changes |
| Focused UI/app/flow tests | PASS | 109 tests |
| Full Flutter tests and analyzer | PASS | local worktree run |
| iOS simulator build | PASS | unsigned `Runner.app` built locally |
| Deterministic iOS integration flow | PASS | `integration_test/app_smoke_test.dart`, 1 test |
| Native iOS map smoke | PASS | `patrol_cli` 4.4.0, 1 passing UI test covering ready, zoom 12, theme, gesture, and location; `build/ios_results_1784405657116.xcresult` |
| Deterministic visual matrix | PASS | 54 named Light/Dark, 100%/200% text, accessibility screenshots under `build/test-artifacts/app-owned/` |
| Android build and fast CI | PASS | [Mobile CI run 29658333281](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29658333281), SHA `fec66f90` |
| Android external device | PASS | [Firebase Test Lab run 29657342097](https://github.com/raychiutw/trip-planner.flutter/actions/runs/29657342097), SHA `d47e88d0` |
| iOS Firebase physical device | BLOCKED | No Apple Development P12 for team `8Z6WVFJ574` in the protected environment |
| Favorite restore staging contract | BLOCKED | Backend identity endpoint and server-side expected-environment mutation guard are not deployed; the deployed origin/environment pair is not committed to `tool/staging-release-environments.txt`; protected staging URL, account cookies, fixture POI, and contract guard are not configured |
| TestFlight upload for this snapshot | NOT RUN | At this point in the verification sequence, release was still coupled to the two blocked optional gates above |

This table records the pre-release state at source SHA `fec66f90`. The later
store record above supersedes its upload status after store delivery was safely
decoupled from optional external-device and staging evidence.

The Android Test Lab run is one CI-only scheduling commit behind the recorded
master SHA. The diff from `d47e88d0` to `fec66f90` changes only
`.github/workflows/mobile-e2e.yml` and its workflow contract test; Flutter,
native runner, and Patrol test sources are identical. It therefore proves the
current product/test binaries, but it is not described as exact-commit
evidence.
