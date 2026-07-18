# Mobile E2E automation

Tripline uses two complementary test layers:

- `flutter_test` and `integration_test` for deterministic app-owned state and navigation;
- Patrol 4.6.1 plus Firebase Test Lab for native Google Maps, platform views, system theme, and real-device behavior.

The external device workflow is `.github/workflows/mobile-e2e.yml`. A weekday schedule runs one Android matrix. iOS is manual because Firebase iOS devices are physical and require Apple Development signing. The same workflow is reusable: TestFlight dispatches run the iOS matrix, Play Internal dispatches run the Android matrix, and neither upload proceeds when its external-device gate fails. Both Test Lab jobs are master-only and use the `mobile-e2e` GitHub Environment; configure that environment to allow deployments only from `master`.

The Patrol bundle contains two independent release gates:

- `app_owned_flow_test.dart` runs login, itinerary/day switching, notes, map/itinerary switching, trip selection, account/appearance, chat, and favorites search/sort against deterministic repository fixtures. It never calls production services.
- `native_map_smoke_test.dart` checks the real native map lifecycle, zoom 12, overlays, and theme switching. Test Lab builds with `E2E_EXPECT_GOOGLE_POI=true`, so CI also fails unless a Google native POI produces the platform callback.

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

1. Register the explicit App ID `com.raychiu.tripline.RunnerUITests` in Apple Developer.
2. Create iOS App Development provisioning profiles for both:
   - `com.raychiu.tripline`
   - `com.raychiu.tripline.RunnerUITests`
3. Export an Apple Development certificate as a password-protected P12.
4. Add repository secrets:
   - `APPLE_DEVELOPMENT_CERTIFICATE_P12`
   - `APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD`
   - existing `APPSTORE_ISSUER_ID`
   - existing `APPSTORE_API_KEY_ID`
   - existing `APPSTORE_API_PRIVATE_KEY`

The workflow downloads both development profiles, builds a release XCTest bundle, verifies the signatures of `Runner.app` and `RunnerUITests-Runner.app`, and only then uploads it to Test Lab. Firebase re-signs valid inputs for its own physical devices.

## Run and interpret

In GitHub Actions, select **Mobile E2E / Firebase Test Lab** and choose `android`, `ios`, or `all`. Test Lab keeps device video, screenshots, logs, JUnit results, and submitted test binaries in the private result bucket. GitHub retains only the matrix log and downloaded device evidence for seven days; signed APK/XCTest inputs are deliberately excluded from public-repository artifacts.

Manual **Mobile CI / Releases** dispatches are accepted only from `master` and require approval through the `mobile-release` GitHub Environment. They do not bypass the matching platform matrix. The release job waits for `external_device_gate`; a test, configuration, quota, or Test Lab infrastructure failure leaves the upload job skipped instead of publishing an unverified build. Google Workload Identity Federation is also restricted to this repository's `mobile-e2e.yml` on `master`.

Before Test Lab, the release workflow runs `tool/verify_favorite_restore_contract.sh` against a disposable staging account and POI. Configure these protected `mobile-release` Environment secrets after the backend migration is deployed:

- `STAGING_API_BASE_URL` (HTTPS only), `STAGING_ALLOWED_HOST` (exact hostname), `STAGING_ORIGIN`
- `STAGING_SESSION_COOKIE`, optional `STAGING_CSRF_TOKEN`
- `STAGING_OTHER_SESSION_COOKIE`, optional `STAGING_OTHER_CSRF_TOKEN`
- `STAGING_FAVORITE_POI_ID`
- `STAGING_CONTRACT_GUARD=tripline-staging-favorite-restore-v1`

The smoke verifies create → delete → active-list exclusion → second-user containment → restore → one active row → cleanup. Missing secrets, the committed production host `trip-planner-dby.pages.dev`, a mismatched allowlist, an absent migration, or any contract mismatch fails closed. Only after this gate succeeds do release builds receive `FAVORITE_RESTORE_ENABLED=true`; the independent Patrol suites do not toggle a feature they do not exercise.

Test Lab exit codes are not swallowed:

- `0`: all tests passed;
- `10`: a test failed;
- `15`, `18`, `20`: inconclusive, unsupported matrix, or infrastructure failure; these remain failed CI jobs.

Use one device per default matrix to protect quota. Before increasing the matrix, add a Google Cloud budget alert and check the current [Firebase Test Lab quotas and pricing](https://firebase.google.com/docs/test-lab/usage-quotas-pricing).

## Local build checks

```bash
dart pub global activate patrol_cli 4.4.0
patrol build android \
  --target patrol_test/native_map_smoke_test.dart \
  --target patrol_test/app_owned_flow_test.dart
patrol build ios \
  --target patrol_test/native_map_smoke_test.dart \
  --target patrol_test/app_owned_flow_test.dart \
  --debug --simulator
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
