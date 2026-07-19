# Mobile E2E automation

Tripline uses two complementary test layers:

- `flutter_test` and `integration_test` for deterministic app-owned state and navigation;
- Patrol 4.6.1 plus Firebase Test Lab for native Google Maps, platform views, system theme, and real-device behavior.

The external device workflow is `.github/workflows/mobile-e2e.yml`. A weekday schedule runs one Android matrix. iOS is manual because Firebase iOS devices are physical and require Apple Development signing. The same workflow is reusable: TestFlight dispatches run the iOS matrix and Play Internal dispatches run the Android matrix as independent evidence jobs. Store uploads no longer wait for Firebase or the staging favorite-restore contract; failures remain visible for the next corrective release without preventing an otherwise valid signed build from reaching testers. Both Test Lab jobs are master-only and use the `mobile-e2e` GitHub Environment; configure that environment to allow deployments only from `master`.

The Patrol bundle contains two independent evidence suites:

- `app_owned_flow_test.dart` runs login, itinerary/day switching, notes, map/itinerary switching, trip selection, account/appearance, chat, and favorites search/sort against deterministic repository fixtures. It never calls production services.
- `native_map_smoke_test.dart` checks the real native map lifecycle, zoom 13, overlays, and theme switching. Test Lab builds with `E2E_EXPECT_GOOGLE_POI=true`, so CI also fails unless a Google native POI produces the platform callback.

Separating the deterministic product flow from the native map boundary makes failures actionable while keeping both cases in the same external-device matrix.

The regular PR/push CI also runs the same app-owned flow on the host runner. It writes named geometry-review PNGs for chat, itinerary, Tripline POI, native-Google-POI callback state, favorites, trip picker, account, form, and destructive confirmation to `build/test-artifacts/app-owned/`. Every state is captured in Light/Dark, 100%/200% text, and Reduce Motion/Reduce Transparency coverage, then uploaded as the seven-day `tripline-ui-evidence-*` artifact even when a later CI step fails. Flutter host tests use the deterministic Ahem font, so these PNGs validate layout and state coverage; use Test Lab's device screenshots/video for readable platform typography and native map tiles. Screenshots are evidence, not pixel-perfect pass/fail goldens.

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
   - `FIREBASE_IOS_VERSION` (required for iOS and supported by the selected model)
5. Keep `GOOGLE_MAPS_ANDROID_API_KEY` and `GOOGLE_MAPS_IOS_API_KEY` as repository secrets. Restricted keys must allow both the platform Maps SDK and Navigation SDK service while retaining the app package/bundle restriction.

Create the dedicated result bucket with uniform access, grant the Test Lab CI service account object-admin access on that bucket, and apply the checked-in 14-day lifecycle policy:

```bash
gcloud storage buckets update gs://BUCKET_NAME \
  --lifecycle-file=.github/test-lab-results-lifecycle.json
```

The current Tripline bucket is `trip-planner-490413-test-lab-results` in `ASIA-EAST1`. Its soft-delete retention is disabled so the lifecycle rule actually caps raw Test Lab storage. GitHub artifacts retain the same evidence for seven days.

The Android job reuses the existing upload-keystore secrets to sign Patrol's debug APK. This is required because the Maps key is restricted to the Tripline package and signing SHA-1; an ephemeral GitHub debug key would render an unauthorized blank map.

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

When rotating the Development certificate or either profile, update the exact
certificate and profile names in `ios/Flutter/TestLabSigning.xcconfig` in the
same change as the protected GitHub secrets.

## Run and interpret

In GitHub Actions, select **Mobile E2E / Firebase Test Lab** and choose `android`, `ios`, or `all`. Test Lab keeps device video, screenshots, logs, JUnit results, and submitted test binaries in the private result bucket. Before GitHub uploads the seven-day artifact, `tool/sanitize_test_lab_evidence.sh` applies an evidence-only allowlist and removes signed APK/XCTest archives plus unknown binary formats. GitHub therefore retains the matrix log, JUnit/XML results, logcat, video, screenshots, and text metadata without republishing installable test inputs.

Manual **Mobile CI / Releases** dispatches are accepted only from `master` and require approval through the `mobile-release` GitHub Environment. Store upload is independent of staging and Firebase evidence so a Test Lab configuration, quota, or infrastructure failure cannot block TestFlight／Play internal delivery. Keep `run_optional_evidence` disabled for the publish-first path; enable it only when the same dispatch should also collect staging and device evidence. Google Workload Identity Federation remains restricted to this repository's `mobile-e2e.yml` on `master`.

When `run_optional_evidence` is enabled, the release workflow runs `tool/verify_favorite_restore_contract.sh` against a disposable staging account and POI before collecting Test Lab evidence. Configure these protected `mobile-release` Environment secrets after the backend migration is deployed:

- `STAGING_API_BASE_URL` (HTTPS only), `STAGING_ORIGIN`
- `STAGING_SESSION_COOKIE`, optional `STAGING_CSRF_TOKEN`
- `STAGING_OTHER_SESSION_COOKIE`, optional `STAGING_OTHER_CSRF_TOKEN`
- `STAGING_FAVORITE_POI_ID`
- `STAGING_CONTRACT_GUARD=tripline-staging-favorite-restore-v1`

Before adding those secrets, add the deployed API's exact HTTPS origin and its
stable backend `environmentId` to the reviewed
`tool/staging-release-environments.txt` file. The environment cannot override
that file. The checked-in `.test` pair is reserved for the isolated script test
and cannot resolve on the public Internet. The backend must implement the
read-only `GET /api/environment-identity` contract documented in
`docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`.

Before its first mutation, the smoke verifies that the exact origin is committed,
the backend identity matches, and the backend advertises the
`expected-environment-id-v1` mutation guard. Every request carries the committed
ID in `X-Expected-Environment-ID`, which the backend must verify again inside
each write path. It then verifies create → delete → active-list
exclusion → second-user containment → restore → one active row → cleanup.
Missing secrets, an uncommitted origin, an explicit port or path, an identity
mismatch, the committed production host `trip-planner-dby.pages.dev`, an absent
migration, or any contract mismatch fails closed. Only after this gate succeeds
do release builds receive `FAVORITE_RESTORE_ENABLED=true`; the independent
Patrol suites do not toggle a feature they do not exercise.

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
to `en_US`. For a local run, use an English simulator or temporarily switch the
simulator to `en-US`, then restore the developer's original locale after the
test. This is a Patrol automation limitation, not a Tripline localization
requirement.

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

## 2026-07-19 verification record

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
| Current-master TestFlight upload | BLOCKED | Release correctly waits for both blocked gates above |

The last successful TestFlight upload predates the HIG/map merge and is not
accepted as current-release evidence. Do not dispatch the TestFlight workflow
until the two blocked rows are configured; the workflow is intentionally
fail-closed.

The Android Test Lab run is one CI-only scheduling commit behind the recorded
master SHA. The diff from `d47e88d0` to `fec66f90` changes only
`.github/workflows/mobile-e2e.yml` and its workflow contract test; Flutter,
native runner, and Patrol test sources are identical. It therefore proves the
current product/test binaries, but it is not described as exact-commit
evidence.
